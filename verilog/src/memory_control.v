`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:11:27 12/11/2021 
// Design Name: 
// Module Name:    memroy_control 
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
module memory_control(
    input clk,
	 
	 input din_empty,
	 output din_read,
    input [31:0] din,
	 
	 input dout_read,
    output [31:0] dout,
	 
	 input rst,
	 input zero,
	 output reg valid
    );

wire wr_en;
reg wr_wait;
reg [9:0] rd_addr = 0;
reg [9:0] wr_addr = 0;

assign din_read = ~din_empty;
assign wr_en = din_read;

BLK_MEM_32b_1k blk_mem(
	 .clka(clk),
    .wea(wr_en),
    .addra(wr_addr),
    .dina(din),
    .clkb(clk),
    .addrb(rd_addr),
    .doutb(dout)
);

always @(posedge clk) begin
	if (rst) begin
		wr_addr <= 0;
		rd_addr <= 0;
		valid <= 0;
	end else begin
		if (zero) begin
			rd_addr <= 0;
			if (wr_addr > 0)
				valid <= 1;
			else
				valid <= 0;
		end else if (dout_read && valid) begin
			rd_addr <= rd_addr+1;
			if (rd_addr+1 == wr_addr)
				valid <= 0;
		end

		if (wr_en)
			wr_addr <= wr_addr+1;

		wr_wait <= wr_en;
		if (wr_wait)
			valid <= 1;		
	end
end

endmodule
