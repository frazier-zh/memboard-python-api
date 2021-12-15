from .base import allow_emulate
import logging

__module_logger = logging.getLogger(__name__)

import numpy as np

def to_code(*args):
    """Convert to bytecode
    Args:
        [[width, value], ...], ...
        Width indicates bit width of given Value.
    """
    code = np.zeros(len(args), dtype=np.uint32)
    for i, arg in enumerate(args):
        shift = 0
        value = 0
        for nbit_value in arg:
            value += (nbit_value[1] % (1<<nbit_value[0])) << shift
            shift += nbit_value[0]

        value = int(value)
        code[i] = value % 0x100000000

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

    @allow_emulate should always be used for any atom operation to be
    created in the future.
"""
@allow_emulate(width=1)
def adc(channel=0):
    """ADC control
    """
    if channel not in [0, 1]:
        raise ValueError("Invalid ADC channel.")
    return to_code([[4, 1], [4, 2], [8, channel]])

@allow_emulate()
def dac(channel=0, value=0x800):
    """DAC control
    """
    if channel not in range(4):
        raise ValueError("Invalid DAC channel.")
    if channel==0 and not value==0x800:
        __module_logger.warn("DAC channel 0 should always be set to 0x800.")
    if value not in range(0x1000):
        raise ValueError("Invalid DAC value, max 0xFFF.")

    return to_code([[4, 2], [4, 2], [8, channel], [16, value]])

@allow_emulate()
def wait(time):
    """Ask FPGA to wait for a precise time period
    """
    time = int(time/10)
    if time<0 or (time>>48):
        raise ValueError("Invalid waiting time, max= 30 days.")
    elif time>>24:
        return to_code(
            [[4, 3], [4, 1], [24, time>>24]],
            [[4, 3], [4, 0], [24, time % 0x1000000]]
        )
    else:
        return to_code([[4, 3], [4, 0], [24, time]])

def to_switch_group(pin):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-86).')
    group = int((pin-1)/28)
    pin_in_group = (pin-1)%28
    return group, pin_in_group

@allow_emulate()
def switch(pin=0, y=0, on=False):
    """Switch control
    """
    if y not in range(3):
        raise ValueError("Invalid Y address.")
    if not isinstance(on, bool):
        raise ValueError("Invalid on/off value.")
    group, x = to_switch_group(pin)

    return to_code([[4, 4+group], [4, 2], [8, 0], [8, x], [4, y], [4, on]])

@allow_emulate(width=3)
def time():
    """Get precise time from FPGA
    """
    return to_code([[4, 7]])

device_list = {
    'adc' : 1,
    'dac' : 2,
    'source': 4,
    'gate': 5,
    'drain': 6
}
@allow_emulate()
def reset(device):
    if device == 'all':
        return to_code(*[[[4, i], [4, 1]] for i in device_list.values()])
    elif device not in device_list:
        raise ValueError("Invalid device for reset operation.")
    else:
        return to_code([[4, device_list[device]], [4, 1]])

"""Definition of compound operation
    Each compound operation consists of multiple atom operation.
    In non-blocking mode, for-statement and if-else statement is allowed but
is only inferenced once during repeated execution. Inferring based on return
value from atom operation is invalid, since all the values are asynchromatic
reduced.
    In blocking mode, atom operations are returned when and only when FPGA
finishes, and return values are immediately valid.
    @allow_emulate is not allowed to use, since only atom operations are
allowed to register return value on FPGA.
"""
def reset_all():
    reset('adc')
    reset('dac')
    reset('source')
    reset('gate')
    reset('drain')

#   switch  GND     DAC     ADC
switch_connection = {
    0: [0,      1,      0],
    1: [-1,     2,      -1],
    2: [-1,     3,      1]
}

from .statistics import to_int, to_voltage
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
        dac(channel=channel, value=to_int(v))
    else:
        __module_logger.warn(f'Pin {pin} is connected to DAC-{channel} by default.')

def measure(pin, drive_pin=None, v=None):
    group, _ = to_switch_group(pin)
    channel = switch_connection[group][2]

    # Turn on DAC/ADC connections
    switch(pin=pin, y=2, on=True)
    if drive_pin is not None:
        apply(drive_pin, v)

    ret = adc(channel=channel)

    # Turn off DAC/ADC connections
    if drive_pin is not None:
        switch(pin=drive_pin, y=1, on=False)
    switch(pin=pin, y=2, on=False)

    return ret
