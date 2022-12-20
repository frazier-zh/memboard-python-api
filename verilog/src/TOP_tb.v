`timescale 1ns / 1ps
`default_nettype wire

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   11:55:46 08/01/2022
// Design Name:   TOP
// Module Name:   C:/Users/zjyyf/Desktop/FPGA/memboard-python-api/verilog/src/Top_tb.v
// Project Name:  memory_board
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

module Top_tb;

	// Inputs
	reg BUSY_ADC;
	reg DOUTA_ADC;
	reg DOUTB_ADC;
	reg CLK0;
	reg CLK1;
	reg [7:0] hi_in;

	// Outputs
	wire [1:0] AD_DAC;
	wire RW_DAC;
	wire LDAC_DAC;
	wire CS_DAC;
	wire CLR_DAC;
	wire RESET_SW1;
	wire CS_SW1;
	wire [3:0] AX_SW1;
	wire [2:0] AY_SW1;
	wire STROBE_SW1;
	wire DATA_SW1;
	wire RESET_SW2;
	wire CS_SW2;
	wire [3:0] AX_SW2;
	wire [2:0] AY_SW2;
	wire STROBE_SW2;
	wire DATA_SW2;
	wire RESET_SW3;
	wire CS_SW3;
	wire [3:0] AX_SW3;
	wire [2:0] AY_SW3;
	wire STROBE_SW3;
	wire DATA_SW3;
	wire RESET_SW4;
	wire CS_SW4;
	wire [3:0] AX_SW4;
	wire [2:0] AY_SW4;
	wire STROBE_SW4;
	wire DATA_SW4;
	wire RESET_SW5;
	wire CS_SW5;
	wire [3:0] AX_SW5;
	wire [2:0] AY_SW5;
	wire STROBE_SW5;
	wire DATA_SW5;
	wire RESET_SW6;
	wire CS_SW6;
	wire [3:0] AX_SW6;
	wire [2:0] AY_SW6;
	wire STROBE_SW6;
	wire DATA_SW6;
	wire SCLK_ADC;
	wire CNVST_ADC;
	wire CS_ADC;
	wire ADDR_ADC;
	wire [7:0] LED;
	wire [1:0] hi_out;
	wire i2c_sda;
	wire i2c_scl;
	wire hi_muxsel;

	// Bidirs
	wire [11:0] DB_DAC;
	wire [15:0] hi_inout;
	wire hi_aa;

	// Instantiate the Unit Under Test (UUT)
	TOP uut (
		.DB_DAC(DB_DAC), 
		.AD_DAC(AD_DAC), 
		.RW_DAC(RW_DAC), 
		.LDAC_DAC(LDAC_DAC), 
		.CS_DAC(CS_DAC), 
		.CLR_DAC(CLR_DAC), 
		.RESET_SW1(RESET_SW1), 
		.CS_SW1(CS_SW1), 
		.AX_SW1(AX_SW1), 
		.AY_SW1(AY_SW1), 
		.STROBE_SW1(STROBE_SW1), 
		.DATA_SW1(DATA_SW1), 
		.RESET_SW2(RESET_SW2), 
		.CS_SW2(CS_SW2), 
		.AX_SW2(AX_SW2), 
		.AY_SW2(AY_SW2), 
		.STROBE_SW2(STROBE_SW2), 
		.DATA_SW2(DATA_SW2), 
		.RESET_SW3(RESET_SW3), 
		.CS_SW3(CS_SW3), 
		.AX_SW3(AX_SW3), 
		.AY_SW3(AY_SW3), 
		.STROBE_SW3(STROBE_SW3), 
		.DATA_SW3(DATA_SW3), 
		.RESET_SW4(RESET_SW4), 
		.CS_SW4(CS_SW4), 
		.AX_SW4(AX_SW4), 
		.AY_SW4(AY_SW4), 
		.STROBE_SW4(STROBE_SW4), 
		.DATA_SW4(DATA_SW4), 
		.RESET_SW5(RESET_SW5), 
		.CS_SW5(CS_SW5), 
		.AX_SW5(AX_SW5), 
		.AY_SW5(AY_SW5), 
		.STROBE_SW5(STROBE_SW5), 
		.DATA_SW5(DATA_SW5), 
		.RESET_SW6(RESET_SW6), 
		.CS_SW6(CS_SW6), 
		.AX_SW6(AX_SW6), 
		.AY_SW6(AY_SW6), 
		.STROBE_SW6(STROBE_SW6), 
		.DATA_SW6(DATA_SW6), 
		.SCLK_ADC(SCLK_ADC), 
		.CNVST_ADC(CNVST_ADC), 
		.CS_ADC(CS_ADC), 
		.BUSY_ADC(BUSY_ADC), 
		.ADDR_ADC(ADDR_ADC), 
		.DOUTA_ADC(DOUTA_ADC), 
		.DOUTB_ADC(DOUTB_ADC), 
		.CLK0(CLK0), 
		.CLK1(CLK1), 
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
    parameter BlockDelayStates = 5;     // REQUIRED: # of clocks between blocks of pipe data
	parameter ReadyCheckDelay = 5;      // REQUIRED: # of clocks before block transfer before
                                        //           host interface checks for ready (0-255)
	parameter PostReadyDelay = 5;       // REQUIRED: # of clocks after ready is asserted and
                                        //           check that the block transfer begins (0-255)

	parameter pipeInSize = 16;          // REQUIRED: byte (must be even) length of default
                                        //           PipeIn; Integer 0-2^32
	parameter pipeOutSize = 16;	        // REQUIRED: byte (must be even) length of default
                                        //           PipeOut; Integer 0-2^32

	integer k;
	reg  [7:0]  pipeIn [0:(pipeInSize-1)];
	initial for (k=0; k<pipeInSize; k=k+1) pipeIn[k] = 8'h00;

	reg  [7:0]  pipeOut [0:(pipeOutSize-1)];
	initial for (k=0; k<pipeOutSize; k=k+1) pipeOut[k] = 8'h00;

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

    localparam [2:0] OP_NULL        = 3'b000;       // Null Operation
    localparam [2:0] OP_SETSR       = 3'b001;       // Set  SR[IREG]=DATA
    localparam [2:0] OP_LDSR        = 3'b010;       // Load SR[IREG]<-DATA
    localparam [2:0] OP_MUX         = 3'b011;       // Call MUX {DATA, 0}
    localparam [2:0] OP_MUXE        = 3'b100;       // Call MUX {DATA, SR[IREG]}
    localparam [2:0] OP_WAIT        = 3'b101;       // Wait SR[IREG]
    localparam [2:0] OP_LDREG       = 3'b110;       // Load Reg[DATA]<-SR[IREG]
    localparam [2:0] OP_RDREG       = 3'b111;       // Read Reg[DATA]

    //-------------------//

    integer f;
	
	// Clock 0, frequency 100MHz
	initial CLK0 = 1;	
	always #5 CLK0 = ~CLK0;
    // Clock 1, frequency 1MHz
    initial CLK1 = 1;
    always #500 CLK1 = ~CLK1;
	
	// ADC Behaviour
	always @(negedge CNVST_ADC) begin
		#40 BUSY_ADC = 1;
		#720 BUSY_ADC = 0;
	end
	
	always @(negedge SCLK_ADC or negedge BUSY_ADC) begin
		#20
		DOUTA_ADC <= $random;
		DOUTB_ADC <= $random;
	end

	initial begin
		FrontPanelReset;
        
		// Reset
        ActivateTriggerIn(8'h40, 0);
        
        /*
        // Write/Read register
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h2});
        WriteToPipeInSingle(8'h80, {OP_LDSR,  1'b0, 12'h710});
        WriteToPipeInSingle(8'h80, {OP_LDREG, 1'b0, 12'h0});
        WriteToPipeInSingle(8'h80, {OP_RDREG, 1'b0, 12'h0});
        WriteToPipeInSingle(8'h80, {OP_RDREG, 1'b0, 12'h1});
        */
        
        // Device Reset
        WriteToPipeInSingle(8'h80, {OP_MUX,   1'b1, 8'h40, 4'b1000}); // ADC-ALL-Reset
        WriteToPipeInSingle(8'h80, {OP_MUX,   1'b1, 8'h50, 4'b1000}); // DAC-ALL-Reset
        WriteToPipeInSingle(8'h80, {OP_MUX,   1'b1, 8'h60, 4'b1000}); // SW-ALL-Reset
        
        /*
        // ADC/DAC/SW Enable
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b1, 12'h100}); // SW0-Enable-X0-Y0-On
        WriteToPipeInSingle(8'h80, {OP_MUXE,  1'b1, 8'h20, 4'b0000});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b1, 12'h112}); // SW5-Enable-X2-Y1-On
        WriteToPipeInSingle(8'h80, {OP_MUXE,  1'b1, 8'h25, 4'b0000});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b1, 12'hA23}); // DAC0-Enable-CH2-0xA23
        WriteToPipeInSingle(8'h80, {OP_MUXE,  1'b1, 8'h10, 4'b0010});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h020}); // Wait-20
        WriteToPipeInSingle(8'h80, {OP_WAIT,  1'b0, 12'h0});
        
        WriteToPipeInSingle(8'h80, {OP_MUX,   1'b1, 8'h00, 4'b0000}); // ADC0-Enable
        */
        
        // ADC Auto, Pipe Read
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h0C8}); // ADC Frequency 500kHz
        WriteToPipeInSingle(8'h80, {OP_LDREG, 1'b0, 12'h000});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h001}); // ADC ADDR=1
        WriteToPipeInSingle(8'h80, {OP_LDREG, 1'b0, 12'h003});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h001}); // ADC Auto=on
        WriteToPipeInSingle(8'h80, {OP_LDREG, 1'b0, 12'h002});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h3E8}); // Wait-10000
        WriteToPipeInSingle(8'h80, {OP_WAIT,  1'b0, 12'h0});
        
        WriteToPipeInSingle(8'h80, {OP_SETSR, 1'b0, 12'h000}); // ADC Auto=off
        WriteToPipeInSingle(8'h80, {OP_LDREG, 1'b0, 12'h002});
        
        #20000
        ReadFromPipeOut(8'hA0, 16);
        
        for (k=0; k<pipeOutSize; k=k+1)
            $display("%H", pipeOut[k]);
    end
      
	`include "./oksim/okHostCalls.v"   // Do not remove!  The tasks, functions, and data stored
	                                   // in okHostCalls.v must be included here.

endmodule

