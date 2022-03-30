import numpy as np
import warnings
from functools import wraps

import time

from . import unit as u
from . import device
from .const import dev, state

import csv
import copy


""" Board Class
    Integrated operations for board communication
"""
class board:
    # Initialize device
    def open():
        device.open()
        device.load('./verilog/src/top.bit')

    def close():
        device.close()

    def reset():
        device.trigger_in(0x40, 0) # Reset logic block
        device.trigger_in(0x40, 1) # Reset memory block
        device.trigger_in(0x40, 2) # Reset fifo blocks

    def start():
        device.wire_in(0x00, 0b01)

    def start_auto():
        device.wire_in(0x00, 0b11) # Enable execution

    def wait_stop(time_out=1):
        start_time = time.time()
        while not board.get_state(dev.logic) == state.idle:
            if (time.time()-start_time > time_out):
                device.trigger_in(0x40, 0)
                raise TimeoutError('Time out while waiting on main logic.')
        board.stop()

    def stop():
        device.wire_in(0x00, 0b00) # Stop execution

    def set_prog(code):
        device.pipe_in(0x80, u.to_byte(code)) # Load program

    def set_clock(every):
        device.pipe_in(0x81, u.to_byte(u.to_tick(every), 6))# Load clock counter

    def get_count():
        return device.wire_out(0x20) # Check cycle count

    def get_state(target=0):
        device.update_wire_out()
        state1 = device.read_wire_out(0x21)
        state2 = device.read_wire_out(0x22)

        if target==dev.logic:
            state = u.bit(state2, 3, 0)
        elif target==dev.adc:
            state = u.bit(state2, 7, 4)
        elif target==dev.dac:
            state = u.bit(state1, 3, 0)
        elif target==dev.sw_source:
            state = u.bit(state1, 7, 4)
        elif target==dev.sw_gate:
            state = u.bit(state1, 11, 8)
        elif target==dev.sw_drain:
            state = u.bit(state1, 15, 12)
        else:
            return -1

        return state

    def get_output(size): # Size in 2-bytes (int16)
        result = bytearray(size*2) # Pipe out container, bytes
        device.pipe_out(0xA0, result)
        return result

""" Operation basic
"""
# Operation decorator
_automode_enabled = False
class automode(object):
    def __init__(self, session):
        self.session = session

    def __enter__(self):
        global _automode_enabled, _session
        _automode_enabled = True
        _session = self.session

    def __exit__(self, exc_type, exc_value, tb):
        global _automode_enabled, _session
        _automode_enabled = False
        del _session

        if exc_type is not None:
            return False
        else:
            return True

def allow_auto(size=0):
    """Decorator allow formalize definition of operations.
    With output_bytes=0, there is no return value expected from operation.

    The return value are thus labeled by integer placeholder and are updated
    by its value once the results are ready.
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            code = func(*args, **kwargs)

            global _automode_enabled
            if _automode_enabled:
                global _session
                _session.add(code)
                return _session.output.assign(size)
            else:
                board.set_prog(code)
                board.start()

                board.wait_stop()
                result = u.from_byte(board.get_output(size))
                if size == 1:
                    return u.to_current(result)
                elif size == 3:
                    return u.to_time(result)
                elif size == 10:
                    time.sleep(0.001)

        return wrapper
    return decorator

"""Output
    Output class keeps track of all the output registered during runtime.
"""
class output(dict):
    def __init__(self):
        self.index = 0
        self.list = []
        self.size = 0

    def assign(self, size):
        if (size):
            self.index += 1
            self.list.append(size)
            self.size += size
            return self.index-1

    def clear(self):
        self.__dict__.clear()
        self.list.clear()
        self.index = 0
        self.size = 0

"""Session
    Session class keeps track of all the command registered during runtime.
