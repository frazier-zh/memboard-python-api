from memboard.logger import TestLogger
from memboard.device import FrontPanel
from memboard.plotter import plot

fp = FrontPanel()

fp.ShowDeviceList()
fp.Open()
fp.ShowPLLConfiguration()

fp.Load('./verilog/ADC_tb/Top.bit')

log = TestLogger(fp)

fp.ActivateTriggerIn(0x40, 1)
log.start()
plot(log, cmap='cool', ylim=(-10.5, 10.5), window=20, interval=0.05, s=8)
log.exit()