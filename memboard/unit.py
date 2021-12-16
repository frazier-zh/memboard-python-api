"""Unit conversion definition
"""
import sys
import numpy as np

# Base units
#   Name        Shortcut    Value   Type
base_units = [
    ['Voltage', 'V',        1,      float],
    ['Ampere',  'A',        1,      float],
    ['Second',  's',        1e9,    int]
]

# Prefix
#   Name        Shortcut    Power(10)
unit_prefixs = [
    ['Kilo',    'K',        3],
    ['Mega',    'M',        6],
    ['Giga ',   'G',        9],

    ['Milli',   'm',        -3],
    ['Micro',   'u',        -6],
    ['Nano',    'n',        -9],
]

# Register all base unit
for unit in base_units:
    utype = unit[3]
    setattr(sys.modules[__name__], unit[1], utype(unit[2]))

    for prefix in unit_prefixs:
        setattr(sys.modules[__name__], f'{prefix[1]}{unit[1]}',\
            utype(10**prefix[2]*unit[2]))

# Compound units
min = 60 * s
hour = 60 * min
day = 24 * hour
ohm = V/A

def to_pretty(time):
    """Convert time to display-friendly format
    HH:MM:SS.
    """
    if time > s:
        data_str = '{:02d}:{:02d}:{:02d}'.format(
            int(time/hour), int(time%hour/min), int(time%min/s)
        )
        small_str = '.{:d}'.format(int(time%s/ms))
        return data_str+small_str
    elif time > ms:
        return '{:d}.{:d} ms'.format(int(time/ms), int(time%ms/us))
    elif time > us:
        return '{:d}.{:d} us'.format(int(time/us), int(time%us/ns))
    else:
        return '{:d} ns'.format(int(time/ns))
    

# Bit stream conversion
def to_byte(value, nbyte=4):
    if isinstance(value, int):
        ord_barray = value.to_bytes(nbyte, 'big')
    elif isinstance(value, np.ndarray):
        ord_barray = value.byteswap().tobytes()

    ok_barray = bytearray(len(ord_barray))
    ok_barray[::2] = ord_barray[1::2]
    ok_barray[1::2] = ord_barray[::2]
    return ok_barray

def from_byte(ok_barray):
    return np.frombuffer(ok_barray, dtype=np.uint16)

# Time conversion
def to_tick(time):
    return int(time/10/ns)

def to_time(tick):
    return tick*10*ns

# Voltage integer conversion
def to_voltage(value):
    return value/0xFFF*24-12

def to_int(voltage):
    return int((voltage+12)/24*0xFFF)


# Operataion execution time
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

def get_runtime(ops):
    op_byte = ops%0x100
    if op_byte in [0x03, 0x13]:
        return (_op_runtime[op_byte]*(ops>>8)+_op_runtime[0]) *ns
    else:
        return (_op_runtime[op_byte]+_op_runtime[0]) *ns