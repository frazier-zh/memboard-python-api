import ok
import os.path
import logging
import time
import numpy as np

__device = ok.okCFrontPanel()
__module_logger = logging.getLogger(__name__)

def open():
    if __device.GetDeviceCount() == 0:
        raise RuntimeError('FPGA device not found.')
    if __device.OpenBySerial(''):
        raise RuntimeError('FPGA connection failed.')

def load(path):
    if os.path.isfile(path):
        if __device.ConfigureFPGA(path):
            raise RuntimeError('FPGA configuration failed.')
    else:
        raise RuntimeError('Invalid configuration file path.')

def close():
    __device.Close()

def to_byte_single(value, nbyte):
    slice_uint16 = np.frombuffer(value.to_bytes(nbyte, 'big'), dtype=np.uint16)
    slice_uint8 = np.array(slice_uint16, dtype='>u2').view('uint8')
    return bytearray(slice_uint8)

def to_byte(array):
    slice_uint16 = np.array(array, dtype='>u4').view('uint16')
    slice_uint8 = np.array(slice_uint16, dtype='>u2').view('uint8')
    return bytearray(slice_uint8)

def from_byte(byte_array):
    return np.array(byte_array, dtype=np.uint8).view('<u2')

from . import unit as u
def to_tick(time):
    return int(time/10/u.ns)

def to_time(tick):
    return tick*10*u.ns

def pipe_in(addr, data):
    if __device.WriteToPipeIn(addr, data):
        RuntimeError('WriteToPipeIn() failed.')

def pipe_out(addr, data):
    if __device.ReadFromPipeOut(addr, data):
        RuntimeError('ReadFromPipeOut() failed.')

def trigger_in(addr, index):
    if __device.ActivateTriggerIn(addr, index):
        RuntimeError('ActivateTriggerIn() failed.')

def wait_trigger_out(addr, index, time_out=1):
    triggered = False
    start_time = time.time()

    while not triggered:
        if (time.time()-start_time > time_out):
            __module_logger.warn('Time out on waiting TriggerOut.')
            return False
        if __device.UpdateTriggerOuts():
            RuntimeError('UpdateTriggerOuts() failed.')
        triggered = __device.IsTriggered(addr, index)

    return True

def wire_in(addr, value):
    __device.SetWireInValue(addr, value)
    if __device.UpdateWireIns():
        RuntimeError('UpdateWireIns() failed.')

def wire_out(addr):
    if __device.UpdateWireOuts(addr):
        RuntimeError('UpdateWireOuts() failed.')
    return __device.GetWireOutValue(addr)
