from dataclasses import dataclass
from functools import wraps

from . import device
from . import const
from .const import OP, Port, State
from . import unit
import time
import csv
import asyncio

from bitarray import bitarray
from bitarray.util import int2ba as i2b
from bitarray.util import ba2int as b2i

import logging
__logger = logging.getLogger(__name__)

import numpy as np

class Output:
    def __init__(self):
        self.index = 0
        self.list = []
        self.size = 0

    def add(self, name, size, func):
        if name == '':
            name = f'x{self.index}'
        self.list.append((name, size, func))
        self.index += 1
        self.size += size

    def clear(self):
        self.list.clear()
        self.index = 0
        self.size = 0

    def convert(self, data, out):
        read_size = self.size*2
        with open(out+'.csv', 'w', newline='') as csvfile:
            fieldnames = [item[0] for item in self.list]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()

            temp = {}
            with open(out+'.dat', 'rb') as file:
                data = file.read(read_size)
                while data:
                    data_16b = np.frombuffer(data, dtype=np.uint16)
                    for i in range(self.index):
                        name = self.list[i][0]
                        size = self.list[i][1]
                        func = self.list[i][2]
                        temp[name] = func(data_16b[:size])
                        data_16b = data_16b[size:]

                    writer.writerow(temp)
                    data = file.read(read_size)

# API code OP class
@dataclass
class Ins:
    op: OP
    rst_flag: bool = False
    en_flag: bool = False
    tic_flag: bool = False
    ext_flag: bool = False
    data: int = 0
    tic: int = 0

    def code(self):
        c = i2b(self.op, 4)
        c = bitarray([self.tic_flag, self.ext_flag, self.en_flag, self.rst_flag]).extend(c)
        c = i2b(self.data, 24).extend(c)
        if self.tic_flag:
            c.extend(i2b(self.tic, 32))
        return c

def executable(method):
    @wraps(method)
    def wrapper(ref, *args, **kwargs):
        inst = method(ref, *args, **kwargs)

        if ref.debug_mode:
            return ref.execute(inst)
        else:
            ref.inst.append(inst)
    return wrapper

