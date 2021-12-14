import ok
import os.path
import logging
import time
import numpy as np

__device = ok.okCFrontPanel()
__module_logger = logging.getLogger(__name__)
__debug = False

def debug(enable):
    global __debug
    __debug = enable

def error(msg, throw=True):
    global __debug

    if __debug:
        try:
            if (error.last == msg):
                error.count += 1
            else:
                if error.count>0:
                    __module_logger.error(f'{error.last} <folded {error.count} repeating errors>.')
                __module_logger.error(msg)
                error.last = msg
                error.count = 0
        except AttributeError:
            __module_logger.error(msg)
            error.last = msg
            error.count = 0
            
    else:
        if throw:
            raise RuntimeError(msg)

def open():
    if __device.GetDeviceCount() == 0:
        error('FPGA device not found.')
    if __device.OpenBySerial(''):
        error('FPGA connection failed.')

def load(path):
    if os.path.isfile(path):
        if __device.ConfigureFPGA(path):
            error('FPGA configuration failed.')
    else:
        error('Invalid configuration file path.')

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
        error('WriteToPipeIn() failed.')

def pipe_out(addr, data):
    if __device.ReadFromPipeOut(addr, data):
        error('ReadFromPipeOut() failed.')

def trigger_in(addr, index):
    if __device.ActivateTriggerIn(addr, index):
        error('ActivateTriggerIn() failed.')

def wait_trigger_out(addr, index, time_out=1):
    triggered = False
    start_time = time.time()

    while not triggered:
        if (time.time()-start_time > time_out):
            error('Time out on waiting TriggerOut.', throw=False)
            return False
        if __device.UpdateTriggerOuts():
            error('UpdateTriggerOuts() failed.')
        triggered = __device.IsTriggered(addr, index)

    return True

def wire_in(addr, value):
    __device.SetWireInValue(addr, value)
    if __device.UpdateWireIns():
        error('UpdateWireIns() failed.')

def wire_out(addr):
    if __device.UpdateWireOuts(addr):
        error('UpdateWireOuts() failed.')
    return __device.GetWireOutValue(addr)
