# Memory Board User Guide

## Basic information

    Memory board version:           2020-09-18
    
    ADC model:                      AD7367BRUZ
    DAC model:                      AD5725BRSZ-500RL7
    Switch model:                   MT8816AF1
    Socket model:                   

    Opal Kelly device model:        XEM6010-LX150
    FrontPanel driver version:      5.1.3
    Xilinx FPGA model:              Spartan-6, XC6SLX150-2fgg484
    ISE Design Suite version:       14.7

    FPGA core language:             Verilog
    API language:                   Python 3.7

## Software Installation

### 1. Install Python3.7

Install **Miniconda3 Windows 64-bit** [Official webpage](https://docs.conda.io/en/latest/miniconda.html).
>Note: Allow Miniconda to modify PATH variables.

Open Anaconda Command Prompt.

```
conda create -n py3.7 python=3.7
conda activate py3.7
conda install numpy
```

### 2. Install **FrontPanel** SDK [Google Drive](https://drive.google.com/file/d/1HM5w99bJSepEbRAgtagARoK4IIzPZ-vO/view?usp=sharing)

After installing FrontPanel SDK, you should add FrontPanel Python API to system environment `"Path"`. The path should contains "ok.py" and "_ok.pyd" file and be similar to:

    your_path_to/Opal Kelly/FrontPanelUSB/API/Python/3.7/x64

>Note: Install driver-only from [Opal Kelly](https://pins.opalkelly.com/downloads) if the above link is unavailable.

### 3. Download **Memboard** Python library from [Github](https://github.com/frazier-zh/memboard-python-api/archive/refs/heads/master.zip)

## Powering The Board

## Example

In this example, 

```Python
import memboard as mb
from memboard import wait, time, apply, measure, reset
import memboard.unit as u

import numpy as np

def run():
    top_pin_list = [29, 30, 31, 32, 33]
    bottom_pin = 83
    results = np.zeros((2, 5))

    reset('all')
    apply(pin=1, v=0.5 *u.V)
    apply(pin=84, v=0 *u.V)

    for i in range(5):
        results[0, i] = time()
        results[1, i] = measure(pin=bottom_pin, drive_pin=top_pin_list[i], v=0.1 *u.V)
        wait(1 *u.us)

    return results


with mb.connect('../verilog/src/top.bit'):
    mb.register(run)
    mb.execute(every=20 *u.us, total=1 *u.s, out='scan')
```

## API Reference

### `connect(path, debug)`

|Parameters|Type|Details
|---|---|---|
|path|str|Indicates path of FPGA binary file "top.bit"|
|debug|bool|Indicates debug mode|

### `add(func)`

|Parameters|Type|Details
|---|---|---|

### `execute()`

### `reset()`

### `apply()`

### `ground()`

### `measure()`

### `wait()`

### `time()`

## Datasheet

### 1. Socket and Pin Mapping

### 2. Execution Time

|Parts|Operation (ns)|Reset (ns)|
|---|---:|---:|
|ADC|1390|20|
|DAC|60|50|
|Switch|190|190|

>Note: Every operation has an additional 30ns processing time.

### 3. Connections of Switches

|Switch Group|Pin|ADC|DAC|
|---|---|---|---|
|Source|1-28|Channel 0|GND*, Channel 1|
|Gate|29-54|-|Channel 2|
|Drain|55-84|Channel 1|Channel 3|

**Channel 0 should always be set to 0V (GND).*

### 4. Non-idealities

1. DAC maximum glitch amplitude is 1V.
2. DAC maximum glitch time is 1000ns.
3. Switch settling time is 100ns.

## FPGA Programming Guide

Refer to the [guide](verilog/README.md).
