from .Base import InstructionList, OPCODE, DEVICE

def reset():
    return InstructionList(
        [OPCODE.MUX, 0, DEVICE.ADC_ALL, 0, ],
        Ins(DEVICE.DAC_ALL flag_reset=True),
        Ins(DEVICE.SW_ALL, flag_reset=True))

def clear():
    return [
        InstrDAC(DEVICE_ALL, flag_clear=True),
        InstrSW (DEVICE_ALL, flag_clear=True)
    ]

def apply(pin: int, data=None):
    return [
        InstrSW (device_no=sw_no, ax=sw_ax, ay=1, data=True),
        InstrDAC(device_no=dac_no, addr=dac_addr, data=data)
    ]

def (pin: int):
    return [
        InstrSW (device_no=sw_no, ax=sw_ax, ay=0, data=False),
        InstrSW (device_no=sw_no, ax=sw_ax, ay=1, data=False),
        InstrSW (device_no=sw_no, ax=sw_ax, ay=2, data=False),
    ]

def ToggleAutoTrigger(self, pin: int):
    return [
        InstrSW (device_no=sw_no, ax=sw_ax, ay=2, data=True),
        InstrADC(device_no=adc_no, flag_trig_mode=True)
    ]

def waveform():
    pass

def measure():
    pass