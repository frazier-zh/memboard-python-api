`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:32:54 02/15/2022
// Design Name:   memory_control
// Module Name:   C:/Users/zjyyf/Desktop/FPGA/memboard-python-api/verilog/src/memory_control_tb.v
// Project Name:  memory_board
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: memory_control
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module memory_control_tb;

	// Inputs
	reg clk;
	reg din_empty;
	reg [31:0] din;
	reg dout_read;
	reg rst;
	reg zero;

	// Outputs
	wire din_read;
	wire [31:0] dout;
	wire valid;

	// Instantiate the Unit Under Test (UUT)
	memory_control uut (
		.clk(clk), 
		.din_empty(din_empty), 
		.din_read(din_read), 
		.din(din), 
		.dout_read(dout_read), 
		.dout(dout), 
		.rst(rst), 
		.zero(zero), 
		.valid(valid)
	);

	// Clock

	initial begin
		// Initialize Inputs
		clk = 1;
		din_empty = 1;
		din = 0;
		dout_read = 0;
		rst = 0;
		zero = 0;

		// Wait 100 ns for global reset to finish
		#1000;
        
		// Add stimulus here
		rst = 1;
		#10 rst = 0;
		
		#10;
		din_empty = 0;
		din = 1;
		#10;
		din = 2;
		#10;
		din = 3;
		#10;
		din_empty = 1;
	end
	
	always #5 clk = ~clk;
      
endmodule

