import numpy as np
import logging
from functools import wraps

__module_logger = logging.getLogger(__name__)


"""Session
    Memboard module holds singleton instance of session which can only be created
at import of the module.
    Session keeps track of all the command registered during runtime.
"""
class Session(object):
    def __init__(self):
        self.code = None
        self.size = 0
        self.output_index = 0
        self.output_list = []
        self.output = dict()

    def __iadd__(self, other):
        return self.add(other)

    def add(self, other):
        if isinstance(other, np.ndarray):
            if self.code is not None:
                    self.code = np.concatenate((self.code, other))
                    self.size += other.shape[0]
            else:
                self.code = other
                self.size = other.shape[0]

    def assign_output(self, width=0):
        if width==0:
            return
        self.output_index += 1
        self.output_list.append(width)
        return self.output_index

    def get_output_size(self):
        return np.sum(self.output_list)

    def clear():
        pass

# Key variables
__ss = Session()
output = __ss.output

def allow_emulate(width=0):
    """Decorator allow formalize definition of atom operations.
    With output_bytes=0, there is no return value expected from operation.

    The return value are thus labeled by integer placeholder and are updated
    by its value once the results are ready.   
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            code = func(*args, **kwargs)

            global __ss
            if is_emulate():
                __ss.add(code)
                return __ss.assign_output(width)
            else:
                pass
                # TODO: execute_once(code)
                # TODO: Add return value

        return wrapper
    return decorator


_emulate_enabled = False
def is_emulate():
    return _emulate_enabled

class start_emulate(object):
    def __enter__(self):
        global _emulate_enabled
        _emulate_enabled = True
    
    def __exit__(self, exc_type, exc_value, tb):
        global _emulate_enabled
        _emulate_enabled = False

        if exc_type is not None:
            return False
        else:
            return True

import time
from . import unit as u
from . import device

__debug = False
class connect(object):
    def __init__(self, path, debug=False):
        self.path = path

        device.debug(debug)
        global __debug
        __debug = True

    def __enter__(self):
        device.open()
        device.load(self.path)

    def __exit__(self, exc_type, exc_value, tb):
        device.close()

        device.debug(False)
        global __debug
        __debug = False

        if exc_type is not None:
            return False
        else:
            return True

def clear():
    global __ss
    __ss.clear()

def add(run):
    global __ss

    with start_emulate():
        run()

def execute(func=None, every=0, total=0, filename='temp'):
    global __ss

    if func is None:
        if __ss.size==0:
            __module_logger.warn('No task found.')
            return
    else:
        add(func)

    run_time = 0
    for ops in __ss.code:
        run_time += u.get_runtime(ops)

    if run_time > every:
        __module_logger.warn(f'Execution takes longer than the given interval {u.to_pretty(run_time)} > {u.to_pretty(every)}.')
        every = 1.5 * run_time
        __module_logger.warn(f'Execution interval is set to {u.to_pretty(every)}.')
    elif 1.1*run_time > every:
        __module_logger.warn(f'Execution may takes longer than the given interval {u.to_pretty(every)}')

    # Print output info
    print(f"""
======== Execution Summary ========
Total commands:       {__ss.size}
Output size (byte):   {__ss.get_output_size()*2}
Execution time:       {u.to_pretty(run_time)}
Execution every:      {u.to_pretty(every)}
Total time:           {u.to_pretty(total)}
Output file:          ./{filename}.dat
Memory file (debug):  ./{filename}.mem*
===================================
    """)
    
    global __debug
    if (__debug):
        """Generate verilog memory file, used in host simulation
        """
        with open(filename+'.mem1', 'w') as file:
            mem = device.to_byte(__ss.code)
            length = len(mem)
            for i in range(int(length/4)):
                file.write('{:02x} {:02x} {:02x} {:02x}\n'\
                    .format(mem[4*i], mem[4*i+1], mem[4*i+2], mem[4*i+3]))

        with open(filename+'.mem2', 'w') as file:
            mem = device.to_byte_single(device.to_tick(every), 6)
            for v in mem:
                file.write('{:02x} '.format(v))

    # Start execution
    device.trigger_in(0x40, 0) # Reset logic block
    device.trigger_in(0x40, 1) # Reset memory block
    device.trigger_in(0x40, 2) # Reset fifo blocks

    device.pipe_in(0x81, u.to_byte(u.to_tick(every), 6))# Load clock counter
    device.pipe_in(0x80, u.to_byte(__ss.code)) # Load program

    data_result = bytearray(__ss.output_list.count(2)*2) # Pipe out container
    time_result = bytearray(__ss.output_list.count(6)*6) # Pipe out container

    device.wire_in(0x00, 1) # Enable execution
    stop_time = total/u.s
    with open(filename+'.dat', 'wb') as file:
        start_time = time.time()
        while time.time()-start_time<stop_time:
            if device.wait_trigger_out(0x60, 0):
                device.pipe_out(0xA1, time_result)
                device.pipe_out(0xA0, data_result)
                file.write(time_result)
                file.write(data_result)
        device.wire_in(0x00, 0) # Stop execution

    if not __debug:
        convert(filename)

import csv
def convert(filename='temp'):
    global __ss
    read_size = __ss.get_output_size() * 2

    with open(filename+'.csv', 'w', newline='') as csvfile:
        fieldnames = [str(key) for key in output.keys()]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        with open(filename+'.dat', 'rb') as file:
            data = file.read(read_size)
            while data:
                data_16b = u.from_byte(data)
                values = []
                for i in range(__ss.output_index):
                    value = 0
                    for j in range(__ss.output_list[i]):
                        value = (value<<16) + data_16b[0]
                        del data[0]
                    values.append(value)

                temp_dict = output.copy()
                for key in temp_dict.keys:
                    temp_dict[key] = values[temp_dict[key]]

                writer.writerow(temp_dict)
                data = file.read(read_size)
                