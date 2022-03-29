""" Device List Class
    Enumerate every device
"""
from enum import IntEnum

DESYNC_TIME = 100

PACKET_SIZE = 12

class TerminalType(IntEnum):
    Sense = 0
    Force = 1

class State(IntEnum):
    idle = 0
    reset = 1
    start = 2
    wait = 3
    clear = 4
    busy = 5
    read = 8

class OP(IntEnum):
    logic = 0
    jmp = 1
    call = 2
    ret = 3
    loop = 5
    adc = 8
    dac = 9
    switch = 10
    clr = 11

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


def to_pin(loc: str):
    col = loc.upper()[0]
    row = int(loc[1:])-1
    if (col in socket_mapping) and (row in range(1, 11+1)):
        pin = socket_mapping[col][row]
        if pin == -1:
            __logger.error(f"Socket-{loc} is unavailable.")
    else:
        __logger.error(f"Invalid socket location {loc}.")
    return pin

def to_socket(pin: int):
    for key, value in socket_mapping.items():
        if pin in value:
            return f'{key}{value}'

#   switch  GND     DAC     ADC
switch_connection = {
    0:     [0,      2,      0],
    1:     [0,      2,      0],
    2:     [-1,     1,     -1],
    3:     [-1,     1,     -1],
    4:     [-1,     3,      1],
    5:     [-1,     3,      1]
}

def get_channel(b: Base, sw_no):
    if b == Base.adc:
        return switch_connection[sw_no][2], 2
    elif b == Base.dac:
        return switch_connection[sw_no][1], 1

def to_switch(pin):
    if pin not in range(1, 84+1):
        __logger.error(f'Invalid pin number {pin}.')

    group = int((pin-1)/28)*2 + int((pin-1)%28/16)
    pin_no = (pin-1)%28%16
    return group, pin_no
    
class Port:
    def __init__(self, pin=None, socket=None, sw_no=None, sw_x=None):
        if pin is not None:
            self.sw_no, self.sw_x = to_switch(pin)
        elif socket is not None:
            self.sw_no, self.sw_x = to_switch(to_pin(socket))
        elif (sw_no is not None) and (sw_x is not None):
            self.sw_no, self.sw_x = sw_no, sw_x
        else:
            __logger.error(f'Invalid port information.')

        self.sw_no = -1
        self.sw_x = -1

    def pin(self):
        return (self.sw_no//3)*28 + (self.sw_no%2)*16 + self.sw_x

    def socket(self):
        return to_socket(self.pin())

    def switch(self):
        return self.sw_no, self.sw_x

    def __repr__(self) -> str:
        return f'Pin-{self.pin()}'
