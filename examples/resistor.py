import memboard as mb
from memboard import wait, time, apply, measure, reset, output
import memboard.unit as u


def run():
    top_pin = 29
    bottom_pin = 84

    reset('all')
    apply(pin=1, v=2 *u.V)
    output['time'] = time()
    output['current'] = measure(pin=bottom_pin, drive_pin=top_pin, v=1 *u.V)


with mb.connect('./verilog/src/top.bit'):
    mb.execute(run, every=200 *u.us, total=5 *u.s, filename='test')