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

module top_tb;
	// Inputs
	reg CLK;
	
	// Outputs
	wire CS_DAC;
	wire CS_SW1;
	wire CS_SW2;
	wire CS_SW3;
	wire CS_SW4;
	wire CS_SW5;
	wire CS_SW6;
	
	reg BUSY_ADC;
	reg DOUTA_ADC;
	reg DOUTB_ADC;
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
		.CS_SW1(CS_SW1), 
		.CS_SW2(CS_SW2), 
		.CS_SW3(CS_SW3), 
		.CS_SW4(CS_SW4), 
		.CS_SW5(CS_SW5), 
		.CS_SW6(CS_SW6), 
		
		.SCLK_ADC(SCLK_ADC), 
		.CNVST_ADC(CNVST_ADC), 
		.CS_ADC(CS_ADC), 
		.BUSY_ADC(BUSY_ADC), 
		.DOUTA_ADC(DOUTA_ADC), 
		.DOUTB_ADC(DOUTB_ADC), 
		
		.LED(LED), 
		.hi_in(hi_in), 
		.hi_out(hi_out), 
		.hi_inout(hi_inout), 
		.hi_aa(hi_aa), 
		.i2c_sda(i2c_sda), 
		.i2c_scl(i2c_scl), 
		.hi_muxsel(hi_muxsel)
	);

	//------------------------------------------------------------------------
	// Begin okHostInterface simulation user configurable  global data
	//------------------------------------------------------------------------
	parameter BlockDelayStates = 5;   // REQUIRED: # of clocks between blocks of pipe data
	parameter ReadyCheckDelay = 5;    // REQUIRED: # of clocks before block transfer before
	                                  //           host interface checks for ready (0-255)
	parameter PostReadyDelay = 5;     // REQUIRED: # of clocks after ready is asserted and
	                                  //           check that the block transfer begins (0-255)
	parameter pipeInSize = 88;        // REQUIRED: byte (must be even) length of default
	                                  //           PipeIn; Integer 0-2^32
	parameter pipeOutSize = 20;       // REQUIRED: byte (must be even) length of default
	                                  //           PipeOut; Integer 0-2^32
	parameter pipeIn2Size = 6;

	integer k;
	reg  [7:0]  pipeIn [0:(pipeInSize-1)];
	initial for (k=0; k<pipeInSize; k=k+1) pipeIn[k] = 8'h00;

	reg  [7:0]  pipeOut [0:(pipeOutSize-1)];
	initial for (k=0; k<pipeOutSize; k=k+1) pipeOut[k] = 8'h00;

	reg  [7:0]  pipeIn2 [0:(pipeIn2Size-1)];
	initial for (k=0; k<pipeIn2Size; k=k+1) pipeIn2[k] = 8'h00;

	//------------------------------------------------------------------------
	//  Available User Task and Function Calls:
	//    FrontPanelReset;                  // Always start routine with FrontPanelReset;
	//    SetWireInValue(ep, val, mask);
	//    UpdateWireIns;
	//    UpdateWireOuts;
	//    GetWireOutValue(ep);
	//    ActivateTriggerIn(ep, bit);       // bit is an integer 0-15
	//    UpdateTriggerOuts;
	//    IsTriggered(ep, mask);            // Returns a 1 or 0
	//    WriteToPipeIn(ep, length);        // passes pipeIn array data
	//    ReadFromPipeOut(ep, length);      // passes data to pipeOut array
	//    WriteToBlockPipeIn(ep, blockSize, length);    // pass pipeIn array data; blockSize and length are integers
	//    ReadFromBlockPipeOut(ep, blockSize, length);  // pass data to pipeOut array; blockSize and length are integers
	//
	//    *Pipes operate by passing arrays of data back and forth to the user's
	//    design.  If you need multiple arrays, you can create a new procedure
	//    above and connect it to a differnet array.  More information is
	//    available in Opal Kelly documentation and online support tutorial.
	//------------------------------------------------------------------------

	integer f;

	initial begin
		FrontPanelReset;

		ActivateTriggerIn(8'h40, 0);
		ActivateTriggerIn(8'h40, 1);
		ActivateTriggerIn(8'h40, 2);

		$readmemh("../../scan.mem1", pipeIn);
		$readmemh("../../scan.mem2", pipeIn2);
		WriteToPipeIn2(8'h81, pipeIn2Size);
		WriteToPipeIn(8'h80, pipeInSize);

		SetWireInValue(8'h00, 1, 16'hffff);
		UpdateWireIns;

		// Start execution
		#20000
		ReadFromPipeOut(8'hA0, pipeOutSize);

		f = $fopen("../../scan.out", "w");
		for (k=0; k<pipeOutSize; k=k+1)
			$fwrite(f, "%02x\n", pipeOut[k]);
		$fclose(f);
	end
	
	// Clock
	always begin
		CLK = 1;
		#5 CLK = 0;
	end
	
	// ADC Behaviour
	always @(negedge CNVST_ADC) begin
		#40 BUSY_ADC = 1;
		#700 BUSY_ADC = 0;
	end
	
	always @(negedge SCLK_ADC) begin
		#20
		DOUTA_ADC <= $random;
		DOUTB_ADC <= $random;
	end

	`include "./oksim/okHostCalls.v"   // Do not remove!  The tasks, functions, and data stored
	                                   // in okHostCalls.v must be included here.

endmodule

