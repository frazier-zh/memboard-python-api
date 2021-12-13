import numpy as np
import logging
from functools import wraps

__module_logger = logging.getLogger(__name__)


session = None
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

    def add(self, other):
        if isinstance(other, np.ndarray):
            self.list = np.concatenate((self.list, other))
            self.size += other.shape[0]
        
        if isinstance(other, Session):
            self.list = np.concatenate((self.list, other.list))
            self.size += other.size

    def assign_output_index(self, bytes=0):
        self.output_index += 1
        self.output_list.append(bytes)
        return self.output_index

    def is_empty(self):
        return self.size > 0

    def define_return(self, ret):
        self.ret = ret

    def print_binary(self):
        for ops in self.list:
            print(" > ", ops.to_bytes(4, 'big'))

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
            global session

            if is_emulate():
                session.add(code)
                return session.assign_output_index(output_bytes)
            else:
                execute_once(code)
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
    def __init__(self, path):
        self.path = path

    def __enter__(self):
        device.open()
        device.load(self.path)

    def __exit__(self, exc_type, exc_value, tb):
        device.close()

        if exc_type is not None:
            return False
        else:
            return True
    
def new_session():
    global session
    if session is not None:
        if not session.is_empty():
            __module_logger.warn('Previous session was discarded!')
        else:
            return
    session = Session()

def execute_once(code):
    pass

import pickle

def execute(run, every=0, total=0, out='temp'):
    global session
    new_session()

    with start_emulate():
        ret = run()
    session.define_return(ret)

    run_time = 0
    for ops in session.list:
        run_time += get_runtime(ops)

    if run_time > every:
        __module_logger.warn(f'Execution takes longer than the given interval\
            {u.to_pretty(run_time)} > {u.to_pretty(every)}')
        every = 1.5 * run_time
        __module_logger.warn(f'Execution interval is set to {u.to_pretty(every)}')

    # Print output info
    print(f"""
======= Output list =======
Total lines:        {session.size}
Total output:       {session.output_index}
Execution time:     {u.to_pretty(run_time)}

Execution every:    {u.to_pretty(every)}
Total time:         {u.to_pretty(total)}

Output file:        ./{out}.dat
                    ./{out}.pkl
=================================
    """)
    with open(out+'.pkl', 'wb') as file:
        pickle.dump(ret, file)

    device.trigger_in(0x40, 0) # Reset logic block
    device.trigger_in(0x40, 1) # Reset memory block

    device.pipe_in(0x81, device.to_byte_single(device.to_tick(every), 6))# Load clock counter
    device.pipe_in(0x80, device.to_byte(session.list)) # Load program

    data_result = bytearray(session.output_list.count(2)*2) # Pipe out container
    time_result = bytearray(session.output_list.count(6)*6) # Pipe out container

    device.wire_in(0x00, 1) # Enable execution
    start_time = time.time()
    stop_time = total/u.s
    with open(out+'.dat', 'wb') as file:
        while time.time()-start_time<stop_time:
            if device.wait_trigger_out(0x60):
                device.pipe_out(0xA1, time_result)
                device.pipe_out(0xA0, data_result)
                file.write(time_result)
                file.write(data_result)
        device.wire_in(0x00, 0) # Stop execution