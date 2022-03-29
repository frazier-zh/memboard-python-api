`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:41:13 03/15/2022 
// Design Name: 
// Module Name:    logic 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

// Constants
`define RESET_ENABLE 1
`define RESET_DISABLE 0
`define RESET_EDGE posedge
`define ENABLE 1
`define DISABLE 0

`define ISA_OP_LOC 7:0
`define ISA_OP_BUS 7:0
`define ISA_DATA_LOC 31:8
`define ISA_DATA_BUS 23:0
`define ISA_ADDR_LOC 19:8

`define ENTRY_VECTOR 12'h010
`define RESET_VECTOR 12'h000

`define ISA_W 32
`define ISA_BUS 31:0
`define ADDR_W 12
`define ADDR_BUS 11:0

`define STACK_BUS 4:0

`define ISA_NOP 32'b0
`define ISA_OP_JMP 8'h01
`define ISA_OP_JMPE 8'h02
`define ISA_OP_CALL 8'h03
`define ISA_OP_RET 8'h04
`define ISA_OP_HOLD 8'h05
`define ISA_OP_LOOP 8'h06
`define ISA_OP_CLRC 8'h07

`define ALU_OP_ADD 8'h10
`define ALU_OP_SUB 8'h11
`define ALU_OP_AND 8'h12
`define ALU_OP_OR 8'h13
`define ALU_OP_XOR 8'h14

`define EXT_OP_ADC 8'h20
`define EXT_OP_DAC 8'h21
`define EXT_OP_SWI 8'h22
`define EXT_OP_CLR 8'h23

`define EXT_ADC_ENABLE 3'b001
`define EXT_DAC_ENABLE 3'b010
`define EXT_SWI_ENABLE 3'b100
`define EXT_DISABLE 3'b0

module MC(
	input clk,
	input rst,
	input en,

	input prog_en,
	input direct,
	
	input din_empty,
	output reg din_wr,
	input [`ISA_BUS] din,
	
	output reg [2:0] ext_cs,
	
	output reg clk_en,
	output reg clk_clr,
	input [`ISA_DATA_BUS] clk_data
	);

reg [`ADDR_BUS] wr_addr = 0;
reg [`ADDR_BUS] if_pc = 0;

BRAM_32b_4k ProgMem(
	.clka(clk),
	.wea(din_wr),
	.addra(wr_addr),
	.dina(din),
	.clkb(),
	.addrb(if_pc),
	.doutb(mem_insn),
	.sbiter(),
	.dbiterr(),
	.rdipecc()
);

// Instruction dispatcher
// Flags and controls
reg stall = 0;

reg [`ISA_BUS] insn = 0;
reg [`ISA_BUS] if_insn = 0;

// Memory programming
reg [`ADDR_BUS] max_addr = 0;
always @(*) begin
	if ((prog_en == `ENABLE) && (din_empty == `DISABLE)) begin
		din_wr = `ENABLE;
	end else if ((direct == `ENABLE) && (~stall)) begin
		din_wr = `ENABLE;
	end else begin
		din_wr = `DISABLE;
	end
	// direct
	if (direct == `ENABLE) begin
		insn = din;
	end else begin
		insn = mem_insn;
	end
end
always @(posedge clk or `RESET_EDGE rst) begin
	if (rst == `RESET_ENABLE) begin
		wr_addr <= 0;
	end else if (din_wr == `ENABLE) begin
		wr_addr <= max_addr;
		max_addr <= max_addr+1;
	end
end

// Memory reading
reg if_en = 0;
reg br_taken = 0;
reg [`ADDR_BUS] br_addr = 0;
reg [`ADDR_BUS] ret_addr = 0;
reg ret = 0;
always @(posedge clk or `RESET_EDGE rst) begin
	if (rst == `RESET_ENABLE) begin
		if_pc <= `RESET_VECTOR;
		if_insn <= `ISA_NOP;
		if_en <= `DISABLE;
	end else if ((en == `ENABLE) && (stall == `DISABLE)) begin
		if (br_taken == `ENABLE) begin
			if_pc <= br_addr;
			if_insn <= insn;
			if_en <= `ENABLE;
		end else begin
			if (if_pc < wr_addr) begin
				if_pc <= if_pc+1;
				if_insn <= insn;
				if_en <= `ENABLE;
			end else
				if_en <= `DISABLE;
		end
	end
end

wire [`ISA_OP_BUS] op = if_insn[`ISA_OP_LOC];
wire [`ADDR_BUS] jr_target = if_insn[`ISA_ADDR_LOC];
wire [`ISA_DATA_BUS] data = if_insn[`ISA_DATA_LOC];

// ALU
always @(*) begin
	if (alu_en) begin
		case (op)
			`ALU_OP_SUB: begin
				alu_out = alu_in0 - alu_in1;
			end
			default: begin
				alu_out = alu_in0;
			end
		endcase
	end
end

// Instruction decoding
always @(*) begin
	br_addr = `RESET_VECTOR;
	br_taken = `DISABLE;
	ext_cs = `EXT_DISABLE;
	clk_clr = `DISABLE;
	
	if (if_en) begin
		case (op)
			`ISA_OP_JMP: begin
				br_addr = jr_target;
				br_taken = `ENABLE;
			end
			`ISA_OP_JMPE: begin
				
			end
			`ISA_OP_CALL: begin
//				br_addr = jr_target;
//				br_taken = `ENABLE;
//				ret = `ENABLE;
			end
			`ISA_OP_RET: begin
//				br_addr = ret_addr;
//				br_taken = `ENABLE;
//				ret = `DISABLE;
			end
			`ISA_OP_HOLD: begin
				stall = (clk_data >= data) ? `ENABLE : `DISABLE;
			end
			`ISA_OP_LOOP: begin
				br_addr = `ENTRY_VECTOR;
				br_taken = loop_end ? `ENABLE : `DISABLE;
				loop_en = `ENABLE;
			end
			`ISA_OP_CLRC: begin
				clk_clr = `ENABLE;
			end
			`EXT_OP_ADC: begin
				ext_cs = `EXT_ADC_ENABLE;
			end
			`EXT_OP_DAC: begin
				ext_cs = `EXT_DAC_ENABLE;
			end
			`EXT_OP_SWI: begin
				ext_cs = `EXT_SWI_ENABLE;
			end
		endcase
	end
end

endmodule
