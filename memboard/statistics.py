from . import unit as u
import numpy as np

_op_runtime = {
    0x00:       0, # Do nothing
    0x11:       0, # ADC reset
    0x21:       1260, # ADC enable
    0x12:       15, # DAC reset
    0x22:       80, # DAC enable
    0x13:       150, # Switch reset
    0x23:       190, # Switch enable
    0x04:       10, # Wait, 10ns
    0x14:       0x1000000, # Wait, 0x1000000 * 10ns
    0x06:       0, # Get FPGA time
}
"""Operation runtime (ns)
    code[7:0]   time
"""

def get_runtime(ops):
    op_byte = ops%0x100
    if op_byte in [0x04, 0x14]:
        return _op_runtime[op_byte] * ops>>8 * 10 *u.ns
    else:
        return _op_runtime[op_byte] *u.ns


"""Power domain"""
_power_config = {
    ''
}

def to_voltage(value):
    return value/0xFFF*24-12

def to_int(voltage):
    return int((voltage+12/24)*0xFFF)