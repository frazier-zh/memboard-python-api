import memboard as mb
import numpy as np

def iv_curve():
    voltage_list = np.linspace(-2, 5, 101, endpoint=True)@u_V

    mb.apply(socket='A1', v=0.1@u_V)
    for v in voltage_list:
        result = mb.measure(socket='B2', v=v)

    mb.apply(socket='A1', v=0.5@u_V)
    for v in voltage_list:
        result = mb.measure(socket='B2', v=v)