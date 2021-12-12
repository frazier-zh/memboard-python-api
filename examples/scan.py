import memboard as mb
from memboard import wait, time, apply, measure
import memboard.unit as u

import numpy as np

def run():
    top_pin_list = [29, 30, 31, 32, 33]
    bottom_pin2 = 83
    bottom_pin1 = 2
    results = np.zeros((3, 5))

    apply(pin=1, v=0.5 *u.V)
    apply(pin=84, v=0 *u.V)

    for i in range(5):
        results[0, i] = time()
        results[1, i] = measure(pin=bottom_pin1, drive_pin=top_pin_list[i], v=0.1 *u.V)
        results[2, i] = measure(pin=bottom_pin2, drive_pin=top_pin_list[i], v=0.1 *u.V)
        wait(10 *u.us)

    return results

with mb.connect():
    #with open('measurement.txt') as file:
    mb.execute(run, every=200 *u.us, total=10 *u.min, out=None)