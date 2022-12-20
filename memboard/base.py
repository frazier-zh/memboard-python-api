from dataclasses import dataclass
from enum import IntEnum

# Constants
N_ADC   = 1
N_DAC   = 1
N_SW    = 6

class ADDR(IntEnum):
    PIPE_IN = 0x80
    PIPE_OUT = 0xA0
    FIFO_IN_WR_DATA_COUNT = 0x20
    FIFO_OUT_RD_DATA_COUNT = 0x21
    DIRECT_DATA = 0x22
    STATUS = 0x23
    TRIGGER_IN = 0x40
    TRIGGER_OUT = 0x60

class TRIG(IntEnum):
    MASTER_RST      = 0
    FIFO_IN_RST     = 1
    FIFO_OUT_RST    = 2
    IF_MAIN_RST     = 3
    CLOCK_RST       = 4
    REG_RST         = 5
    MUX_RST         = 6

class SIGNAL(IntEnum):
    DIRECT_DATA_READY = 0

class STATUS(IntEnum):
    IF_MAIN_IDLE = 1<<0
    FIFO_IN_FILL = 1<<1

class REG(IntEnum):
    ADC_CLK_DIV     = 0
    ADC_READ_MODE   = 1
    ADC_TRIG_MODE   = 2
    ADC_ADDR        = 3
    ADC_IDLE        = 4
    DAC_IDLE        = 5
    SW_IDLE         = 6

class DEVICE:
    ADC_ALL = (1<<7)+(0<<4)
    ADC     = [((0<<4)+x) for x in range(N_ADC)]

    DAC_ALL = (1<<7)+(1<<4)
    DAC     = [((1<<4)+x) for x in range(N_DAC)]

    SW_ALL  = (1<<7)+(2<<4)
    SW      = [((2<<4)+x) for x in range(N_SW)]

class OPCODE(IntEnum):
    NULL     = 0
    SETSR    = 1
    LDSR     = 2
    MUX      = 3
    MUXE     = 4
    WAIT     = 5

class OPT(IntEnum):
    RESET   = 1<<3
    CLEAR   = 1<<2

@dataclass
class Instruction:
    opcode  : OPCODE = OPCODE.NULL
    ireg    : bool = 0
    data    : int = 0

    def to_bytes(self) -> bytearray:
        return bytearray([(self.opcode<<5)+(self.ireg<<4)+(self.data>>8)%(1<<4),\
            self.data%(1<<8)])

    def __repr__(self) -> str:
        return '{} IREG{:d} {:x}'.format(self.opcode.name, self.ireg, self.data)

class InstructionList(Instruction):
    def __init__(self, *args) -> None:
        self.list = []
        for item in args:
            if isinstance(item, Instruction):
                self.list.append(item)
            else:
                self.list.append(Instruction(item))

    def append(self, item):
        if isinstance(item, Instruction):
            self.list.append(item)
        elif isinstance(item, InstructionList):
            self.list += item.list

    def to_bytes(self) -> bytearray:
        bytes = bytearray()
        for instr in self.list:
            bytes += instr.to_bytes()
        return bytes

    def to_txt(self, file):
        with open(file, 'w') as fout:
            for item in self.list:
                fout.write(' '.join('{:02x}'.format(x) for x in item.to_bytes()))
