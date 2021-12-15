import memboard as mb
from memboard import wait, time, apply, measure, reset, output
import memboard.unit as u

def run():
    top_pin_list = [29, 30, 31, 32, 33]
    bottom_pin = 83

    reset('all')
    apply(pin=1, v=0.5 *u.V)
    apply(pin=84, v=0 *u.V)

    for i in range(5):
        output['time%d'%i] = time()
        output['current%d'%i] = measure(pin=bottom_pin, drive_pin=top_pin_list[i], v=0.1 *u.V)
        wait(1 *u.us)

with mb.connect('../verilog/src/top.bit', debug=True):
    mb.execute(run, every=20 *u.us, total=1 *u.s, filename='scan')