# Memory Board User Guide

## Basic information

    Memory board version:           2020-09-18
    API verison:                    2024-01-27
    
    ADC model:                      AD7367BRUZ
    DAC model:                      AD5725BRSZ-500RL7
    Switch model:                   MT8816AF1
    Socket model:                   

    Opal Kelly device model:        XEM7310-A200
    FrontPanel driver version:      5.1.3
    Xilinx FPGA model:              Artix-7, XC7A200T-1FBG484
    Vivado version:                 2023.2

    FPGA core language:             Verilog
    API language:                   Python 3.7

## Software Installation

### 1. Python3.7

Please refer to online tutorials.

### 2. **FrontPanel** SDK

Install "driver-only" from [Opal Kelly](https://pins.opalkelly.com/downloads).

### 3. **Memboard** Python library from [Github](https://github.com/frazier-zh/memboard-python-api/archive/refs/heads/master.zip)

```
git clone https://github.com/frazier-zh/memboard-python-api.git
```

## Powering The Board

Make the connection as illustrated as follows.

![Alt text](img/power_connection.png)

## Quick Start

```Python
from memboard.api import mb1
board = mb1()
board.connect()                 # connect board

board.switch('dac', pin=0)      # make pin 0 to connect to DAC
board.switch('adc', pin=83)     # make pin 83 to connect to ADC
board.dac(pin=0, v=2.5)         # apply 2.5V on pin 0
board.sleep(1000)               # sleep 1000us
board.dac(pin=0, v=0)           # apply 0V on pin 0
board.switch('off', pin=0)      # disconnect pin 0
board.switch('off', pin=83)

print(board.read_adc())         # read adc data

board.close()
```

## Using auto mode

To perform a test with accurate timing, we need to prepare the board operation command upfront.

## Tips

### Non-idealities

1. DAC maximum glitch amplitude: 1V.
2. DAC maximum glitch time: 1us.
3. Switch settling time: 100ns.

