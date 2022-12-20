import inspect
import warnings

from .Base import *
from .FrontPanel import FrontPanel

# Board control
class Board:
    def __init__(self):
        self.device = FrontPanel()
        
        self.register = {}

    def open(self):
        self.device.Open()
        self.device.Load('./verilog/src/top.bit')

    def is_idle(self):
        self.device.UpdateWireOuts()
        self.status = self.device.GetWireOutValue(ADDR.STATUS)
        if (self.status & STATUS.IF_MAIN_IDLE):
            return True
        else:
            return False

    def close(self):
        self.device.Close()

    def reset(self, trig: TRIG=TRIG.MASTER_RST):
        self.device.ActivateTriggerIn(ADDR.TRIGGER_IN, trig)

    def get_direct_data(self):
        self.device.UpdateTriggerOuts()
        if self.device.IsTriggered(ADDR.TRIGGER_OUT, SIGNAL.DIRECT_DATA_READY):
            warnings.warn('Board::{}(), direct data is not ready. Data may be incorrect.'\
                .format(inspect.currentframe().f_code.co_name))

        self.device.UpdateWireOuts()
        return self.device.GetWireOutValue(ADDR.DIRECT_DATA)

    def load(self, item: Instruction):
        self.device.WriteToPipeIn(item.to_bytes())

    # Instruction related
    def get_register(self, addr:REG=None):
        if self.is_idle():
            self.load(Instruction(OPCODE.RDREG, 0, addr))
            if (self.device.WaitOnTrigger(ADDR.TRIGGER_OUT, SIGNAL.DIRECT_DATA_READY, time_out=0.01)):
                self.register[addr] = self.get_direct_data()
        else:
            warnings.warn('Board::{}(), board is busy. Register value update skipped.'\
                .format(inspect.currentframe().f_code.co_name))
        return self.register[addr]

    def get_all_register(self):
        for reg_addr in REG:
            self.get_register(reg_addr)

    def set_register(self, addr, value):
        if self.is_idle():
            # Load value
            if (value>>12):
                self.load(Instruction(OPCODE.SETSR, 1, value>>12))
            self.load(Instruction(OPCODE.LDSR, 1, value%(1<<12)))
            self.load(Instruction(OPCODE.LDREG, 1, addr))
            
            # Comfirm on the update
            self.load(Instruction(OPCODE.RDREG, 0, addr))
            if self.device.WaitOnTrigger(ADDR.TRIGGER_OUT, SIGNAL.DIRECT_DATA_READY, time_out=0.01):
                self.register[addr] = self.get_direct_data()
            if value != self.register[addr]:
                warnings.warn('Board::{}(), register data is inconsistent. Expected {}, the register value is {}.'\
                    .format(inspect.currentframe().f_code.co_name), value, self.register[addr])
        else:
            warnings.warn('Board::{}(), board is busy. Register value update skipped.'\
                .format(inspect.currentframe().f_code.co_name))
