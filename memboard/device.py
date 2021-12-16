import ok
import os.path
import logging
import time

__device = ok.okCFrontPanel()
__module_logger = logging.getLogger(__name__)
__debug = False

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

def debug(enable):
    global __debug
    __debug = enable

def try_to(code, throw=True):
    if code>=0:
        return code
    elif not code in error_codes:
        code = -100

    global __debug
    if __debug:
        try:
            if (try_to.last == code):
                try_to.count += 1
            else:
                if try_to.count>0:
                    __module_logger.error(f'{error_codes[try_to.last]} <folded {try_to.count} repeating errors>.')
                __module_logger.error(error_codes[code])
                try_to.last = code
                try_to.count = 0
        except AttributeError:
            __module_logger.error(error_codes[code])
            try_to.last = code
            try_to.count = 0
    else:
        if throw:
            raise RuntimeError(error_codes[code])

def open():
    try_to(__device.GetDeviceCount())
    try_to(__device.OpenBySerial(''))

def load(path):
    if os.path.isfile(path):
        try_to(__device.ConfigureFPGA(path))
    else:
        try_to(-101)

def close():
    __device.Close()

from . import unit as u

def pipe_in(addr, data):
    try_to(__device.WriteToPipeIn(addr, data))

def pipe_out(addr, data):
    try_to(__device.ReadFromPipeOut(addr, data))

def trigger_in(addr, index):
    try_to(__device.ActivateTriggerIn(addr, index))

def wait_trigger_out(addr, index, time_out=1):
    triggered = False
    start_time = time.time()

    while not triggered:
        if (time.time()-start_time > time_out):
            try_to(-102, throw=False)
            return False
        try_to(__device.UpdateTriggerOuts())
        triggered = try_to(__device.IsTriggered(addr, index))

    return True

def wire_in(addr, value):
    try_to(__device.SetWireInValue(addr, value))
    try_to(__device.UpdateWireIns())

def wire_out(addr):
    try_to(__device.UpdateWireOuts(addr))
    return try_to(__device.GetWireOutValue(addr))
