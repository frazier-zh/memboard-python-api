import ok

__device = None

def initialize():
    __device = ok.okCFrontPanel()

def set_wire(addr, value):
    __device.SetWireInValue(addr, value)
    __device.UpdateWireIns()

def get_wire(addr):
    __device.UpdateWireOuts()
    return __device.dev.GetWireOutValue(addr)

def load(file_path):
    __device.configureFPGA(file_path)

def control():
    pass
