def v(s):
    print(f"Device>> {s}")

def initialize(file_path):
    v("ok.okCFrontPanel()")
    v("OpenBySerial()")
    v(f"configureFPGA({file_path})")

def set_wire(addr, value):
    v(f"SetWireInValue({addr}, {value})")
    v(f"UpdateWireIns()")

def get_wire(addr):
    v("UpdateWireOuts()")
    v(f"GetWireOutValue({addr})")
    return 0

def close():
    v("Close()")

def verify():
    set_wire(0x00, 0)
    res = get_wire(0x20)
    if res == 0:
        return True
    else:
        return False