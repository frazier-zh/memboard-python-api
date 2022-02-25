import numpy as np
import logging

import time
from . import unit as u

import csv
import copy

__module_logger = logging.getLogger(__name__)

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
            __module_logger.warn(f'Execution may takes longer than the given interval {u.to_pretty(self.run_time)} > {u.to_pretty(self.every)}.')
            every = 1.5*self.run_time
            __module_logger.warn(f'Execution interval is set to {u.to_pretty(every)}.')

        self.print_info()
        print(f'Execute every {u.to_pretty(every)}, total {u.to_pretty(total)}.')

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
                            values.append(u.to_current(data_16b[0]))
                            data_16b = data_16b[1:]
                        elif self.output.list[i] == 3:
                            value = data_16b[2] *1e-5
                            value += data_16b[1] *0.65535
                            value += data_16b[0] *42949.67296
                            values.append(value)
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