# Board control
class Board:
    # Basic board operation
    def __init__(self):
        self.state = np.zeros(len(OP), dtype=np.uint8)
        #self.dac = np.zeros(4, dtype=np.uint16)
        self.connection = np.zeros((6, 16, 8), dtype=bool)

        self.debug_mode = False
        self.inst = []

        self.force_mode = True
        self.time_out = 1 *unit.s

        #self.verbose = 'socket'

    def open(self):
        device.open()
        device.load('./verilog/src/top.bit')
        self.reset()
        self.reset(OP.adc)
        self.reset(OP.dac)
        self.reset(OP.switch)

    def close(self):
        device.close()

    def reset(self, Mode: OP=OP.logic):
        if Mode == OP.logic:
            device.trigger_in(0x40, 0) # Reset logic block
            device.trigger_in(0x40, 1) # Reset memory block
            device.trigger_in(0x40, 2) # Reset fifo blocks
        elif Mode == OP.adc:
            self.adc(reset=True)
        elif Mode == OP.dac:
            self.dac(reset=True)
        elif Mode == OP.switch:
            self.switch(reset=True)

        self.connection.fill(0)

    def start(self):
        device.wire_in(0x00, 0b01)

    # def start_auto(self):
    #     device.wire_in(0x00, 0b11) # Enable execution

    def stop(self):
        device.wire_in(0x00, 0b00) # Stop execution

    def load_prog(self, code):
        device.pipe_in(0x80, unit.to_byte(code)) # Load program

    # def load_clock(self, every):
    #     device.pipe_in(0x81, unit.to_byte(unit.to_tick(every), 6))# Load clock counter

    # def read_count(self):
    #     return device.wire_out(0x20) # Check cycle count

    async def update(self, q: asyncio.Queue):
        pass

    # Main execution
    async def _execute(self, test: Procedure):
        queue = asyncio.Queue()
        task_recieve = asyncio.create_task(self.update(queue))
        task_process = asyncio.create_task(test.update(queue))
        await task_recieve
        await queue.join()
        task_process.cancel()

    def execute(self, test: Procedure):
        try:
            self.load_prog(test.compile())
            self.start()
            asyncio.run(self._execute(test))
            # start_time = time.time()
            # while (time.time()-start_time < self.time_out):
            #     self.read_state()
            #     if (self.state[OP.logic] == State.idle):
            #         __logger.info('Execution succeeded.')
    
            # self.stop()
            # self.read_state()
            # if (self.state[OP.logic] != State.idle):
            #     __logger.error(f'Execution failed. <L:{self.state[OP.logic]} | A:{self.state[OP.adc]} | D:{self.state[OP.dac]} | S:{self.state[OP.switch]}>')
            #     self.reset(OP.logic)
        except KeyboardInterrupt:
            self.stop()
            __logger.warning('KeyboardInterrupt catched, stopping execution.')
        except RuntimeError:
            self.stop()

    # Components control
    @executable
    def adc(self, reset=False, channel=0):
        if reset:
            return Ins(OP.adc, rst_flag=True)
        if channel not in range(2):
            raise ValueError("Invalid ADC channel.")
        return Ins(OP.adc, en_flag=True, data=channel)
            
    @executable
    def dac(self, reset=False, channel=0, value=0x800):
        if reset:
            return Ins(OP.dac, rst_flag=True)
        if channel not in range(4):
            raise ValueError("Invalid DAC channel.")
        if value not in range(0x1000):
            raise ValueError("Invalid DAC value, max 0xFFF.")
        return Ins(OP.dac, en_flag=True, ext_flag=True, data=channel, ext=value)

    @executable
    def switch(self, reset=False, no=0, x=0, y=0, on=False):
        if reset:
            return Ins(OP.switch, rst_flag=True)
        if no not in range(6):
            raise ValueError("Invalid switch number.")
        if x not in range(32):
            raise ValueError("Invalid X address.")
        if y not in range(8):
            raise ValueError("Invalid Y address.")
        if not isinstance(on, bool):
            raise ValueError("Invalid on/off value.")
        self.connection[no, x, y] = on
        return Ins(OP.switch, en_flag=True, ext_flag=True, data=no, ext=x+(y<<6)+(on<<9))

    @executable
    def sleep(self, value):
        return Ins(OP.sleep, tic_flag=True, tic=value)

    # Functions
    def apply(self, pin: Port, v=None):
        """Apply voltage on given terminal
        1. determine DAC channel and switch number
        2. enable switch for connection setup
        3. enable DAC for voltage setup
        Args:
            pin (int): pin number
            voltage (float): voltage value
        """
        channel, sw_y = const.get_channel(OP.dac, pin.sw_no)

        if self.force_mode:
            __logger.info(f'<FORCE> Opening connection for {pin} and DAC-{channel}.')
            self.switch(no=pin.sw_no, x=pin.sw_x, y=sw_y, on=True)
            self.dac(channel=channel, value=unit.to_value(v))
        else:
            if self.connection[pin.sw_no, pin.sw_x, sw_y]:
                __logger.info(f'{pin} was connected to DAC-{channel}.')
            else:
                __logger.info(f'Opening connection for {pin} and DAC-{channel}.')
                self.switch(no=pin.sw_no, x=pin.sw_x, y=1, on=True)

            if v is not None:
                self.dac(channel=channel, value=unit.to_value(v))
            else:
                __logger.info(f'{pin} is connected to DAC-{channel}.')

    def shut(self, pin: Port):
        if self.force_mode:
            __logger.info(f'<FORCE> Closing all connections to {pin}.')
            self.switch(no=pin.sw_no, x=pin.sw_x, y=0)
            self.switch(no=pin.sw_no, x=pin.sw_x, y=1)
            self.switch(no=pin.sw_no, x=pin.sw_x, y=2)
        else:
            __logger.info('Closing all connections to {pin}.')
            sw_ys = np.where(self.connection[pin.sw_no, pin.sw_x])
            for sw_y in sw_ys:
                self.switch(no=pin.sw_no, x=pin.sw_x, y=sw_y)

    def measure(self, pin: Port, drive_pin: Port=None, v=None):
        """Measure current
        pin can be assign to measure specific terminal.
        drive_pin can be assigned to supply the measurement.
        """
        # ADC
        channel, sw_y = const.get_channel(OP.adc, pin.sw_no)
        if channel == -1:
            __logger.error(f'ADC is unavailable for {pin}.')
        else:
            self.switch(no=pin.sw_no, x=pin.sw_x, y=sw_y, on=True)
        # DAC
        if drive_pin:
            self.apply(drive_pin, v)
            self.sleep(1 * unit.us)

        self.adc(channel=channel)

        # Turn off DAC before switching off to eliminate charging effect
        if drive_pin:
            self.apply(drive_pin, 0)
            self.shut(drive_pin)
        self.shut(pin)
