from bisect import bisect_right
import warnings
import numpy as np
import re
import pandas as pd
import asyncio

from .board import Board, Ins
from .parser import Parser
from .const import TerminalType

class Listing():
    def __iter__(self):
        return self

    def __next__(self):
        raise StopIteration

class Array(Listing):
    def __init__(self, wordline, bitline) -> None:
        self.wl = np.array(wordline)
        if len(self.wl.shape) == 1:
            self.wl = self.wl[np.newaxis, ...]
        elif len(self.wl.shape) != 2:
            raise ValueError(f'Unexpected wordline definition.')
        self.w_wl, self.n_wl = self.wl.shape

        self.bl = np.array(bitline)
        if len(self.bl.shape) == 1:
            self.bl = self.bl[np.newaxis, ...]
        elif len(self.bl.shape) != 2:
            raise ValueError(f'Unexpected bitline definition.')
        self.w_bl, self.n_bl = self.bl.shape

    def __iter__(self):
        self._idx_wl = 0
        self._idx_bl = 0
        return self

    def __next__(self):
        ret_list = [self.wl[i, self._idx_wl] for i in range(self.w_wl)] +\
            [self.bl[i, self._idx_bl] for i in range(self.w_bl)]

        self._idx_bl += 1
        if self._idx_bl >= self.n_bl:
            self._idx_bl = 0
            self._idx_wl += 1
            if self._idx_wl >= self.n_wl:
                raise StopIteration
        return ret_list

class Sequence(Listing):
    def __init__(self, data=None, file: str=None) -> None:
        if data is not None:
            data = np.array(data, dtype=float)
            dim = len(data.shape)
            if dim > 2:
                raise ValueError(f'Excessive sequence dimension {dim}>2.')
            self.data = data
            self.size = data.shape[0]
        elif file:
            self.load(file)
        else:
            raise ValueError(f'Invalid sequence.')

    def load(self, file):
        f = open(file)
        lines = f.readlines()
        data = []
        if re.match(',', lines[0]):
            sep = ','
        else:
            sep = ' '
        for line in lines:
            if re.match('[a-zA-Z]+', line):
                break
            temp = np.fromstring(line, sep=sep)
            if len(temp):
                data.append(temp)
        self.data = np.array(data)
        self.size = data.shape[0]

    def __iter__(self):
        self._idx = 0
        return self

    def __next__(self):
        ret = self.data[self._idx]
        self._idx += 1
        if self._idx > self.size:
            raise StopIteration
        return ret

class PulseSequence(Sequence):
    def __init__(self, *args) -> None:
        pulses = list(args)
        pulses.sort(key=lambda x: x[1])

        t_list = [0]
        v_list = [0]
        for p in pulses:
            if len(p) != 3:
                raise ValueError(f'Invalid pulse definition {p}, expected [v, t_start, pulse_width].')

            v, ts, pw = p
            te = ts + pw
            if pw<0:
                raise ValueError(f'Invalid pulse definition {p}, pulse width {pw}<0.')
            if ts<t_list[-1]:
                raise ValueError(f'Overlapped pulse definition {p}.')
            if ts==t_list[-1]:
                v_list[-1] = v
            else:
                t_list.append(ts)
                v_list.append(v)
            t_list.append(te)
            v_list.append(0)

        data = np.array([t_list, v_list]).transpose()

        super().__init__(data)

class Terminal():
    def __init__(self, name, type: TerminalType) -> None:
        self.name = name
        self.type = type
        self.sequence = None
    
    def set(self, data):
        if isinstance(data, Sequence):
            self.sequence = data
        else:
            self.sequence = Sequence(data)

class Procedure():
    async def update(self, q: asyncio.Queue):
        pass

    def compile(self):
        pass

