# Introduction



[XEM6010 User Manual](https://opalkelly.com/products/xem6010/)


ADC Sample speed 1260ns

DAC single port set speed 80ns

DAC parallel interface set speed 200ns

DAC maximum glitch amplitude +-1V(12V), +-0.1V(5V)

DAC maximum glitch settle time 1000ns(12V), 400ns(5V)

Swtich set speed 190ns ?

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

## Install Python3.7

1. Install Miniconda3 Windows 64-bit [Official webpage](https://docs.conda.io/en/latest/miniconda.html)

```
conda create -n py3.7 python=3.7
conda activate py3.7
conda install numpy
```

## Install **FrontPanel** Driver [Google Drive](https://pins.opalkelly.com/downloads)

## Download **Memboard** Python Library [Github](https://drive.google.com/file/d/1HM5w99bJSepEbRAgtagARoK4IIzPZ-vO/view?usp=sharing)

# FPGA Programming Guide

## FrontPanel HDL [Official webpage](https://docs.opalkelly.com/fpsdk/frontpanel-hdl/)

The use of FrontPanel components to control and observe pieces of your FPGA design requires the instantiation of one or more modules in your toplevel HDL.

The host interface is the block which connects directly to pins on the FPGA which are connected to the USB microcontroller.  This is the entry point for FrontPanel into your design.

The endpoints connect to a shared control bus on the host interface.  This internal bus is used to shuttle the endpoint connections to and from the host interface.  Several endpoints may be connected to this shared bus.  FrontPanel uses endpoint addresses to select which endpoint it is communicating with, so each endpoint must have its own unique address to work properly.

### Endpoint Types

| ENDPOINT TYPE | ADDRESS RANGE | SYNC/ASYNC | DATA TYPE |
|---|---|---|---|
|Wire In|0x00 – 0x1F|Asynchronous|Signal state|
|Wire Out|0x20 – 0x3F|Asynchronous|Signal state|
|Trigger In|0x40 – 0x5F|Synchronous|One-shot|
|Trigger Out|0x60 – 0x7F|Synchronous|One-shot|
|Pipe In|0x80 – 0x9F|Synchronous|Multi-byte transfer|
|Pipe Out|0xA0 – 0xBF|Synchronous|Multi-byte transfer|

### Wires

Wire is used to communicate asynchronous signal state between the host (PC) and the target (FPGA).  The okHostInterface supports up to 32 Wire In endpoints and 32 Wire Out endpoints connected to it.  To save bandwidth, all Wire In or Wire Out endpoints are updated at the same time and written or read by the host in one block.

All Wire In (to FPGA) endpoints are updated by the host at the same time with the call `UpdateWireIns()`.  Prior to this call, the application sets new Wire In values using the API method `SetWireInValue()`.  The `SetWireInValue()` simply updates the wire values in a data structure internal to the API.  `UpdateWireIns()` then transfers these values to the FPGA.

All Wire Out (from FPGA) endpoints are likewise read by the host at the same time with a call to `UpdateWireOuts()`.  This call reads all 32 Wire Out endpoints and stores their values in an internal data structure.  The specific endpoint values can then be read out using `GetWireOutValue()`.

### Triggers

Triggers are used to communicate a singular event between the host and target.  A Trigger In provides a way for the host to convey a “one-shot” on an arbitrary FPGA clock.  A Trigger Out provides a way for the FPGA to signal the host with a “one-shot” or other single-event indicator.

Triggers are read and updated in a manner similar to Wires.  All Trigger Ins are transferred to the FPGA at the same time and all Trigger Outs are transferred from the FPGA at the same time.

Trigger Out information is read from the FPGA using the call `UpdateTriggerOuts()`.  Subsequent calls to `IsTriggered()` then return ‘true’ if the trigger has been activated since the last call to `UpdateTriggerOuts()`.

### Pipes

Pipe communication is the synchronous communication of one or more bytes of data.  In both Pipe In and Pipe Out cases, the host is the master.  Therefore, the FPGA must be able to accept (or provide) data on any time.  Wires, Triggers, and FIFOs can make things a little more negotiable.

When data is written by the host to a Pipe In endpoint using `WriteToPipeIn(…)`, the device driver will packetize the data as necessary for the underlying protocol.  Once the transfer has started, it will continue to completion, so the FPGA must be prepared to accept all of the data.

When data is read by the host from a Pipe Out endpoint using `ReadFromPipeOut(…)`, the device driver will again packetize the data as necessary.  The transfer will proceed from start to completion, so the FPGA must be prepared to provide data to the Pipe Out as requested.

**Notice: Byte Order (USB 2.0)**

Pipe data is transferred over the USB in 8-bit words but transferred to the FPGA in 16-bit words.  Therefore, on the FPGA side (HDL), the Pipe interface has a 16-bit word width but on the PC side (API), the Pipe interface has an 8-bit word width.

When writing to Pipe Ins, the first byte written is transferred over the lower order bits of the data bus (7:0).  The second byte written is transferred over the higher order bits of the data bus (15:8).  Similarly, when reading from Pipe Outs, the lower order bits are the first byte read and the higher order bits are the second byte read.

### Endpoint Data Widths

|ENDPOINT TYPE|USB 2.0|USB 3.0|PCI EXPRESS|
|---|---|---|---|
|Wire|16|32|32|
|Trigger|16|32|32|
|Pipe|16|32|64|

### Host Interface Clock Speed

The HDL host interface is a slave interface from the host. It runs at a fixed clock rate that is dependent upon the interface type for the device.

- USB 2.0 interfaces run at 48 MHz (20.83 ns clock period)
- USB 3.0 interfaces run at 100.8 MHz (9.92 ns clock period)
- PCI Express (x1) interfaces run at 50 MHz (20 ns clock period)

## Verilog examples [See more examples](https://opalkelly.com/examples/)

```Verilog
wire [17*1-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2)
);
okWireOR #(.N(2)) wireOR (.ok2(ok2), .ok2s(ok2x));

okWireIn inA(
     .ok1(ok1),
     .ep_addr(8'h00),
     .ep_dataout (dataA)
);
 
okWireOut outA(
     .ok1(ok1),
     .ok2(ok2x[0*17 +: 17]),
     .ep_addr (8'h20),
     .ep_datain (dataA)
);
```

# Documents

## FrontPanel API Reference

    'install_path\Opal Kelly\FrontPanelUSB\Documentation'

## FrontPanel SDK

    https://docs.opalkelly.com/fpsdk

The FrontPanel SDK (Software Development Kit) is a flexible API (Application Programmer’s Interface) providing all the benefits of FrontPanel to your own custom application.  These benefits include:

- Device discovery and enumeration
- FPGA configuration
- FPGA communication using wires, triggers, pipes
- Abstraction to a common development platform for both USB and PCI Express devices

## FrontPanel Examples

    https://opalkelly.com/examples/

The examples contains both software and HDL portions. The software and HDL must work in tandem if FrontPanel is to be used on the PC end to perform tasks on the FPGA. The HDL in this section is designed to be set within the FrontPanel Framework HDL, available on the HDL Framework page for USB 2.0 and USB 3.0. It is assumed that the FPGA is configured with the bitfile generated by the HDL before the hardware is run. For specific information about each of these methods or modules, consult the FrontPanel User’s Manual, the FrontPanel API guide, and the samples and README files provided with the FrontPanel download.