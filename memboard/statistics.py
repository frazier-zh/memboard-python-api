from . import unit as u
import numpy as np

_op_runtime = {
    0x00:       30, # Do nothing
    0x11:       20, # ADC reset
    0x21:       1390, # ADC enable
    0x12:       50, # DAC reset
    0x22:       60, # DAC enable
    0x03:       10, # Wait, 10ns
    0x13:       0x1000000, # Wait, 0x1000000 * 10ns
    0x14:       110, # Switch1 reset
    0x24:       110, # Switch1 enable
    0x15:       110, # Switch2 reset
    0x25:       110, # Switch2 enable
    0x16:       110, # Switch3 reset
    0x26:       110, # Switch3 enable
    0x07:       30, # Get FPGA time
}
"""Operation runtime (ns)
    code[7:0]   time
"""

def get_runtime(ops):
    op_byte = ops%0x100
    if op_byte in [0x03, 0x13]:
        return (_op_runtime[op_byte]*(ops>>8)+_op_runtime[0]) *u.ns
    else:
        return (_op_runtime[op_byte]+_op_runtime[0]) *u.ns


"""Power domain"""
_power_config = {
    ''
}

def to_voltage(value):
    return value/0xFFF*24-12

def to_int(voltage):
    return int((voltage+12)/24*0xFFF)