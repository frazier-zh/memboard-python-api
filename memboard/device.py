import ok
import os.path
import logging
import time

from tabulate import tabulate

__error_codes = {
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
    -102: 'TimeOutError',
}

def Try(code: int):
    if code >= 0:
        return code
    elif code in __error_codes:
        raise RuntimeError('FrontPanelAPI: %s'%__error_codes[code])
    else:
        raise RuntimeError('FrontPanelAPI: UnknownError')

class FrontPanel():
    def __init__(self):
        self.fp = ok.okCFrontPanel()
        self.pll = ok.PLL22393()

    def __del__(self):
        self.fp.Close()

    def Open(self, no: int = 0):
        serial = self.fp.GetDeviceListSerial(no)
        Try(self.fp.OpenBySerial(serial))
        Try(self.fp.GetPLL22393Configuration(self.pll))

    def Load(self, path: str):
        if os.path.isfile(path):
            Try(self.fp.ConfigureFPGA(path))
        else:
            Try(-101)

    def Close(self):
        self.fp.Close()

    def WriteToPipeIn(self, addr: int, data: bytearray):
        Try(self.fp.WriteToPipeIn(addr, data))

    def ReadFromPipeOut(self, addr: int, data: bytearray):
        Try(self.fp.ReadFromPipeOut(addr, data))

    def ActivateTriggerIn(self, addr: int, bit: int):
        Try(self.fp.ActivateTriggerIn(addr, bit))

    def Update(self):
        Try(self.fp.UpdateWireIns())
        Try(self.fp.UpdateWireOuts())
        Try(self.fp.UpdateTriggerOuts())

    def IsTriggered(self, addr: int, bit: int):
        return self.fp.IsTriggered(addr, bit)

    def SetWireInValue(self, addr: int, value: int):
        Try(self.fp.SetWireInValue(addr, value))

    def GetWireOutValue(self, addr: int):
        return Try(self.fp.GetWireOutValue(addr))

    def WaitOnTrigger(self, addr: int, bit: int, time_out=1):
        t_start = time.time()
        while True:
            if time.time()-t_start > time_out:
                Try(-102)
                return False

            Try(self.fp.UpdateTriggerOuts())
            if Try(self.fp.IsTriggered(addr, bit)):
                return True

    def SetPLLConfiguration(self):
        Try(self.fp.SetPLL22393Configuration(self.pll))

    def SetPLLParameters(self, n, p, q, enable=True):
        Try(self.pll.SetPLLParameters(n, p, q, enable))

    def SetOutputParameters(self, n, d, src=0, enable=True):
        Try(self.pll.SetOutputDivider(n, d))
        Try(self.pll.SetOutputSource(n, src*2+2))
        self.pll.SetOutputEnable(n, enable)

    # Utility methods
    def ShowDeviceList(self):
        device_count = self.fp.GetDeviceCount()

        device_info = []
        info_header = ['No.', 'Model', 'SerialNo.']
        for i in range(device_count):
            device_info.append([i,
                self.fp.GetBoardModelString(self.fp.GetDeviceListModel(i)),
                self.fp.GetDeviceListSerial(i)])
        print('Device Info:')
        print(tabulate(device_info, headers=info_header, tablefmt='orgtbl'))

    def ShowPLLConfiguration(self):
        n_pll = 3 # total 3 pll clocks
        n_output = 5 # Total 5 outputs

        pll_info = []
        pll_info_header = ['No.', 'Freq', 'P/Q', 'Enable']
        f_crystal = self.pll.GetReference()
        for i in range(n_pll):
            pll_info.append([i,
                self.pll.GetPLLFrequency(i),
                f'{self.pll.GetPLLP(i)}/{self.pll.GetPLLQ(i)}',
                self.pll.IsPLLEnabled(i)])

        print(f'Reference Crystal Frequency: {f_crystal} MHz')
        print('PLL Info:')
        print(tabulate(pll_info, headers=pll_info_header, tablefmt='orgtbl'))

        output_info = []
        output_info_header = ['No.', 'Freq', 'D', 'Source', 'Enable']
        for i in range(n_output):
            output_info.append([i,
                self.pll.GetOutputFrequency(i),
                self.pll.GetOutputDivider(i),
                self.pll.GetOutputSource(i)/2-1,
                self.pll.IsOutputEnabled(i)])
        print('Output Info:')
        print(tabulate(output_info, headers=output_info_header, tablefmt='orgtbl'))

    def ConvertTime(self, raw):
        freq = self.pll.GetOutputFrequency(1) # frequency of default clk1
        return float(raw)/(freq*1e6)
