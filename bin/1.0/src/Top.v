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

//OkData
wire [15:0] ep20status; //Status bit
wire [15:0] ep21data; //ADC dataout[0]
wire [15:0] ep22data; //ADC dataout[1]
wire [15:0]	ep00control; //Control bit
wire [15:0]	ep01data; //Switch 1,2 {7'b0,[0]onoff,[7:0]address}
wire [15:0]	ep02data; //Switch 3,4 {7'b0,[0]onoff,[7:0]address}
wire [15:0]	ep03data; //Switch 5,6 {7'b0,[0]onoff,[7:0]address}
wire [15:0]	ep04data; //DAC {2'b0,[1:0]address,[11:0]data}

//Main Logic
wire sw_group1_reset;
wire sw_group2_reset;
wire sw_group3_reset;
wire sw_group1_set;
wire sw_group2_set;
wire sw_group3_set;
wire adc_enable;
wire adc_reset;
wire [13:0] adc_out_a;
wire [13:0] adc_out_b;
wire dac_enable;
wire dac_reset;
wire [1:0] dac_address;
wire [11:0] dac_data;

wire sw_group1_ready;
wire sw_group2_ready;
wire sw_group3_ready;
wire adc_ready;
wire dac_ready;

wire [2:0] DEBUG_adc_stage;

//Wire Logic
assign ep20status = {13'b0,DEBUG_adc_stage};
assign ep21data = (adc_ready==1)?{2'b0,adc_out_a}:16'b0;
assign ep22data = (adc_ready==1)?{2'b0,adc_out_b}:16'b0;
assign {
	adc_reset,adc_enable,
	sw_group1_reset,sw_group2_reset,sw_group3_reset,dac_reset,
	sw_group1_set,sw_group2_set,sw_group3_set,dac_enable
	} = ep00control[9:0];
assign LED[7:0] = ~{adc_ready,dac_ready,sw_group1_ready,sw_group2_ready,sw_group3_ready,DEBUG_adc_stage};

Top_Switch SW_GROUP1(
	.clk(CLK),
	.sw1_reset(RESET_switch1),
	.sw1_cs(CS_switch1),
	.sw1_ax(AX_switch1),
	.sw1_ay(AY_switch1),
	.sw1_strobe(Strobe_switch1),
	.sw1_data(DATA_switch1),
	
	.sw2_reset(RESET_switch2),
	.sw2_cs(CS_switch2),
	.sw2_ax(AX_switch2),
	.sw2_ay(AY_switch2),
	.sw2_strobe(Strobe_switch2),
	.sw2_data(DATA_switch2),
	
	.sw_set(sw_group1_set),
	.sw_reset(sw_group1_reset),
	.sw_ready(sw_group1_ready),
	.address(ep01data[7:0]),
	.onoff(ep01data[8])
);
Top_Switch SW_GROUP2(
	.clk(CLK),
	.sw1_reset(RESET_switch3),
	.sw1_cs(CS_switch3),
	.sw1_ax(AX_switch3),
	.sw1_ay(AY_switch3),
	.sw1_strobe(Strobe_switch3),
	.sw1_data(DATA_switch3),
	
	.sw2_reset(RESET_switch4),
	.sw2_cs(CS_switch4),
	.sw2_ax(AX_switch4),
	.sw2_ay(AY_switch4),
	.sw2_strobe(Strobe_switch4),
	.sw2_data(DATA_switch4),
		
	.sw_set(sw_group2_set),
	.sw_reset(sw_group2_reset),
	.sw_ready(sw_group2_ready),
	.address(ep02data[7:0]),
	.onoff(ep02data[8])
);
Top_Switch SW_GROUP3(
	.clk(CLK),
	.sw1_reset(RESET_switch5),
	.sw1_cs(CS_switch5),
	.sw1_ax(AX_switch5),
	.sw1_ay(AY_switch5),
	.sw1_strobe(Strobe_switch5),
	.sw1_data(DATA_switch5),
	
	.sw2_reset(RESET_switch6),
	.sw2_cs(CS_switch6),
	.sw2_ax(AX_switch6),
	.sw2_ay(AY_switch6),
	.sw2_strobe(Strobe_switch6),
	.sw2_data(DATA_switch6),
			
	.sw_set(sw_group3_set),
	.sw_reset(sw_group3_reset),
	.sw_ready(sw_group3_ready),
	.address(ep03data[7:0]),
	.onoff(ep03data[8])
);

Top_DAC DAC1(
	.CLK(CLK),
	.DB(DB_DAC),
	.AD(AD_DAC),
	.RW(RW_DAC),
	.LDAC(LDAC_DAC),
	.CS(CS_DAC),
	.CLR(CLR_DAC),

	.dac_enable(dac_enable),
	.dac_reset(dac_reset),
	.dac_ready(dac_ready),
	.address(ep04data[13:12]),
	.data(ep04data[11:0])
);

Top_ADC ADC1(
	.CLK(CLK),
	.SCLK(SCLK_ADC),
	.CNVST(CNVST_ADC),
	.CS(CS_ADC),
	.BUSY(BUSY_ADC),
	.DoutA(DoutA_ADC),
	.DoutB(DoutB_ADC),
	.adc_out_a(adc_out_a),
	.adc_out_b(adc_out_b),
	.adc_enable(adc_enable),
	.adc_reset(adc_reset),
	.adc_ready(adc_ready),
	
	.debug_adc_stage(DEBUG_adc_stage)
);

//Ok
wire [17*3-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));
okWireOR #(.N(3)) wireOR (.ok2(ok2), .ok2s(ok2x));

//Ok Data I/O
okWireOut ep20(.ok1(ok1),.ok2(ok2x[ 0*17 +: 17 ]),.ep_addr(8'h20),.ep_datain(ep20status));
okWireOut ep21(.ok1(ok1),.ok2(ok2x[ 1*17 +: 17 ]),.ep_addr(8'h21),.ep_datain(ep21data));
okWireOut ep22(.ok1(ok1),.ok2(ok2x[ 2*17 +: 17 ]),.ep_addr(8'h22),.ep_datain(ep22data));
okWireIn ep00(.ok1(ok1),.ep_addr(8'h00),.ep_dataout(ep00control));
okWireIn ep01(.ok1(ok1),.ep_addr(8'h01),.ep_dataout(ep01data));
okWireIn ep02(.ok1(ok1),.ep_addr(8'h02),.ep_dataout(ep02data));
okWireIn ep03(.ok1(ok1),.ep_addr(8'h03),.ep_dataout(ep03data));
okWireIn ep04(.ok1(ok1),.ep_addr(8'h04),.ep_dataout(ep04data));

endmodule
