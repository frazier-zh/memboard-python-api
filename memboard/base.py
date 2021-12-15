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
        self.list = None
        self.size = 0
        self.output_index = 0
        self.output_list = []
        self.output_size = 0
        self.ret = None

    def __iadd__(self, other):
        return self.add(other)

    def add(self, other):
        if isinstance(other, np.ndarray):
            if self.list is not None:
                    self.list = np.concatenate((self.list, other))
                    self.size += other.shape[0]
            else:
                self.list = other
                self.size = other.shape[0]

    def get_code(self):
        return self.list

    def assign_output(self, width=0):
        if width==0:
            return
        self.output_index += 1
        self.output_list.append(width)
        self.output_size += width
        return self.output_index

    def clear():
        pass

# Key variables
__session = Session()
output = dict()

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

            global __session
            if is_emulate():
                __session.add(code)
                return __session.assign_output(width)
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
from .statistics import get_runtime
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
    global __session
    __session.clear()

def add(run):
    global __session

    with start_emulate():
        ret = run()

def execute(func=None, every=0, total=0, filename='temp'):
    global __session

    if func is None:
        if __session.size==0:
            __module_logger.warn('No task found.')
            return
    else:
        add(func)

    run_time = 0
    for ops in __session.list:
        run_time += get_runtime(ops)

    if run_time > every:
        __module_logger.warn(f'Execution takes longer than the given interval {u.to_pretty(run_time)} > {u.to_pretty(every)}.')
        every = 1.5 * run_time
        __module_logger.warn(f'Execution interval is set to {u.to_pretty(every)}.')
    elif 1.1*run_time > every:
        __module_logger.warn(f'Execution may takes longer than the given interval {u.to_pretty(every)}')

    # Print output info
    print(f"""
======== Execution Summary ========
Total commands:       {__session.size}
Output size (byte):   {__session.output_size*2}
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
            mem = device.to_byte(__session.list)
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

    device.pipe_in(0x81, device.to_byte_single(device.to_tick(every), 6))# Load clock counter
    device.pipe_in(0x80, device.to_byte(__session.list)) # Load program

    data_result = bytearray(__session.output_list.count(2)*2) # Pipe out container
    time_result = bytearray(__session.output_list.count(6)*6) # Pipe out container

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

    convert(filename)

import csv
def convert(filename='temp'):
    global __session
    read_size = __session.output_size * 2

    with open(filename+'.csv', 'w', newline='') as csvfile:
        fieldnames = [str(key) for key in output.keys()]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        with open(filename+'.dat', 'rb') as file:
            data = file.read(read_size)
            while data:
                data_processed = np.zeros(__session.output_index, dtype=np.uint64)
                for i in range(__session.output_index):
                    value = 0
                    for j in range(__session.output_list[i]):
                        value <<= 8
                        value += data[0]
                        del data[0]

                temp_dict = output.copy()

                data = file.read(read_size)