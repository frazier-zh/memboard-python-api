"""Unit conversion definition
"""
import sys

# Base units
#   Name        Shortcut    Value   Type
base_units = [
    ['Voltage', 'V',        1,      float],
    ['Ampere',  'A',        1,      float],
    ['Second',  's',        1e9,    int],
    ['Ohm',     'Ohm',      1,      float]
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

def to_pretty(time):
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
    