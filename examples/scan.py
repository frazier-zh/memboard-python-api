import memboard as mb
from memboard import wait, time, apply, measure
import memboard.unit as u

import numpy as np

def run():
    top_pin_list = [29, 30, 31, 32, 33]
    bottom_pin = 83
    results = np.zeros((2, 5))

    apply(pin=1, v=0.5 *u.V)
    apply(pin=84, v=0 *u.V)

    for i in range(5):
        results[0, i] = time()
        results[2, i] = measure(pin=bottom_pin, drive_pin=top_pin_list[i], v=0.1 *u.V)
        wait(10 *u.us)

    return results


with mb.connect('../verilog/src/top.bit', debug=True):
    mb.register(run)
    mb.output_mem()
    mb.execute(every=200 *u.us, total=5 *u.s, out='scan')
