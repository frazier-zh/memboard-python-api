`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:04:49 03/18/2022
// Design Name:   MC
// Module Name:   C:/Users/zjyyf/Desktop/FPGA/memboard-python-api/verilog/mc/logic_test_memory.v
// Project Name:  memory_board
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: MC
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module logic_test_memory;

	// Inputs
	reg clk;
	reg rst;
	reg en;
	reg prog_en;
	reg direct;
	reg din_empty;
	reg [31:0] din;
	reg clk;

	// Outputs
	wire din_wr;
	wire [2:0] ext_cs;
	wire clk_en;
	wire clk_clr;

	// Instantiate the Unit Under Test (UUT)
	MC uut (
		.clk(clk), 
		.rst(rst), 
		.en(en), 
		.prog_en(prog_en), 
		.direct(direct), 
		.din_empty(din_empty), 
		.din_wr(din_wr), 
		.din(din), 
		.ext_cs(ext_cs), 
		.clk_en(clk_en), 
		.clk_clr(clk_clr), 
		.clk(clk)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		en = 0;
		prog_en = 0;
		direct = 0;
		din_empty = 0;
		din = 0;
		clk = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

