from . import ok
import time
import os
import numpy as np
import logging

logger = logging.getLogger(__name__)

bitfile_path = "bitfile/"

def BIT_SHIFT_FROM_MASK(mask):
    # calculate shift from mask
    shift = 0
    while mask & 0b1 == 0:
        mask = mask >> 1
        shift += 1
    return shift

def BIT(a, mask):
    shift = BIT_SHIFT_FROM_MASK(mask)
    return (a << shift) & mask

def BIT_EQUAL(a, b, mask):
    shift = BIT_SHIFT_FROM_MASK(mask)
    return (a & mask) >> shift == b
    
def BIT_GET(a, mask):
    shift = BIT_SHIFT_FROM_MASK(mask)
    return (a & mask) >> shift

class mb1(ok.okCFrontPanel):
    def __init__(self):
        super().__init__()
        self._register_methods()

        self.init()

    def _register_methods(self):
        for field in dir(ok.okCFrontPanel):
            if (not field.startswith('_')) and callable(getattr(ok.okCFrontPanel, field)):
                setattr(self, field, self._error_wrap_method(field))

    def _error_wrap_method(self, method):
        def wrapper(*args, **kwargs):
            ret = getattr(super(mb1, self), method)(*args, **kwargs)
            if isinstance(ret, int):
                if ret < 0:
                    logger.error(f'<ok::{method}> Error: {self.GetErrorString(ret)}')
                else:
                    logger.info(f'<ok::{method}> Success: {ret}')
            return ret
        return wrapper
    
    ## Board specific constants
    SLEEP_TIME = 0.01    # [s]

    REG_RST         = 0
    REG_FIFO_RST    = 1
    REG_PERI_RST    = 2
    REG_CLK_LOAD     = 3
    REG_EN          = 4
    REG_ADC_EN      = 5 
    REG_ADC_SYNC    = 6

    REG_ADC_PERIOD = 110
    REG_DAC_PERIOD = 111
    REG_ADC_COUNT  = 120
    REG_LAST_DAC   = 130
    REG_PERI_IDLE   = 131
    REG_DAC_COUNT  = 132
    
    reg_default_value = {
        REG_RST: 0,
        REG_FIFO_RST: 0,
        REG_PERI_RST: 0,
        REG_CLK_LOAD: 0,
        REG_EN: 1,
        REG_ADC_EN: 0,
        REG_ADC_SYNC: 0,

        REG_DAC_PERIOD: 99,
        REG_ADC_PERIOD: 199,
    }

    ADDR_WIREIN_CTRL = 0x00
    ADDR_WIREIN_ADC_PERIOD = 0x10
    ADDR_WIREIN_DAC_PERIOD = 0x11
    ADDR_WIREOUT_ADC_COUNT = 0x20
    ADDR_WIREOUT_LAST_DAC = 0x30
    ADDR_WIREOUT_PERI_IDLE = 0x31
    ADDR_WIREOUT_DAC_COUNT = 0x32
    ADDR_PIPEIN_DAC = 0x80
    ADDR_PIPEOUT_ADC = 0xa0

    ADDR_PIPEIN_TESTPIPE = 0x81
    ADDR_PIPEOUT_TESTPIPE = 0xa1

    ID_DAC = 0x0
    ID_SW1 = 0x1
    ID_SW2 = 0x2
    ID_SW3 = 0x3
    ID_SW4 = 0x4
    ID_SW5 = 0x5
    ID_SW6 = 0x6
    ID_ADC = 0x7
    
    CMD_IDLE = 0x0
    CMD_NORMAL = 0x1
    CMD_SLEEP = 0x2

    MASK_DAC_CHANNEL    = 0x3000
    MASK_DAC_CLEAR      = 0x4000
    MASK_DAC_DATA       = 0x0fff
    MASK_SWITCH_X       = 0x1e
    MASK_SWITCH_Y       = 0xe0
    MASK_SWITCH_ON      = 0x1
    MASK_SWITCH_CLEAR   = 0x100

    MASK_SLEEP_TIME     = 0x00ffffff
    MASK_CMD            = 0xff000000
    MASK_ID             = 0x00ff0000
    MASK_DATA           = 0x0000ffff

    LED_MESSAGE = {
        1: 'RESET_RTL',
        2: 'EN',
        3: 'ADC_EN',
        4: 'SLEEP',
        5: 'BUSY',
        6: 'PERI_BUSY',
        7: 'FIFO_OVERFLOW',
        8: 'NOT_USED',
    }

    DAC_CHANNEL_MAP = [
        2, 1, 3,
    ]
    SWITCH_MAP = [
        { 'adc': 2, 'dac': 1, 'gnd': 0},
        { 'adc':-1, 'dac': 1, 'gnd': 0},
        { 'adc': 2, 'dac': 1, 'gnd':-1},
    ]
    ADC_CHANNEL_MAP = [
        0, -1, 1,
    ]
    
    ## General functions
    def init(self):
        """ Default board register values."""
        # Get list of register from class that starts with REG_
        self.reg_keys = [getattr(mb1, key) for key in mb1.__dict__ if key.startswith('REG_')]
        self.reg = {key: 0 for key in self.reg_keys}
        for key, value in mb1.reg_default_value.items():
            self.reg[key] = value

        self.reg_switch_map = [-1] * 84

        self.is_auto_mode = False
        self.auto_mode_timeout = 0
        self.reg_dac_data = []
        self.reg_adc_data = []

        self.reg_dac_channel_data = {}
        self.reg_adc_id_index = {}
        self.reg_adc_id_data = {}

    ## Board specific functions
    def connect(self):
        self.OpenBySerial('')

        try_count = 0
        while True:
            try_count += 1
            if try_count > 10:
                logger.error('<mb1::connect> Device not configured properly. Try to connect again.')
                return False
            self.UpdateWireOuts()
            self.reg[mb1.REG_PERI_IDLE] = self.GetWireOutValue(mb1.ADDR_WIREOUT_PERI_IDLE)
            if self.reg[mb1.REG_PERI_IDLE] != 0xff:
                logger.warning(f'<mb1::connect> Attempt {try_count}: {self.reg[mb1.REG_PERI_IDLE]}')
                self.ConfigureFPGA(bitfile_path +'MB1_XEM7310.bit')
            else:
                break

        self.reset()
    
    def get_control_byte(self):
        bits = np.zeros(8, dtype=bool)
        for i in range(8):
            if i in self.reg.keys():
                bits[i] = self.reg[i]
        return int(np.packbits(bits, bitorder='little')[0])
        
    def update(self):
        self.SetWireInValue(mb1.ADDR_WIREIN_CTRL, self.get_control_byte())
        self.SetWireInValue(mb1.ADDR_WIREIN_ADC_PERIOD, self.reg[mb1.REG_ADC_PERIOD])
        self.SetWireInValue(mb1.ADDR_WIREIN_DAC_PERIOD, self.reg[mb1.REG_DAC_PERIOD])
        self.UpdateWireIns()
        time.sleep(self.SLEEP_TIME)
        self.UpdateWireOuts()
        self.reg[mb1.REG_ADC_COUNT] = self.GetWireOutValue(mb1.ADDR_WIREOUT_ADC_COUNT)
        self.reg[mb1.REG_LAST_DAC] = self.GetWireOutValue(mb1.ADDR_WIREOUT_LAST_DAC)
        self.reg[mb1.REG_PERI_IDLE] = self.GetWireOutValue(mb1.ADDR_WIREOUT_PERI_IDLE)
        self.reg[mb1.REG_DAC_COUNT] = self.GetWireOutValue(mb1.ADDR_WIREOUT_DAC_COUNT)

    def reset(self):
        self.reset_logic()
        self.reset_fifo()
        self.load_clock()
        self.reset_peripheral()

        self.dac('clear')
        self.switch('clear')

    def reset_logic(self):
        self.SetWireInValue(mb1.ADDR_WIREIN_CTRL, 0x1)
        self.UpdateWireIns()
        time.sleep(self.SLEEP_TIME)
        self.SetWireInValue(mb1.ADDR_WIREIN_CTRL, 0x0)
        self.UpdateWireIns()
        time.sleep(self.SLEEP_TIME)

    def reset_peripheral(self):
        self.reg[mb1.REG_PERI_RST] = 1
        self.update()
        self.reg[mb1.REG_PERI_RST] = 0
        self.update()

    def reset_fifo(self):
        self.reg[mb1.REG_FIFO_RST] = 1
        self.update()
        self.reg[mb1.REG_FIFO_RST] = 0
        self.update()

    def load_clock(self):
        self.reg[mb1.REG_CLK_LOAD] = 1
        self.update()
        self.reg[mb1.REG_CLK_LOAD] = 0
        self.update()
    
    def set_adc_period(self, period):
        self.reg[mb1.REG_ADC_PERIOD] = period
        self.load_clock()

    def set_dac_period(self, period):
        self.reg[mb1.REG_DAC_PERIOD] = period
        self.load_clock()

    ## Enable/disable control bits
    def enable(self):
        self.reg[mb1.REG_EN] = 1
        self.update()

    def enable_auto(self):
        self.reg[mb1.REG_EN] = 1
        self.reg[mb1.REG_CLK_LOAD] = 1
        self.reg[mb1.REG_ADC_EN] = 0
        self.reg[mb1.REG_ADC_SYNC] = 1
        self.update()
        self.reg[mb1.REG_CLK_LOAD] = 0
        self.update()

    def disable(self):
        self.reg[mb1.REG_EN] = 0
        self.update()

    def disable_auto(self):
        self.disable_adc_sync()

    def enable_adc(self):
        self.reg[mb1.REG_ADC_EN] = 1
        self.update()

    def disable_adc(self):
        self.reg[mb1.REG_ADC_EN] = 0
        self.update()

    def enable_adc_sync(self):
        self.reg[mb1.REG_ADC_SYNC] = 1
        self.update()

    def disable_adc_sync(self):
        self.reg[mb1.REG_ADC_SYNC] = 0
        self.update()

    @staticmethod
    def pack_dac_data(data):
        if isinstance(data, int):
            bdata = bytearray(data.to_bytes(4, 'little'))
        elif isinstance(data, list):
            np_array = np.array(data, dtype=np.uint32)
            bdata = bytearray(np_array.tobytes())
        elif isinstance(data, bytearray):
            bdata = data

        if len(bdata) % 16 != 0: # USB 3.0 requires 16 bytes packet size
            bdata += bytearray(16 - len(bdata) % 16)
        return bdata

    @staticmethod
    def unpack_dac_data(data):
        return np.frombuffer(data, dtype=np.uint32)
        
    @staticmethod
    def unpack_adc_data(data):
        np_data = np.frombuffer(data, dtype=np.int16)
        processed_data = [mb1.adc2v(d) for d in np_data]
        return np.array(processed_data, dtype=float).reshape(-1, 2).transpose()

    ## Peripheral functions
    ## Use load() to load peripheral instruction into board memory
    def write(self, data):
        self.WriteToPipeIn(mb1.ADDR_PIPEIN_DAC, self.pack_dac_data(data))
   
    def auto_mode(self, timeout=10):
        self.reg_dac_data = []
        self.reg_adc_data = []
        self.is_auto_mode = True
        self.auto_mode_timeout = timeout

        return AutoModeContextManager(self)
    
    def _exec(self):
        # Run
        self.disable()
        self.reset_fifo()
        self.reset_logic()
        self.reset_peripheral()

        self.write(self.reg_dac_data)
        self.enable_auto()

        start_time = time.time()
        while time.time() - start_time < self.auto_mode_timeout:
            self.update()
            if self.reg[mb1.REG_DAC_COUNT] != 0:
                time.sleep(self.SLEEP_TIME)
            else:
                break
        
        self.disable()

        # Process data
        self.reg_adc_id_index = {}
        self.reg_adc_id_data = {}
        self.reg_dac_channel_data = [[0]] * 4
        dac_period = self.reg[mb1.REG_DAC_PERIOD]
        adc_period = self.reg[mb1.REG_ADC_PERIOD]
        for time, d in enumerate(self.reg_dac_data):
            if BIT_EQUAL(d, mb1.CMD_SLEEP, mb1.MASK_CMD):
                sleep_time = BIT_GET(d, mb1.MASK_SLEEP_TIME) + 1
                for i in range(4):
                    self.reg_dac_channel_data[i].extend([self.reg_dac_channel_data[i][-1]] * sleep_time)
                continue

            for i in range(4):
                self.reg_dac_channel_data[i].append(self.reg_dac_channel_data[i][-1])
            
            if BIT_EQUAL(d, mb1.ID_DAC, mb1.MASK_ID):
                if BIT_EQUAL(d, 1, mb1.MASK_DAC_CLEAR):
                    for i in range(4):
                        self.reg_dac_channel_data[i][-1] = 0
                else:
                    c = BIT_GET(d, mb1.MASK_DAC_CHANNEL)
                    v = mb1.dac2v(BIT_GET(d, mb1.MASK_DAC_DATA))
                    self.reg_dac_channel_data[c][-1] = v

            elif BIT_EQUAL(d, mb1.ID_ADC, mb1.MASK_ID):
                id = BIT_GET(d, mb1.MASK_DATA)
                id_index = time * (dac_period + 1) // (adc_period + 1)
                self.reg_adc_id_index[id] = id_index

        # Read back ADC data
        self.reg_adc_data = self.read_adc()
        if self.reg_adc_data is None:
            logger.error('<mb1::exec> No data received.')
            return
        
        for id, index in self.reg_adc_id_index.items():
            if index >= len(self.reg_adc_data):
                logger.warning(f'<mb1::exec> Insufficient data. Expected at least {index}, received {len(self.reg_adc_data)}.')
            else:
                self.reg_adc_id_data[id] = self.reg_adc_data[index]

    def load(self, *args):
        if self.is_auto_mode:
            self.reg_dac_data.extend(*args)
        else:
            self.write(*args)
    
    def read_adc(self):
        self.update()

        fifo_count = self.reg[mb1.REG_ADC_COUNT]
        if fifo_count == 0:
            logger.warning('<mb1::read_adc> No data.')
            return None
        actual_read_count = int(np.ceil(fifo_count / 4) * 4)
        bdata_len = actual_read_count * 4 # USB 3.0 requires 16 bytes packet size
        buffer = bytearray(bdata_len)
        self.ReadFromPipeOut(mb1.ADDR_PIPEOUT_ADC, buffer)

        return self.unpack_adc_data(buffer[:fifo_count*4])
    
    def get_adc_data(self, id=None):
        if id in self.reg_adc_id_data.keys():
            return self.reg_adc_id_data[id]
        else:
            logger.warning(f'<mb1::get_adc_data> No data for id {id}.')
            return None
    
    def sleep(self, t=0):
        """ Sleep for t cycles, cycle period is determined by peripheral pulse period.
        """
        self.load(mb1.rsleep(t))

    def adc(self, id):
        """ This will insert empty instruction to label ADC data point with id.
        Notice that this will not enable ADC nor retrieve data.
        """
        self.load(mb1.radc(id=id))

    def dac(self, mode=None, pin=0, v=0):
        """ Apple voltage to pin.
        Voltage range: -5V ~ 5V
        Supported modes: clear
        """
        if mode == 'clear':
            self.load(mb1.rdac(clr=1))
            return
        
        channel = mb1.get_dac_channel(pin)

        self.switch(pin, 'dac')
        self.load(mb1.rdac(c=channel, v=mb1.v2dac(v)))

    def switch(self, mode='off', pin=0):
        """ Supported modes: off, clear, adc, dac, gnd
        """
        if mode == 'clear':
            self.load(
                mb1.rswitch(id=0, clr=1),
                mb1.rswitch(id=1, clr=1),
                mb1.rswitch(id=2, clr=1),
                mb1.rswitch(id=3, clr=1),
                mb1.rswitch(id=4, clr=1),
                mb1.rswitch(id=5, clr=1)
            )
            self.reg_switch_map = [-1] * 84

        elif mode == 'off':
            prev_switch_y = self.reg_switch_map[pin]
            if prev_switch_y == -1:
                return
            self.load(mb1.rswitch(x=pin, y=prev_switch_y, on=0))
            self.reg_switch_map[pin] = -1

        elif mode in ['adc', 'dac', 'gnd']:
            switch_y = self.get_switch_y(pin, mode)
            if switch_y < 0: # no connection available
                logger.error(f'<mb1::switch> Mode {mode} not available at pin {pin}.')
                return
            prev_switch_y = self.reg_switch_map[pin]
            if prev_switch_y == -1: # no previous connection
                self.load(mb1.rswitch(x=pin, y=switch_y, on=1))
                self.reg_switch_map[pin] = switch_y
            elif prev_switch_y != switch_y: # previous connection exists
                self.load(mb1.rswitch(x=pin, y=prev_switch_y, on=0))
                self.load(mb1.rswitch(x=pin, y=switch_y, on=1))
                self.reg_switch_map[pin] = switch_y

        else:
            logger.error(f'<mb1::switch> Unknown mode {mode}.')

    ## Debug and plot functions
    def print_dac_data(self):
        for d in self.reg_dac_data:
            print(f'  {d:08x}')

    def plot(self, title='', save=False):
        if not self.reg_dac_data:
            logger.warning('<mb1::plot> No data to plot.')
            return
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots()
        
        # Plot DAC data
        ax.set_xlabel('Time (us)')
        ax.set_ylabel('Voltage (V)')
        dac_period = (self.reg[mb1.REG_DAC_PERIOD] + 1) / 100
        dac_time = np.arange(0, len(self.reg_dac_data)) * dac_period  # unit us
        for c in range(1, 4):
            ax.plot(dac_time, self.reg_dac_channel_data[c], label=f'DAC{c}', color=plt.cm.Set1(c))

        # Plot ADC data
        ax2 = ax.twinx()
        ax2.set_ylabel('Voltage (V)')
        adc_period = (self.reg[mb1.REG_ADC_PERIOD] + 1) / 100
        adc_time = np.arange(0, len(self.reg_adc_data)) * adc_period  # unit us
        for c in range(2):
            ax2.plot(adc_time, self.reg_adc_data[c], label=f'ADC{c}', color=plt.cm.Set2(c), marker='.')

        # Plot ADC data points
        for id, data in self.reg_adc_id_data.items():
            ax2.axvline(x=data * adc_period, color='r', linestyle='--', label=f'ADC{id}')

        ax.set_ylim(-5, 5)
        ax2.set_ylim(-5, 5)
        ax.set_title(title)
        ax.legend(loc='upper left')
        ax2.legend(loc='upper right')

        if save:
            plt.savefig(title+'.png')
            plt.close()
        else:
            plt.show()

    ## Peripheral mapping functions
    @staticmethod
    def v2dac(v):
        return np.clip(int((v+5)/10*4096), a_max=0xfff, a_min=0x000)
    
    @staticmethod
    def dac2v(dac):
        return dac/4096*10.0-5.0
    
    @staticmethod
    def adc2v(adc):
        if adc & 0x2000:
            adc = -(0x4000 - adc)
        return -(adc/8192*5.0)

    @staticmethod
    def get_led_message(no):
        return mb1.LED_MESSAGE[no]
    
    @staticmethod
    def get_dac_channel(x):
        g = x // 28
        return mb1.DAC_CHANNEL_MAP[g]
    
    @staticmethod
    def get_switch_y(x, device):
        g = x // 28
        return mb1.SWITCH_MAP[g][device]
    
    @staticmethod
    def get_adc_channel(x):
        g = x // 28
        return mb1.ADC_CHANNEL_MAP[g]
    
    ## Peripheral instructions
    @staticmethod
    def radc(id=0):
        return BIT(mb1.CMD_IDLE, mb1.MASK_CMD) | BIT(mb1.ID_ADC, mb1.MASK_ID) | BIT(id, mb1.MASK_DATA)

    @staticmethod
    def rswitch(x=0, y=0, on=0, clr=0, id=None):
        g = x // 28
        if id is None:
            id = g * 2 + (x - g * 28) // 16
        x = x - g * 28 - id * 16
        data = BIT(clr, mb1.MASK_SWITCH_CLEAR) | BIT(y, mb1.MASK_SWITCH_Y) | BIT(x, mb1.MASK_SWITCH_X) | BIT(on, mb1.MASK_SWITCH_ON)
        return BIT(mb1.CMD_NORMAL, mb1.MASK_CMD) | BIT(mb1.ID_SW1 + id, mb1.MASK_ID) | BIT(data, mb1.MASK_DATA)

    @staticmethod
    def rsleep(t=100):
        return BIT(mb1.CMD_SLEEP, mb1.MASK_CMD) | BIT(t, mb1.MASK_SLEEP_TIME)
    
    @staticmethod
    def rdac(c=0, v=0x800, clr=0):
        data = BIT(1, mb1.MASK_DAC_CLEAR) | BIT(c, mb1.MASK_DAC_CHANNEL) | BIT(int(v), mb1.MASK_DAC_DATA)
        return BIT(mb1.CMD_NORMAL, mb1.MASK_CMD) | BIT(mb1.ID_DAC, mb1.MASK_ID) | data
    
    # ## Self-test functions
    # def test(self):
    #     self.reset()
    #     if not self.testPipe():
    #         return False
    #     if not self.testLogic():
    #         return False
    #     if not self.testPeripheral():
    #         return False
    #     return True

    # def testLogic(self):
    #     logger.info('<mb1::TestLogic> Testing logic...')
    #     ## Put board into sleep state
    #     self.disable()
    #     data = [0, 0, 0] + mb1.sleep(1000)
    #     self.load(data)
    #     self.update()
    #     peri_count = self.reg[mb1.REG_DAC_COUNT]
    #     if peri_count != 4:
    #         logger.error(f'<mb1::TestLogic> Pipe write failed. Expected 4, received {peri_count}.')
    #         return False
        
    #     ## Put board into normal state
    #     self.enable()
    #     self.update()
    #     last_data = self.reg[mb1.REG_LAST_DAC]
    #     if last_data != data[-1]:
    #         logger.error(f'<mb1::TestLogic> Data match failed. Expected {data[-1]:08x}, received {last_data:08x}.')
    #         return False
        
    #     return True
    
    # def testPipe(self):
    #     logger.info('<mb1::TestPipe> Testing pipe...')
    #     ## Write to and read back from pipe to verify data integrity
    #     data = [0x0000ffff, 0x00ff00ff, 0x0f0f0f0f, 0x12345678]
    #     send_data = self.pack_dac_data(data)
    #     self.WriteToPipeIn(mb1.ADDR_PIPEIN_TESTPIPE, send_data)
    #     recv_data = bytearray(len(send_data))
    #     self.ReadFromPipeOut(mb1.ADDR_PIPEOUT_TESTPIPE, recv_data)

    #     if send_data == recv_data:
    #         logger.info('<mb1::TestPipe> Success.')
    #         return True
    #     else:
    #         logger.error('<mb1::TestPipe> Failed.')
    #         return False

    # def testPeripheral(self):
    #     logger.info('<mb1::TestPeripheral> Testing peripheral...')
    #     logger.info('<mb1::TestPeripheral> This test will always conclude success.')

    #     ## Connect DAC to ADC
    #     original_peri_pulse_period = self.reg[mb1.REG_DAC_PERIOD]
    #     self.setPeriPulsePeriod(99)
    #     self.load(
    #         mb1.switch(x=0, y=1, on=1)+\
    #         mb1.dacSeries(2, np.arange(0x000, 0xfff, 0x10))+\
    #         mb1.dacSeries(2, np.arange(0xfff, 0x000, -0x10))+\
    #         mb1.switch(x=0, y=1, on=0)
    #     )
    #     self.setPeriPulsePeriod(original_peri_pulse_period)
    #     return True

    
class AutoModeContextManager:
    def __init__(self, board):
        self.board = board

    def __enter__(self):
        pass

    def __exit__(self, exc_type, exc_value, traceback):
        self.board._exec()
