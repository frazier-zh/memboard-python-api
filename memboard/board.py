from pydoc import _OldStyleClass
from . import device
from .const import dev, state, op
from . import unit as u

from functools import wraps
import logging
__module_logger = logging.getLogger(__name__)

import numpy as np

# API code generate
class code:
    def convert(*args):
        """Convert to bytecode
        Args:
            [dev:4, op:4, addr:8, value:16/24], ...
            'value:size' indicates bit size of given Value.
        """
        code = np.zeros(len(args), dtype=np.uint32)
        for i, inst in enumerate(args):
            code[i] = inst[0]
            if len(inst) == 4:
                code[i] += (inst[1]<<4)+(inst[2]<<8)+(inst[3]<<16)
            elif len(inst) == 3:
                code[i] += (inst[1]<<4)+(inst[2]<<8)
            elif len(inst) == 2:
                code[i] += (inst[1]<<4)

        return code

    def adc(channel=0):
        if channel not in [0, 1]:
            raise ValueError("Invalid ADC channel.")
        return code.convert([dev.adc, op.enable, channel])

    def dac(channel=0, value=0x800):
        if channel not in range(4):
            raise ValueError("Invalid DAC channel.")
        if channel==0 and not value==0x800:
            __module_logger.warn("DAC channel 0 should always be set to 0x800.")
        if value not in range(0x1000):
            raise ValueError("Invalid DAC value, max 0xFFF.")

        return code.convert([dev['dac'], op['enable'], channel, value])

    def switch():
        pass

    def wait(time):
        """Ask FPGA to wait for a precise time period
        """
        time = int(time/(10*u.ns))
        if time<5 or (time>>48):
            raise ValueError("Invalid waiting time, max 30 days.")
        elif time>>24:
            return code.convert(
                [dev.timer, op.high, time>>24],
                [dev.timer, op.low, time % 0x1000000]
            )
        else:
            return code.convert([dev.timer, op.low, time % 0x1000000])

    def get_time():
        pass

    def get_adc():
        # TODO
        pass

# Board control
class board:
    def __init__(self):
        self.state = np.zeros()

    def open(self):
        device.open()
        device.load('./verilog/src/top.bit')

    def close(self):
        device.close()

    def reset(self):
        device.trigger_in(0x40, 0) # Reset logic block
        device.trigger_in(0x40, 1) # Reset memory block
        device.trigger_in(0x40, 2) # Reset fifo blocks

    def start(self):
        device.wire_in(0x00, 0b01)

    def start_auto(self):
        device.wire_in(0x00, 0b11) # Enable execution

    def wait_stop(time_out=1):
        start_time = time.time()
        while not get_state(dev.logic) == state.idle:
            if (time.time()-start_time > time_out):
                device.trigger_in(0x40, 0)
                raise TimeoutError('Time out while waiting on main logic.')
        stop()

    def stop(self):
        device.wire_in(0x00, 0b00) # Stop execution

    def set_prog(self, code):
        device.pipe_in(0x80, u.to_byte(code)) # Load program

    def set_clock(self, every):
        device.pipe_in(0x81, u.to_byte(u.to_tick(every), 6))# Load clock counter

    def get_count(self):
        return device.wire_out(0x20) # Check cycle count

    def get_state(self):
        state1 = device.read_wire_out(0x21)
        state2 = device.read_wire_out(0x22)

        self.state[dev.logic] = 
        

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

    def get_output(self, size): # Size in 2-bytes (int16)
        result = bytearray(size*2) # Pipe out container, bytes
        device.pipe_out(0xA0, result)
        return result


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
                set_prog(code)
                start()

                wait_stop()
                if size:
                    result = u.from_byte(get_output(size))
                    value = 0
                    for i in range(size):
                        value = (value<<16) + result[0]
                        result = result[1:]
                    return value

        return wrapper
    return decorator


"""Definition of atom operations
    Each operation coresponds to a basic FPGA function.

Notice:
        Evoke any decorated function directly using native function call
    will set the mode to block waiting. Only Memboard.execute(func) enables
    non-blocking execution with time presicion of micro-second.

    Although python under Linux provides micro-second presicion program
    control, for compatibility and FPGA stability, non-blocking mode is
    recommended on all platform.

    @allow_auto should always be used for any atom operation to be
    created in the future.
"""
def to_switch_group(pin):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-84).')
    group = int((pin-1)/28)
    pin_in_group = (pin-1)%28
    return group, pin_in_group

@allow_auto()
def switch(pin=0, y=0, on=False):
    """Switch control
    """
    if y not in range(3):
        raise ValueError("Invalid Y address.")
    if not isinstance(on, bool):
        raise ValueError("Invalid on/off value.")
    group, x = to_switch_group(pin)
    return to_code([dev.sw_source+group, op.enable, 0, x+(y<<7)+(on<<11)])

@allow_auto(size=3)
def time():
    """Get precise time from FPGA
    """
    return to_code([dev.clock])

@allow_auto()
def reset(device):
    return to_code([device, op.reset])

"""Definition of compound operation
    Each compound operation consists of multiple atom operation.
    @allow_auto is not allowed to use, since only atom operations are
allowed to register return value on FPGA.
"""
def reset_all():
    reset(dev.adc)
    reset(dev.dac)
    reset(dev.sw_source)
    reset(dev.sw_gate)
    reset(dev.sw_drain)

#   switch  GND     DAC     ADC
switch_connection = {
    0: [0,      2,      0],
    1: [-1,     1,      -1],
    2: [-1,     3,      1]
}

def ground(pin):
    group, _ = to_switch_group(pin)
    if [group][0]==-1:
        raise ValueError(f"Pin {pin} cannot connect to ground, use DAC instead.")
    else:
        switch(pin=pin, y=0, on=True)

def apply(pin, v=None):
    """Apply voltage on given terminal
    1. determine DAC channel and switch number
    3. enable switch for connection setup
    2. enable DAC for voltage setup

    Args:
        pin (int): pin number
        voltage (float): voltage value
    """
    group, _ = to_switch_group(pin)
    channel = switch_connection[group][1]

    switch(pin=pin, y=1, on=True)
    
    # Just connect to DAC if voltage is not given
    if v is not None:
        dac(channel=channel, value=u.to_int(v))
    else:
        __module_logger.warn(f'Pin {pin} is connected to DAC-{channel}.')

def measure(pin, drive_pin=None, v=None):
    # ADC
    group, _ = to_switch_group(pin)
    channel = switch_connection[group][2]
    # DAC
    if drive_pin:
        drive_group, _ = to_switch_group(drive_pin)
        drive_channel = switch_connection[drive_group][1]

    # Turn on DAC/ADC connections
    switch(pin=pin, y=2, on=True)
    if drive_pin:
        switch(pin=drive_pin, y=1, on=True)

    # Apply voltage
    if drive_pin:
        dac(channel=drive_channel, value=u.to_int(v))
        wait(5 *u.us)
    ret = adc(channel=channel)

    # Turn off DAC before switching off to eliminate charging effect
    if drive_pin:
        dac(channel=drive_channel, value=0x800)
        wait(1 *u.us)

    # Turn off DAC/ADC connections
    if drive_pin:
        switch(pin=drive_pin, y=1, on=False)
    switch(pin=pin, y=2, on=False)

    return ret
