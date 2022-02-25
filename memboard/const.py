""" Device List Class
    Enumerate every device
"""
state = {
    'idle' : 0,
    'reset' : 1,
    'start' : 2,
    'wait' : 3,
    'clear' : 4,
    'busy' : 5,
    'read' : 6,
    'read2' : 7
}

dev = {
    'logic' : 0,
    'adc' : 1,
    'dac' : 2,
    'timer' : 3,
    'sw_source' : 4,
    'sw_gate' : 5,
    'sw_drain' : 6,
    'clock' : 7
}

data = {
    'adc' : 1,
    'clock' : 3
}

op = {
    'low' : 0b0000,
    'high' : 0b1000,
    'reset' : 0b1,
    'enable' : 0b10
}
    
# Operataion execution time
operation_runtime = {
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

def runtime(ops):
    op_byte = ops%0x100
    if op_byte in [0x03, 0x13]:
        return (operation_runtime[op_byte]*(ops>>8)+operation_runtime[0]) *ns
    else:
        return (operation_runtime[op_byte]+operation_runtime[0]) *ns


socket_mapping = {
    'A': [32, 30, 29, 27, 24, 23, 20, 17, 15, 14, 11],
    'B': [35, 33, 31, 28, 25, 18, 19, 16, 13, 12,  9],
    'C': [36, 34, -1, -1, 26, 22, 21, -1, -1, 10,  8],
    'D': [38, 37, -1, -1, -1, -1, -1, -1, -1,  7,  6],
    'E': [41, 40, 42, -1, -1, -1, -1, -1,  2,  4,  3],
    'F': [44, 39, 43, -1, -1, -1, -1, -1,  1, 84,  5],
    'G': [45, 46, 47, -1, -1, -1, -1, -1, 81, 82, 83],
    'H': [48, 49, -1, -1, -1, -1, -1, -1, -1, 79, 80],
    'J': [50, 52, -1, -1, 60, 64, 65, -1, -1, 76, 78],
    'K': [51, 54, 55, 58, 61, 63, 67, 70, 73, 75, 77],
    'L': [53, 56, 57, 59, 62, 68, 66, 69, 71, 72, 74]
}

def socket(loc: str):
    col = loc.upper()[0]
    row = int(loc[1:])-1
    if (col in socket_mapping) and (row in range(1, 11+1)):
            return socket_mapping[col][row]
    else:
        return 0

def pin(pin: int):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-84).')

    for key, value in socket_mapping.items():
        if pin in value:
            return f'{key}{value}'