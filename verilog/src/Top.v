`timescale 1ns / 1ps
module TOP(
	//Peripheral control signals
	inout [11:0] DB_DAC,
	output [1:0] AD_DAC,
	output RW_DAC,
	output LDAC_DAC,
	output CS_DAC,
	output CLR_DAC,
	output RESET_switch1,
	output CS_switch1,
	output [3:0] AX_switch1,
	output [2:0] AY_switch1,
	output Strobe_switch1,
	output DATA_switch1,
	output RESET_switch2,
	output CS_switch2,
	output [3:0] AX_switch2,
	output [2:0] AY_switch2,
	output Strobe_switch2,
	output DATA_switch2,
	output RESET_switch3,
	output CS_switch3,
	output [3:0] AX_switch3,
	output [2:0] AY_switch3,
	output Strobe_switch3,
	output DATA_switch3,
	output RESET_switch4,
	output CS_switch4,
	output [3:0] AX_switch4,
	output [2:0] AY_switch4,
	output Strobe_switch4,
	output DATA_switch4,
	output RESET_switch5,
	output CS_switch5,
	output [3:0] AX_switch5,
	output [2:0] AY_switch5,
	output Strobe_switch5,
	output DATA_switch5,
	output RESET_switch6,
	output CS_switch6,
	output [3:0] AX_switch6,
	output [2:0] AY_switch6,
	output Strobe_switch6,
	output DATA_switch6,
	input CLK,
	output SCLK_ADC,
   output CNVST_ADC,
   output CS_ADC,
   input BUSY_ADC,
   output reg ADDR_ADC=0,
   input DoutA_ADC,
	input DoutB_ADC,
	output [7:0] LED,
	
	//OkHostInterface
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,
	output wire        i2c_sda,
	output wire        i2c_scl,
	output wire        hi_muxsel
 );

//OkHost
wire        ti_clk;
wire [30:0] ok1;
wire [16:0] ok2;

assign i2c_sda = 1'bz;
assign i2c_scl = 1'bz;
assign hi_muxsel = 1'b0;

//Ok
wire [17*4-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));
okWireOR #(.N(4)) wireOR (.ok2(ok2), .ok2s(ok2x));

// Status and control signal
wire clock_rst, fifo_rst, mem_rst, logic_rst, logic_en, logic_rdy, logic_rdy_trig;
wire [15:0] trig_in, wire_in;

assign {clock_rst, fifo_rst, mem_rst, logic_rst} = trig_in[1:0];
assign logic_en = wire_in[0];
assign LED = {7'b0, logic_rdy};

reg logic_rdy_delay;
always @(posedge CLK)
	logic_rdy_delay <= logic_rdy;
assign logic_rdy_trig = logic_rdy & ~logic_rdy_delay;

okWireIn ctrl_sig(.ok1(ok1),.ep_addr(8'h00),.ep_dataout(wire_in));
okTriggerIn rst_sig(.ok1(ok1),.ep_addr(8'h40),.ep_clk(CLK),.ep_trigger(trig_in));
okTriggerOut stat_sig(.ok1(ok1),.ok2(ok2x[3*17 +: 17]),.ep_addr(8'h60),.ep_clk(CLK),.ep_trigger({15'b0, logic_rdy_trig}));

// Memory interface
wire data32_in_empty;
wire data16_write, data16_read;
wire data_read, data_write;
wire [15:0] data16_in, data16_out, data_out;
wire [31:0] data32_in, main_bus;

okPipeIn pipe80(
	.ok1(ok1),
	.ok2(ok2x[0*17 +: 17]),
	.ep_addr(8'h80),
	.ep_write(data16_write),
	.ep_dataout(data16_in)
);

FIFO_16b_32b_64 fifo_data_in(
	.rst(fifo_rst),
	.wr_clk(ti_clk),
	.rd_clk(CLK),
	.din(data16_in),
	.wr_en(data16_write),
	.rd_en(data_read),
	.dout(data32_in),
	.full(),
	.empty(data32_in_empty)
);

okPipeOut pipeA0(
	.ok1(ok1),
	.ok2(ok2x[1*17 +: 17]),
	.ep_addr(8'hA0),
	.ep_read(data16_read),
	.ep_datain(data16_out)
);

FIFO_16b_16b_1k fifo_data_out(
	.rst(fifo_rst),
	.wr_clk(CLK),
	.rd_clk(ti_clk),
	.din(data_out),
	.wr_en(data_write),
	.rd_en(data16_read),
	.dout(data16_out),
	.full(),
	.empty()
);

wire mblock_en, mblock_clr, mblock_valid;

memory_control mem_ctrl(
	.clk(CLK),
	.data_in_empty(data32_in_empty),
	.data_read(data_read),
	.data_in(data32_in),
	.data_out(main_bus),
	.rst(mem_rst),
	.zero(mblock_clr),
	.rd_en(mblock_en),
	.valid(mblock_valid)
);

// Clock interface

wire time16_write;
wire [15:0] time16_in;
wire [47:0] time_out;

okPipeIn pipe81(
	.ok1(ok1),
	.ok2(ok2x[2*17 +: 17]),
	.ep_addr(8'h81),
	.ep_write(time16_write),
	.ep_dataout(time16_in)
);

wire clock_cs, clock_rdy, clock_cd, clock_en, clock_clr;

multiclock_interface clock(
	.clk(CLK),
	.rst(clock_rst),
	.ti_clk(ti_clk),
	.data_write(time16_write),
	.data_in(time16_in),
	.en(clock_en),
	.cd(clock_cd),
	.cs(clock_cs),
	.clr(clock_clr),
	.data_out(time_out),
	.rdy(clock_rdy)
);

// Main logic interface

wire [3:0] dev_no;
wire [3:0] op_bus;
wire [7:0] addr_bus;
wire [15:0] data_bus;
assign {data_bus, addr_bus, op_bus, dev_no} = main_bus;

wire switch_cs, adc_cs, dac_cs, timer_cs;
wire switch_rdy, adc_rdy, dac_rdy, timer_rdy;
wire [13:0] adc_out;

logic_control logic_ctrl(
	.clk(CLK),
	.en(logic_en),
	.rst(logic_rst),
	.rdy(logic_rdy),
	.mblock_en(mblock_en),
	.mblock_clr(mblock_clr),
	.mblock_valid(mblock_valid),
   .dev_no(dev_no),
	.data_bus(data_bus),
	.data_out_en(data_write),
	.data_out(data_out),
	.switch_cs(switch_cs), .adc_cs(adc_cs), .dac_cs(dac_cs), .timer_cs(timer_cs), .clock_cs(clock_cs),
	.switch_rdy(switch_rdy), .adc_rdy(adc_rdy), .dac_rdy(dac_rdy), .timer_rdy(timer_rdy), .clock_rdy(clock_rdy),
	.adc_out(adc_out),
	.time_out(time_out),
	.clock_cd(clock_cd),
	.clock_en(clock_en),
	.clock_clr(clock_clr)
);

// Device definitions

switch_interface_group switch(
	.RESET_switch1(RESET_switch1), .CS_switch1(CS_switch1), .AX_switch1(AX_switch1), .AY_switch1(AY_switch1), .Strobe_switch1(Strobe_switch1), .DATA_switch1(DATA_switch1),
	.RESET_switch2(RESET_switch2), .CS_switch2(CS_switch2), .AX_switch2(AX_switch2), .AY_switch2(AY_switch2), .Strobe_switch2(Strobe_switch2), .DATA_switch2(DATA_switch2),
	.RESET_switch3(RESET_switch3), .CS_switch3(CS_switch3), .AX_switch3(AX_switch3), .AY_switch3(AY_switch3), .Strobe_switch3(Strobe_switch3), .DATA_switch3(DATA_switch3),
	.RESET_switch4(RESET_switch4), .CS_switch4(CS_switch4), .AX_switch4(AX_switch4), .AY_switch4(AY_switch4), .Strobe_switch4(Strobe_switch4), .DATA_switch4(DATA_switch4),
	.RESET_switch5(RESET_switch5), .CS_switch5(CS_switch5), .AX_switch5(AX_switch5), .AY_switch5(AY_switch5), .Strobe_switch5(Strobe_switch5), .DATA_switch5(DATA_switch5),
	.RESET_switch6(RESET_switch6), .CS_switch6(CS_switch6), .AX_switch6(AX_switch6), .AY_switch6(AY_switch6), .Strobe_switch6(Strobe_switch6), .DATA_switch6(DATA_switch6),
	.clk(CLK), .cs(switch_cs), .rdy(switch_rdy), .op(op_bus), .addr(addr_bus), .data_in(data_bus)
);

adc_interface_ad7367 adc(
	.BUSY(BUSY_ADC), .SCLK(SCLK_ADC), .CNVST(CNVST_ADC), .CS(CS_ADC), .DOUTA(DoutA_ADC), .DOUTB(DoutB_ADC),
	.clk(CLK), .cs(adc_cs), .rdy(adc_rdy), .op(op_bus), .addr(addr_bus), .data_out(adc_out)
);

dac_interface_ad5725 dac(
	.AD(AD_DAC), .DB(DB_DAC), .RW(RW_DAC), .LDAC(LDAC_DAC), .CS(CS_DAC), .CLR(CLR_DAC),
	.clk(CLK), .cs(dac_cs), .rdy(dac_rdy), .op(op_bus), .addr(addr_bus), .data_in(data_bus)
);

timer_interface timer(
	.clk(CLK), .cs(timer_cs), .rdy(timer_rdy), .op(op_bus), .addr(addr_bus), .data_in(data_bus)
);

endmodule
