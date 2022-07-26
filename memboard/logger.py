from concurrent.futures import thread
import threading
import time
import pandas as pd
import csv
from enum import IntEnum

import numpy as np

class State(IntEnum):
    STOPPED = 1
    ACTIVE = 2
    STOPPING = 3
    STARTING = 4

class LoggerBase(threading.Thread):
    def __init__(self, interval=0.005):
        super(LoggerBase, self).__init__()
        self.updated = threading.Event()

        self._request_stop = threading.Event()
        self._request_start = threading.Event()
        self._request_exit = threading.Event()

        self.state = State.STOPPED

        self.t = 0
        self.t_int = interval

    def run(self):
        self.state = State.STARTING

        while True:
            if self._request_exit.is_set():
                break
            try:
                if self.state == State.STARTING:
                    self.state = State.ACTIVE

                    self._request_stop.clear()
                    self._request_start.clear()

                    self.t_start = time.time()
                    self.init()

                elif self.state == State.ACTIVE:
                    if self._request_stop.is_set():
                        self.state = State.STOPPING
                    else:
                        self.t = time.time()-self.t_start
                        self.update(self.t)
                        self.updated.set()

                elif self.state == State.STOPPING:
                    self.state = State.STOPPED

                elif self.state == State.STOPPED:
                    if self._request_start.is_set():
                        self.state = State.STARTING

                time.sleep(self.t_int)
            except:
                raise

    def update(self, t):
        pass

    def init(self, t_start):
        pass

    def exit(self):
        self._request_exit.set()

    def stop(self):
        self._request_stop.set()

    def restart(self):
        self._request_start.set()

    def is_active(self):
        return (self.state == State.ACTIVE)

# For API verison local-testing
# Reciving data format
#   | 32 bits   | 16 bits   | 16 bits   |
#   | Time      | Value     | Value     |
from .device import FrontPanel
import struct

class Data:
    def __init__(self, shape, size=65536, dtype=float):
        if isinstance(shape, int):
            self.shape = (size, shape)
        else:
            self.shape = (size, *shape)

        self.idx_max = size-1
        self.data = np.empty(shape=self.shape, dtype=dtype)

        self.idx = 0
    
    def append(self, item):
        self.data[self.idx] = item
        self.idx = self.idx+1 if self.idx<self.idx_max else 0

    def iter_append(self, iter):
        for item in iter:
            self.data[self.idx] = item
            self.idx = self.idx+1 if self.idx<self.idx_max else 0

    def get(self, dtype=np.float32) -> np.ndarray:
        return np.roll(self.data, -self.idx, axis=0).astype(dtype)

    def clear(self):
        self.idx = 0
        self.data[...] = 0

def to_voltage(data_16b):
    sign = data_16b & 0x2000 # negative
    if sign:
        data_16b = 0x3FFF-data_16b+1

    voltage = (float(data_16b)/0x2000) * 10
    return (-1 if sign else 1) * voltage

class TestLogger(LoggerBase):
    def __init__(self, device: FrontPanel, path='test.bin', *args,  **kwargs):
        super(TestLogger, self).__init__(*args, **kwargs)

        self.device = device
        self.path = path
        self.data = Data(shape=3)

        self.file = open(self.path, 'wb')

    def update(self, t):
        try:
            self.device.Update()
            new_entry = self.device.GetWireOutValue(0x20) # read fifo data count
            if new_entry == 0:
                return

            data = bytearray(2 * new_entry)
            self.device.ReadFromPipeOut(0xA0, data)
            data[0::2], data[1::2] = data[1::2], data[0::2] # Swap byte order for FP API
            
            self.file.write(data) # write to binary file
            self.file.flush() # flush for instant file update

            # acquire on-board clock
            if self.dt_start == -1:
                self.dt_start = struct.unpack('>IHH', data[:8])[0]

            # snapshot last data packet
            last_data = struct.unpack('>IHH', data[-8:])
            self.dt = self.device.ConvertTime(last_data[0]-self.dt_start)
            v_ch0 = to_voltage(last_data[1])
            v_ch1 = to_voltage(last_data[2])

            self.data.append([self.dt, v_ch0, v_ch1])

        except RuntimeError:
           return

    def init(self):
        self.dt_start = -1
        self.data.clear()
