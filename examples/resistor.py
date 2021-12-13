import memboard as mb
from memboard import wait, time, apply, measure
import memboard.unit as u

import numpy as np

def run():
    top_pin = 29
    bottom_pin = 84

    apply(pin=1, v=2.5 *u.V)

    return time(), measure(pin=bottom_pin, drive_pin=top_pin, v=1 *u.V)

with mb.connect('top.bit'):
    mb.execute(run, every=200 *u.us, total=5 *u.s, out='test')