"""
class session(object):
    def __init__(self):
        self.code = None
        self.output = output()

    def clear(self):
        self.code = None
        self.output.clear()

    def add(self, other):
        if isinstance(other, np.ndarray):
            if self.code is not None:
                    self.code = np.concatenate((self.code, other))
                    self.size += other.shape[0]
            else:
                self.code = other
                self.size = other.shape[0]

    def compile(self, func):
        # Run function once
        with automode(self):
            func(self.output)

        self.run_time = 0
        for ops in self.code:
            self.run_time += u.get_runtime(ops)

    def execute(self, out, every=0, total=0):
        if 1.5*self.run_time > every:
            warnings.warn(f'Execution may takes longer than the given interval {u.to_pretty(self.run_time)} > {u.to_pretty(self.every)}.')
            every = 1.5*self.run_time
            warnings.warn(f'Execution interval is set to {u.to_pretty(every)}.')

        self.print_info()

        # Start execution
        board.reset()
        board.set_prog(self.code)
        board.set_clock(every)
        
        board.start_auto()
        stop_time = total/u.s
        with open(out+'.dat', 'wb') as file:
            start_time = time.time()
            prev_count = 0
            while time.time()-start_time<stop_time:
                cur_count = board.get_count()
                if cur_count > prev_count: # Indicate new output
                    result = board.get_output(self.output.size*(cur_count-prev_count))
                    file.write(result)

                    prev_count = cur_count

            board.stop()
            cur_count = board.get_count()
            if cur_count > prev_count: # Indicate new output
                result = board.get_output(self.output.size*(cur_count-prev_count))
                file.write(result)
        
    def convert(self, out):
        # TODO
        read_size = self.output.size*2

        with open(out+'.csv', 'w', newline='') as csvfile:
            fieldnames = [str(key) for key in self.output.keys()]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()

            temp_dict = copy.deepcopy(self.output)
            with open(out+'.dat', 'rb') as file:
                data = file.read(read_size)
                while data:
                    data_16b = np.frombuffer(data, dtype=np.uint16)
                    values = []
                    for i in range(self.output.index):                
                        if self.output.list[i] == 1:
                            values.append(u.to_current(data_16b[:1]))
                            data_16b = data_16b[1:]
                        elif self.output.list[i] == 3:
                            values.append(u.to_time(data_16b[:3]))
                            data_16b = data_16b[3:]

                    for key in self.output.keys():
                        temp_dict[key] = values[self.output[key]]

                    writer.writerow(temp_dict)
                    data = file.read(read_size)

    def print_info(self):
        # Print output info
        print(f"""
====== Execution Summary ======
Total commands:   {self.code.size}
Output size:      {self.output.size*2} bytes
Execution time:   {u.to_pretty(self.run_time)}
===============================""")

    def generate_code(self, out, every):
        """Generate verilog memory file, used in host simulation
        """
        with open(out+'.mem1', 'w') as file:
            mem = u.to_byte(self.code)
            length = len(mem)
            for i in range(int(length/4)):
                file.write('{:02x} {:02x} {:02x} {:02x}\n'\
                    .format(mem[4*i], mem[4*i+1], mem[4*i+2], mem[4*i+3]))

        with open(out+'.mem2', 'w') as file:
            mem = u.to_byte(u.to_tick(every), 6)
            for v in mem:
                file.write('{:02x} '.format(v))

# Lagacy method, will be discraded
def execute(func, out='tmp', every=0, total=0):
    se = session()
    se.compile(func)
    se.execute(out=out, every=every, total=total)
    se.convert(out=out)

def execute_debug(func, out='tmp', every=0, total=0):
    csvfile = open(out+'.csv', 'w', newline='')
    writer = None
    result = {}

    every_s = every/u.s
    total_s = total/u.s
    start_time = time.time()
    last_time = start_time
    while True:
        current_time = time.time()
        if current_time-start_time>total_s:
            break
        if current_time-last_time>every_s:
            last_time = current_time
            func(result)

            if writer is None:
                writer = csv.DictWriter(csvfile, fieldnames=result.keys())
                writer.writeheader()
                writer.writerow(result)
            else:
                writer.writerow(result)