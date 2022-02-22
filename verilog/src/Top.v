`timescale 1ns / 1ps
module TOP(
	//Peripheral control signals
	inout [11:0] DB_DAC,
	output [1:0] AD_DAC,
	output RW_DAC,
	output LDAC_DAC,
	output CS_DAC,
	output CLR_DAC,
	output RESET_SW1,
	output CS_SW1,
	output [3:0] AX_SW1,
	output [2:0] AY_SW1,
	output STROBE_SW1,
	output DATA_SW1,
	output RESET_SW2,
	output CS_SW2,
	output [3:0] AX_SW2,
	output [2:0] AY_SW2,
	output STROBE_SW2,
	output DATA_SW2,
	output RESET_SW3,
	output CS_SW3,
	output [3:0] AX_SW3,
	output [2:0] AY_SW3,
	output STROBE_SW3,
	output DATA_SW3,
	output RESET_SW4,
	output CS_SW4,
	output [3:0] AX_SW4,
	output [2:0] AY_SW4,
	output STROBE_SW4,
	output DATA_SW4,
	output RESET_SW5,
	output CS_SW5,
	output [3:0] AX_SW5,
	output [2:0] AY_SW5,
	output STROBE_SW5,
	output DATA_SW5,
	output RESET_SW6,
	output CS_SW6,
	output [3:0] AX_SW6,
	output [2:0] AY_SW6,
	output STROBE_SW6,
	output DATA_SW6,
	input CLK,
	output SCLK_ADC,
   output CNVST_ADC,
   output CS_ADC,
   input BUSY_ADC,
   output reg ADDR_ADC=0,
   input DOUTA_ADC,
	input DOUTB_ADC,
	
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
wire [17*6-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));
okWireOR #(.N(6)) wireOR (.ok2(ok2), .ok2s(ok2x));

// Status and control signal
wire clock_rst, fifo_rst, mem_rst, logic_rst, logic_en, logic_auto;
wire [15:0] logic_count, dev_state1, dev_state2;

wire [15:0] trig_in, wire_in;

assign {fifo_rst, mem_rst, logic_rst} = trig_in[2:0];
assign {logic_auto, logic_en} = wire_in[1:0];

okWireIn okWireIn00(.ok1(ok1),.ep_addr(8'h00),.ep_dataout(wire_in));
okWireOut okWireOut20(.ok1(ok1),.ok2(ok2x[3*17 +: 17]),.ep_addr(8'h20),.ep_datain(logic_count));
okWireOut okWireOut21(.ok1(ok1),.ok2(ok2x[4*17 +: 17]),.ep_addr(8'h21),.ep_datain(dev_state1));
okWireOut okWireOut22(.ok1(ok1),.ok2(ok2x[5*17 +: 17]),.ep_addr(8'h22),.ep_datain(dev_state2));
okTriggerIn okTriggerIn40(.ok1(ok1),.ep_addr(8'h40),.ep_clk(CLK),.ep_trigger(trig_in));

// Memory interface
wire data32_in_empty;
wire data16_write, data16_read;
wire data_read, data_write;
wire [15:0] data16_in, data16_out, data_out;
wire [31:0] data32_in, mem_in, main_bus;

okPipeIn okPipeIn80(
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

okPipeOut okPipeOutA0(
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

wire mem_read, mem_zero, mem_valid;
memory_control mem_ctrl(
	.clk(CLK),
	.din_empty(data32_in_empty),
	.din_read(data_read),
	.din(data32_in),
	.dout_read(mem_read),
	.dout(mem_in),
	.rst(mem_rst),
	.zero(mem_zero),
	.valid(mem_valid)
);

// Clock interface

wire time16_write;
wire [15:0] time16_in;
wire [47:0] time_out;

okPipeIn okPipeIn81(
	.ok1(ok1),
	.ok2(ok2x[2*17 +: 17]),
	.ep_addr(8'h81),
	.ep_write(time16_write),
	.ep_dataout(time16_in)
);

wire cd_en, cd_rdy, clock_clr;
multiclock_interface clock(
	.clk(CLK),
	.ti_clk(ti_clk),
	.data_write(time16_write),
	.data_in(time16_in),
	.en(cd_en),
	.rdy(cd_rdy),
	.clr(clock_clr),
	.data_out(time_out)
);

// Main logic interface
wire [7:0] dev_cs;
wire [7:0] dev_rdy;
wire [13:0] adc_out;

assign dev_rdy[0] = 1, dev_rdy[7] = 1;
assign LED[7:0] = {dev_rdy};

wire [3:0] logic_state;
logic_control logic_ctrl(
	.clk(CLK),
	.rst(logic_rst),
	.state(logic_state),
	.en(logic_en),
	.auto_en(logic_auto),
	.auto_count(logic_count),
	.mem_read(mem_read),
	.mem_zero(mem_zero),
	.mem_valid(mem_valid),
	.mem_in(mem_in),
	.main_bus(main_bus),
	.dev_cs(dev_cs),
	.dev_rdy(dev_rdy),
	.data_write(data_write),
	.data_out(data_out),
	.adc_out(adc_out),
	.time_out(time_out),
	.cd_en(cd_en),
	.cd_rdy(cd_rdy),
	.clock_clr(clock_clr)
);

// Device definitions
wire [3:0] dev_bus;
wire [3:0] op_bus;
wire [7:0] addr_bus;
wire [15:0] data_bus;
assign {data_bus, addr_bus, op_bus, dev_bus} = main_bus;

wire [3:0] adc_state;
adc_interface_ad7367 adc(
	.BUSY(BUSY_ADC), .SCLK(SCLK_ADC), .CNVST(CNVST_ADC), .CS(CS_ADC), .DOUTA(DOUTA_ADC), .DOUTB(DOUTB_ADC),
	.clk(CLK), .cs(dev_cs[1]), .rdy(dev_rdy[1]), .state(adc_state), .op(op_bus), .addr(addr_bus), .data_out(adc_out)
);

wire [3:0] dac_state;
dac_interface_ad5725 dac(
	.AD(AD_DAC), .DB(DB_DAC), .RW(RW_DAC), .LDAC(LDAC_DAC), .CS(CS_DAC), .CLR(CLR_DAC),
	.clk(CLK), .cs(dev_cs[2]), .rdy(dev_rdy[2]), .state(dac_state), .op(op_bus), .addr(addr_bus), .data_in(data_bus)
);

timer_interface timer(
	.clk(CLK), .cs(dev_cs[3]), .rdy(dev_rdy[3]), .op(op_bus), .data_in({data_bus, addr_bus})
);

assign AX_SW2 = AX_SW1, AX_SW4 = AX_SW3, AX_SW6 = AX_SW5;
assign AY_SW2 = AY_SW1, AY_SW4 = AY_SW3, AY_SW6 = AY_SW5;
assign STROBE_SW2 = STROBE_SW1, STROBE_SW4 = STROBE_SW3, STROBE_SW6 = STROBE_SW5;
assign DATA_SW2 = DATA_SW1, DATA_SW4 = DATA_SW3, DATA_SW6 = DATA_SW5;

wire [3:0] sw1_state;
switch_interface_group switch1(
	.RESET_SW1(RESET_SW1), .CS_SW1(CS_SW1), .RESET_SW2(RESET_SW2), .CS_SW2(CS_SW2),
	.clk(CLK), .cs(dev_cs[4]), .rdy(dev_rdy[4]), .state(sw1_state), .op(op_bus), .data_in(data_bus),
	.AX(AX_SW1), .AY(AY_SW1), .STROBE(STROBE_SW1), .DATA(DATA_SW1)
);

wire [3:0] sw2_state;
switch_interface_group switch2(
	.RESET_SW1(RESET_SW3), .CS_SW1(CS_SW3), .RESET_SW2(RESET_SW4), .CS_SW2(CS_SW4),
	.clk(CLK), .cs(dev_cs[5]), .rdy(dev_rdy[5]), .state(sw2_state), .op(op_bus), .data_in(data_bus),
	.AX(AX_SW3), .AY(AY_SW3), .STROBE(STROBE_SW3), .DATA(DATA_SW3)
);

wire [3:0] sw3_state;
switch_interface_group switch3(
	.RESET_SW1(RESET_SW5), .CS_SW1(CS_SW5), .RESET_SW2(RESET_SW6), .CS_SW2(CS_SW6),
	.clk(CLK), .cs(dev_cs[6]), .rdy(dev_rdy[6]), .state(sw3_state), .op(op_bus), .data_in(data_bus),
	.AX(AX_SW5), .AY(AY_SW5), .STROBE(STROBE_SW5), .DATA(DATA_SW5)
);

assign dev_state1 = {sw3_state, sw2_state, sw1_state, dac_state};
assign dev_state2 = {8'b0, adc_state, logic_state};

endmodule
