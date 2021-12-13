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
@allow_emulate(output_bytes=2)
def adc(op, channel=0):
    """ADC control
    """
    if op == 'reset':   
        op_bytes = 1
    elif op == 'enable':
        op_bytes = 2
    else:
        raise ValueError("Invalid ADC operation")

    if channel not in [0, 1]:
        raise ValueError("Invalid ADC channel")

    return to_code(
        [[4, 1], [4, op_bytes], [8, channel]]
    )

def to_switch_no(pin):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-86).')

    group = int((pin-1)/28)
    pin_in_group = (pin-1)%28
    x = pin_in_group if pin_in_group>15 else pin_in_group-16
    channel = group*2 + (1 if pin_in_group>15 else 0)

    return group, channel, x

@allow_emulate()
def sw(op, pin=0, y=0, on=False):
    """Switch control
    """
    if op == 'reset':   
        op_bytes = 1
    elif op == 'enable':
        op_bytes = 2
    else:
        raise ValueError("Invalid Switch operation")

    _, channel, x = to_switch_no(pin)

    if y not in range(3):
        raise ValueError("Invalid Y address")

    if not isinstance(on, bool):
        raise ValueError("Invalid on/off value")

    return to_code(
        [[4, 3], [4, op_bytes], [8, channel], [4, x], [4, y], [1, on]]
    )

@allow_emulate()
def dac(op, channel=0, value=0x800):
    """DAC control
    """
    if op == 'reset':   
        op_bytes = 1
    elif op == 'enable':
        op_bytes = 2
    else:
        raise ValueError("Invalid DAC operation")

    if channel not in range(4):
        raise ValueError("Invalid DAC channel")
    if  op=='enable' and channel==0 and not value==0x800:
        __module_logger.warn("DAC channel 0 should always be set to 0x800")

    if value not in range(0x1000):
        raise ValueError("Invalid DAC value, max 0xFFF")

    return to_code(
        [[4, 2], [4, op_bytes], [8, channel], [16, value]]
    )

@allow_emulate()
def wait(time):
    """Ask FPGA to wait for a precise time period
    """
    time = int(time/10)
    if time<0 or (time>>48):
        raise ValueError("Invalid waiting time, max= 30 days.")
    elif time>>24:
        return to_code(
            [[4, 4], [4, 1], [24, time>>24]],
            [[4, 4], [4, 0], [24, time % 0x1000000]]
        )
    else:
        return to_code(
            [[4, 4], [4, 0], [24, time]]
        )

@allow_emulate(output_bytes=6)
def time():
    """Get precise time from FPGA
    """
    return to_code(
        [[4, 6]]
    )

"""Registery of operation status"""
power_config = ''


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
def reset():
    sw(op='reset')
    adc(op='reset')
    dac(op='reset')

#   SW  GND     DAC     ADC
switch_connection = {
    0: [0,      1,      0],
    1: [-1,     2,      -1],
    2: [-1,     3,      1]
}

from .statistics import to_int, to_voltage
def ground(pin):
    group, _, _ = to_switch_no(pin)
    if [group][0]==-1:
        raise ValueError(f"Pin {pin} cannot connect to ground, use DAC instead.")
    else:
        sw(op='enable', pin=pin, y=0, on=True)

def apply(pin, v=None):
    """Apply voltage on given terminal
    1. determine DAC channel and SW number
    3. enable SW for connection setup
    2. enable DAC for voltage setup

    Args:
        pin (int): pin number
        voltage (float): voltage value
    """
    group, _, _ = to_switch_no(pin)
    channel = switch_connection[group][1]

    sw(op='enable', pin=pin, y=1, on=True)
    
    # Just connect to DAC if voltage is not given
    if v is not None:
        dac(op='enable', channel=channel, value=to_int(power_config, v))
    else:
        __module_logger.warn(f'Pin {pin} is connected to DAC-{channel} by default.')

def measure(pin, drive_pin=None, v=None):
    group, _, _ = to_switch_no(pin)
    channel = switch_connection[group][2]

    # Turn on DAC/ADC connections
    sw(op='enable', pin=pin, y=2, on=True)
    if drive_pin is not None:
        apply(drive_pin, v)

    ret = adc(op='enable', channel=channel)

    # Turn off DAC/ADC connections
    if drive_pin is not None:
        sw(op='enable', pin=drive_pin, y=1, on=False)
    sw(op='enable', pin=pin, y=2, on=False)

    return ret
