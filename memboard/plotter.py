import matplotlib.pyplot as plt
from matplotlib.cm import get_cmap
import numpy as np
import time

from .logger import TestLogger

# Plot style definition
def color(n: int):
    if n==0:
        return 0
    else:
        base = float(2**int(np.log2(n)))
        return (n+0.5)/base-1

def find_nearest(org, ref, range=0.1):
    l_bound = np.searchsorted(ref-range, org)
    r_bound = np.searchsorted(ref+range, org)
    return l_bound[l_bound!=r_bound]

def plot(log: TestLogger,
    window=10,
    point=100,
    interval=0.05,
    ylim=(0,1),
    cmap: str='viridis',
    **kwargs):

    # basic paramters
    n_curves = 0
    cparams = dict()
    cmap = get_cmap(cmap)
    
    # figure
    fig = plt.figure(figsize=(12,6))
    ax = fig.add_subplot(111)
    plt.ion()
    plt.show()

    t_next = 0
    while plt.fignum_exists(fig.number):
        if not log.is_alive(): # check logger status
            break

        log.updated.wait() # wait on logger update
        t = time.time() # sleep for interval
        if t<t_next:
            time.sleep(t_next - t)
        
        # --- Start Plotting ---
        ax.cla() # clear old graph

        t_end = log.dt
        t_start = t_end-window # plotting window

        ax.set_xlim(t_start, t_end)
        ax.set_ylim(*ylim)

        value_np = log.data.get().T # [t, v0, v1, ...]
        n_channel = value_np.shape[0]-1
        if value_np.size:
            n_point = value_np.shape[1]

            # covert on-board time to local time
            p_start = max(np.searchsorted(value_np[0], t_start)-1,0)

            for i in range(n_channel): 
                curve_key = f'ch.{i}'
                if curve_key not in cparams:
                    # (NO., color)
                    cparams[curve_key] = [n_curves, cmap(color(n_curves))]
                    n_curves += 1
                
                ax.scatter(value_np[0][p_start:], value_np[i+1][p_start:],\
                    label=curve_key, color=cparams[curve_key][1], **kwargs)
            
        ax.legend(loc='upper right')
        fig.canvas.draw()
        fig.canvas.flush_events()

        t_next = time.time()+interval # schedule next update

    plt.ioff()
    plt.close()
