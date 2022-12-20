socket_mapping = dict({
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
    })

def pin(socket: str):
    col = socket.upper()[0]
    row = int(socket[1:])-1
    if (col in socket_mapping) and (row in range(1, 11+1)):
            return socket_mapping[col][row]
    else:
        return 0

def socket(pin: int):
    if pin not in range(1, 84+1):
        raise ValueError('Invalid pin number (1-84).')

    for key, value in socket_mapping.items():
        if pin in value:
            return f'{key}{value}'

#   switch  GND     DAC     ADC
switch_mapping = {
    0: [0,      2,      0],
    1: [-1,     1,      -1],
    2: [-1,     3,      1]
}