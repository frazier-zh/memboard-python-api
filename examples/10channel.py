import memboard as mb
from memboard import board
import memboard.unit as unit

top_pin = [1,3,5,8,11,15,61,59,57]
bottom_pin = [2,4,6,9,14,17,63,60,58]
voltage = 0.1 *unit.V
pulse_width = 1 *unit.us
repeat = 1 *unit.ms # Repeat interval, unit.ms, unit.s, unit.us, unit.min
end = 5 *unit.s # Repeat for 10 seconds

def main(output):
    output['time'] = mb.time()
    for i in range(len(top_pin)):
        output[str(top_pin[i])+'to'+str(bottom_pin[i])] = mb.measure(pin=top_pin[i], drive_pin=bottom_pin[i], v=voltage, width=pulse_width)

board.open()
mb.execute_debug(main, every=repeat, total=end, out='../PCB measurements/test4')
board.close()