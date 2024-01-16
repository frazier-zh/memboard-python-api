import ok
import os.path
import logging
import time

__device = ok.okCFrontPanel()
__logger = logging.getLogger(__name__)

error_codes = {
    0: 'NoError',
    -1: 'Failed',
    -2: 'TimeOut',
    -3: 'DoneNotHigh',
    -4: 'TrasnferError',
    -5: 'CommunicationError',
    -6: 'InvalidBitStream',
    -7: 'FileError',
    -8: 'DeviceNotOpen',
    -9: 'InvalidEndpoint',
    -10: 'InvalidBlockSize',
    -11: 'I2CRestrictedAddress',
    -12: 'I2CBitError',
    -13: 'I2CNack',
    -14: 'I2CUnknownStatus',
    -15: 'UnsupportedFeature',
    -16: 'FIFOUnderflow',
    -17: 'FIFOOverflow',
    -18: 'DataAlignmentError',
    -19: 'InvalidResetProfile',
    -20: 'InvalidParameter',
    -21: 'OperationInProgress',

    -100: 'UnknownError',
    -101: 'InvalidFilePath',
    -102: 'TimeOutError'
}

def _try(code):
    if not code in error_codes:
        code = -100

    __logger.error(error_codes[code])

def open():
    _try(__device.GetDeviceCount())
    _try(__device.OpenBySerial(''))

def load(path):
    if os.path.isfile(path):
        _try(__device.ConfigureFPGA(path))
    else:
        _try(-101)

def close():
    __device.Close()

from . import unit as u

def pipe_in(addr, data):
    _try(__device.WriteToPipeIn(addr, data))

def pipe_out(addr, data):
    _try(__device.ReadFromPipeOut(addr, data))

def trigger_in(addr, index):
    _try(__device.ActivateTriggerIn(addr, index))

def wait_trigger_out(addr, index, time_out=1):
    triggered = False
    start_time = time.time()

    while not triggered:
        if (time.time()-start_time > time_out):
            __logger.error(error_codes[-102])
            return False
        _try(__device.UpdateTriggerOuts())
        triggered = _try(__device.IsTriggered(addr, index))

    return True

def wire_in(addr, value):
    _try(__device.SetWireInValue(addr, value))
    _try(__device.UpdateWireIns())

def update_wire_out():
    _try(__device.UpdateWireOuts())

def read_wire_out(addr):
    return _try(__device.GetWireOutValue(addr))

def wire_out(addr):
    _try(__device.UpdateWireOuts())
    return _try(__device.GetWireOutValue(addr))
