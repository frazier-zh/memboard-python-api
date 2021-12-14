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
        self.list = np.zeros(1, dtype=np.uint32)
        self.size = 0
        self.output_index = 0
        self.output_list = []
        self.ret = None

    def __iadd__(self, other):
        return self.add(other)

    def register_code(self, other):
        if isinstance(other, np.ndarray):
            self.list = np.concatenate((self.list, other))
            self.size += other.shape[0]
        
        if isinstance(other, Session):
            self.list = np.concatenate((self.list, other.list))
            self.size += other.size

    def get_code(self):
        return self.list

    def assign_output(self, bytes=0):
        self.output_index += 1
        self.output_list.append(bytes)
        return self.output_index

    def register_output(self, ret):
        self.ret = ret

    def get_output(self):
        return 

    def clear(self):
        pass

__session = Session()

def allow_emulate(output_bytes=0):
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
                __session.register_code(code)
                return __session.assign_output(output_bytes)
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

class connect(object):
    def __init__(self, path, debug=False):
        self.path = path
        device.debug(debug)

    def __enter__(self):
        device.open()
        device.load(self.path)

    def __exit__(self, exc_type, exc_value, tb):
        device.close()
        device.debug(False)

        if exc_type is not None:
            return False
        else:
            return True

import pickle

def clear():
    global __session
    __session.clear()

def register(run):
    global __session

    with start_emulate():
        ret = run()
    __session.register_output(ret)

def execute(every=0, total=0, out='temp'):
    global __session

    run_time = 0
    for ops in __session.list:
        run_time += get_runtime(ops)

    if run_time > every:
        __module_logger.warn(f'Execution takes longer than the given interval\
            {u.to_pretty(run_time)} > {u.to_pretty(every)}')
        every = 1.5 * run_time
        __module_logger.warn(f'Execution interval is set to {u.to_pretty(every)}')

    # Print output info
    print(f"""
======== Execution Summary ========
Total lines:        {__session.size}
Total output:       {__session.output_index}
Execution time:     {u.to_pretty(run_time)}

Execution every:    {u.to_pretty(every)}
Total time:         {u.to_pretty(total)}

Output file:        ./{out}.dat
                    ./{out}.pkl
===================================
    """)

    device.trigger_in(0x40, 0) # Reset logic block
    device.trigger_in(0x40, 1) # Reset memory block

    device.pipe_in(0x81, device.to_byte_single(device.to_tick(every), 6))# Load clock counter
    device.pipe_in(0x80, device.to_byte(__session.list)) # Load program

    data_result = bytearray(__session.output_list.count(2)*2) # Pipe out container
    time_result = bytearray(__session.output_list.count(6)*6) # Pipe out container

    device.wire_in(0x00, 1) # Enable execution
    start_time = time.time()
    stop_time = total/u.s
    with open(out+'.dat', 'wb') as file:
        while time.time()-start_time<stop_time:
            if device.wait_trigger_out(0x60, 0):
                device.pipe_out(0xA1, time_result)
                device.pipe_out(0xA0, data_result)
                file.write(time_result)
                file.write(data_result)
        device.wire_in(0x00, 0) # Stop execution

"""For debug purpose only
"""
def output_mem(path='./'):
    global __session
    with open(path+'code.mem', 'w') as file:
        code = device.to_byte(__session.list)
        length = len(code)
        for i in range(int(length/4)):
            file.write('{:02x} {:02x} {:02x} {:02x}\n'\
                .format(code[4*i], code[4*i+1], code[4*i+2], code[4*i+3]))