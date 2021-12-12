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

    def __iadd__(self, other):
        return self.add(other)

    def add(self, other):
        if isinstance(other, np.ndarray):
            self.list = np.concatenate((self.list, other))
            self.size += other.shape[0]
        
        if isinstance(other, Session):
            self.list = np.concatenate((self.list, other.list))
            self.size += other.size

    def assign_output_index(self):
        self.output_index += 1

        return self.output_index

    def is_empty(self):
        return self.size > 0

    def print_binary(self):
        print("Operation")
        for ops in self.list:
            print("0x{:08X}".format(ops))


def allow_emulate(output=False):
    """Decorator allow formalize definition of atom operations.
    With output=False, there is no return value expected from operation.

    With output=True, single return value is expected. Depending on whether
    the operation is executed immediately or scheduled, the return value is
    handled by either blocking native python, or non-blocking okBTPipeOut
    through USB2.0 port.

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
                if output:
                    return session.assign_output_index()
            else:
                execute(code)
                if output:
                    return wait_output()

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

def wait_output():
    pass

from . import debug_device as device
from . import unit as u
from .statistics import get_runtime

class connect(object):
    def __enter__(self):
        device.initialize("../bin/1.0/TOP.bit")
        if not device.verify():
            raise RuntimeError("FPGA connection failed.")

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

def execute(run, every=0, total=0, out=None):
    global session
    new_session()

    with start_emulate():
        ret = run()

    run_time = 0
    for ops in session.list:
        run_time += get_runtime(ops)

    if run_time > every:
        __module_logger.warn(f'Execution may take longer than the given interval\
            {u.to_pretty(run_time)} > {u.to_pretty(every)}')

    # Print summary sheet
    print(f"""
======= Execution summary =======
Total lines:        {session.size}
Total output:       {session.output_index}
Execution time:     {u.to_pretty(run_time)}

Execution every:    {u.to_pretty(every)}
Total time:         {u.to_pretty(total)}
=================================
    """)

    #session.print_binary()
    #print(ret)