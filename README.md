# 1. Memory Board User Guide

## 1.1. Basic information


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

## 1.2. Software Installation

### 1.2.1. Install Python3.7

Install **Miniconda3 Windows 64-bit** [Official webpage](https://docs.conda.io/en/latest/miniconda.html).
**Notice: Allow Miniconda to modify PATH variables.**

Open Anaconda Command Prompt.

```
conda create -n py3.7 python=3.7
conda activate py3.7
conda install numpy
```

### 1.2.2. Install **FrontPanel** SDK [Google Drive](https://drive.google.com/file/d/1HM5w99bJSepEbRAgtagARoK4IIzPZ-vO/view?usp=sharing)

After installing FrontPanel SDK, you should add FrontPanel Python API to system environment `"Path"`. The path should contains "ok.py" and "_ok.pyd" file and be similar to:

    your_path_to/Opal Kelly/FrontPanelUSB/API/Python/3.7/x64

**Notice: Install driver-only from [Opal Kelly](https://pins.opalkelly.com/downloads) if the above link is unavailable.**

### 1.2.3. Download **Memboard** Python library from [Github](https://github.com/frazier-zh/memboard-python-api/archive/refs/heads/master.zip)

## 1.3. Power Configuration

## 1.4. Python Example

```Python
import memboard as mb
from memboard import wait, time, apply, measure
import memboard.unit as u

import numpy as np # Matrix/array library

```

## 1.5. API Reference

### 1.5.1. `connect()`

### 1.5.2. `execute()`

### 1.5.3. `apply()`

### 1.5.4. `measure()`

### 1.5.5. `ground()`

### 1.5.6. `wait()`

### 1.5.7. `time()`

## 1.6. FPGA Programming Guide

Refer to the [guide](verilog/README.md).

ADC Sample speed 1260ns

DAC single port set speed 80ns

DAC parallel interface set speed 200ns

DAC maximum glitch amplitude +-1V(12V), +-0.1V(5V)

DAC maximum glitch settle time 1000ns(12V), 400ns(5V)

Swtich set speed 190ns ?
