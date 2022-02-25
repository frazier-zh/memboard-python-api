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

def bit(value: int, l, r):
    return (value%(1<<l+1))>>r

def to_int(voltage):
    return int((voltage+5)/10*0xFFF)

def to_current(value):
    sign = value & 0x2000 # negative
    if sign:
        value = 0x3FFF-value+1

    voltage = (value/0x2000) * 5
    return (-1 if sign else 1) * voltage / 200e3