class MultiDeviceScan(Procedure):
    class Output():
        def __init__(self) -> None:
            self.n_dev = 0

            self.expr_list = {}
            self.data = None

        def init(self, terminal, n_dev, n_repeat=1):
            self.variable = dict.fromkeys(['t']+list(terminal.keys()))

            time = None
            self.sense_list = []
            self.force_list = []
            for t in terminal.values():
                if (time is None) and (t.type == TerminalType.Sense):
                    time = t.sequence
                    self.sense_list.append(t.name)
                elif t.type == TerminalType.Force:
                    self.force_list.append(t.name)
            if time is None:
                warnings.warn('No sensing sequence.', RuntimeWarning)
                time = [0]

            constant = [time]
            for name in self.force_list:
                if terminal[name].sequence is None:
                    warnings.warn(f'No forcing sequence on terminal {name}, set to GND.')
                terminal[name].sequence = PulseSequence([0, 0, 0])
                seq = terminal[name].sequence.data
                constant.append([seq[bisect_right(seq, t)-1] for t in time])
            self.constant = pd.DataFrame(np.array(constant).transpose(), columns=['t']+self.force_list)

            self.n_dev = n_dev
            self.n_repeat = n_repeat
            self.n_time = len(time)
            constant_columns = pd.MultiIndex.from_product([[0], ['t']+self.force_list], names=['dev', 'var'])
            variable_columns = pd.MultiIndex.from_product([np.arange(n_dev), self.sense_list+list(self.expr_list.keys())], names=['dev', 'var'])
            
            self.columns = constant_columns.append(variable_columns)
            self.rows = pd.MultiIndex.from_product([np.arange(n_repeat), np.arange(len(time))], names=['repeat', 'i'])

            self.data = pd.DataFrame(0, index=self.rows, columns=self.columns)
            self.data.loc[:, 0] = self.constant

            self.loc = (0, 0)

        def update(self, repeat, time, dev, term, data):
            time_diff = self.constant[0, 't']-time
            idx = time_diff.abs().argmin()
            if (idx, dev) != self.loc:
                self.eval_expr()
                self.loc = (idx, dev)
            if repeat>=self.n_repeat:
                warnings.warn(f'Data overflow.')
            self.data.loc[(repeat, idx), (dev, term)] = data

        # def del_expr(self, name):
        #     if name in self.expr_list:
        #         del self.expr_list[name]

        def add_expr(self, name, expr_str):
            expr_parser = Parser()
            if name in self.expr_list:
                raise ValueError(f'Duplicated expression definition {name}, was {name}={str(self.expr_list[name])}')
            try:
                expr = expr_parser.parse(expr_str)
            except Exception:
                raise ValueError(f'Syntax check failed \"{expr_str}\".')
            for v in expr.variables():
                if not v in self.variable:
                    raise ValueError(f'Invalid variable {v}.')
            self.expr_list[name] = expr
            self.variable[name] = None

        def eval_expr(self):
            var = self.data.iloc[0].loc[0, self.force_list].append(self.data.iloc[0].loc[0, :])
            var = var.droplevel('dev')
            var[self.sense_list] = 1
            var = var.to_dict()


    def __init__(self, name='', file=None) -> None:
        self.name = name

        self.terminal = {}
        self.device = []
        self.output = MultiDeviceScan.Output()

        if file is not None:
            self.load(file)

    def set_terminal(self, **kwargs):
        self.terminal.clear()
        for name, type in kwargs.items():
            if name in self.terminal:
                raise ValueError(f'Duplicated terminal definition {name}, was {name}={self.terminal[name].type.name}.')
            if type == 'sense':
                self.terminal[name] = Terminal(name, TerminalType.Sense)
            elif type == 'force':
                self.terminal[name] = Terminal(name, TerminalType.Force)
            else:
                raise ValueError(f'Unexpected terminal type {name}={type}, expected force/sense.')

    def force(self, **kwargs):
        for name, sequence in kwargs.items():
            if not name in self.terminal:
                raise ValueError(f'Invalid terminal {name}.')
            if self.terminal[name].type == TerminalType.Force:
                self.terminal[name].set(sequence)
            else:
                raise ValueError(f'Unexpected forcing on sensing terminal {name}.')

    def sense(self, data):
        for t in self.terminal.values():
            if t.type == TerminalType.Sense:
                t.set(data)

    def add_device(self, devices):
        for dev in devices:
            if len(dev) == len(self.terminal):
                self.device.append(dev)
            else:
                raise ValueError(f'Mismatch of terminal number, expected {self.terminal.keys()}.')

    def print_device(self):
        for t in self.terminal:
            print(t, end='\t')
        print('')
        for dev in self.device:
            for t in dev:
                print(t, end='\t')
            print('')

    def load(self, file: str):
        pass

    def save(self, file: str):
        pass

    def compile(self):
        pass