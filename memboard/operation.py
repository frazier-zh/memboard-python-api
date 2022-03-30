from .base import allow_auto
from .const import dev, op
import logging
from . import unit as u

__module_logger = logging.getLogger(__name__)

import numpy as np

def to_code(*args):
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
@allow_auto(size=1)
def adc(channel=0):
    """ADC control
    """
    if channel not in [0, 1]:
        raise ValueError("Invalid ADC channel.")
    return to_code([dev.adc, op.enable, channel])

@allow_auto()
def dac(channel=0, value=0x800):
    """DAC control
    """
    if channel not in range(4):
        raise ValueError("Invalid DAC channel.")
    if channel==0 and not value==0x800:
        __module_logger.warn("DAC channel 0 should always be set to 0x800.")
    if value not in range(0x1000):
        raise ValueError("Invalid DAC value, max 0xFFF.")

    return to_code([dev.dac, op.enable, channel, value])

@allow_auto(size=10)
def wait(time):
    """Ask FPGA to wait for a precise time period
    """
    time = int(time/(10*u.ns))
    if time<5 or (time>>48):
        raise ValueError("Invalid waiting time, max 30 days.")
    elif time>>24:
        return to_code(
            [dev.timer, op.high, time>>24],
            [dev.timer, op.low, time % 0x1000000]
        )
    else:
        return to_code([dev.timer, op.low, time % 0x1000000])

def to_switch_group(pin):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-84).')
    group = int((pin-1)/28)
    pin_in_group = (pin-1)%28
    return group, pin_in_group

@allow_auto()
def switch(pin=0, y=0, on=True):
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
        dac(channel=channel, value=u.to_value(v))
    else:
        __module_logger.warn(f'Pin {pin} is connected to DAC-{channel} by default.')

def measure(pin, drive_pin=None, v=None, width=1*u.us):
    group, _ = to_switch_group(pin)
    channel = switch_connection[group][2]

    # Turn on DAC/ADC connections
    switch(pin=pin, y=2, on=True)
    if drive_pin is not None:
        apply(drive_pin, v)

    wait(width)
    ret = adc(channel=channel)

    # Turn off DAC/ADC connections
    if drive_pin is not None:
        apply(drive_pin, 0)
        switch(pin=drive_pin, y=1, on=False)
    switch(pin=pin, y=2, on=False)

    return ret
