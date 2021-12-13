`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:23:40 12/13/2021
// Design Name:   TOP
// Module Name:   C:/Users/zjyyf/Desktop/RRAM_FPGA/memboard_test/testbench/TOP_tb.v
// Project Name:  memboard_test
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: TOP
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module TOP_tb;
	// Inputs
	reg CLK;
	
	// Outputs
	wire CS_DAC;
	wire CS_switch1;
	wire CS_switch2;
	wire CS_switch3;
	wire CS_switch4;
	wire CS_switch5;
	wire CS_switch6;
	
	reg BUSY_ADC;
	reg DoutA_ADC;
	reg DoutB_ADC;
	wire SCLK_ADC;
	wire CNVST_ADC;
	wire CS_ADC;

	wire [7:0] LED;
	reg [7:0] hi_in;
	wire [1:0] hi_out;
	wire [15:0] hi_inout;
	wire hi_aa;
	wire i2c_sda;
	wire i2c_scl;
	wire hi_muxsel;

	// Instantiate the Unit Under Test (UUT)
	TOP uut (
		.CLK(CLK), 
		
		.CS_DAC(CS_DAC), 
		.CS_switch1(CS_switch1), 
		.CS_switch2(CS_switch2), 
		.CS_switch3(CS_switch3), 
		.CS_switch4(CS_switch4), 
		.CS_switch5(CS_switch5), 
		.CS_switch6(CS_switch6), 
		
		.SCLK_ADC(SCLK_ADC), 
		.CNVST_ADC(CNVST_ADC), 
		.CS_ADC(CS_ADC), 
		.BUSY_ADC(BUSY_ADC), 
		.DoutA_ADC(DoutA_ADC), 
		.DoutB_ADC(DoutB_ADC), 
		
		.LED(LED), 
		.hi_in(hi_in), 
		.hi_out(hi_out), 
		.hi_inout(hi_inout), 
		.hi_aa(hi_aa), 
		.i2c_sda(i2c_sda), 
		.i2c_scl(i2c_scl), 
		.hi_muxsel(hi_muxsel)
	);

	initial begin
		// Initialize Inputs
		CLK = 0;
		BUSY_ADC = 0;
		DoutA_ADC = 0;
		DoutB_ADC = 0;
		hi_in = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
	
	// Clock
	always begin
		clk = 1;
		#5 clk = 0;
	end
	
	// ADC Behaviour
	always @(negedge CNVST) begin
		#40 BUSY = 1;
		#700 BUSY = 0;
	end
	
	always @(negedge SCLK) begin
		#20
		DoutA_ADC <= $random;
		DoutB_ADC <= $random;
	end
      
endmodule

