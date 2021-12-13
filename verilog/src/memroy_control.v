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
	 
	 input fifo_empty,
	 output reg fifo_en,
    input [31:0] data_in,
    output [31:0] data_out,
	 
	 input rst,
	 input clr,
	 input rd_en,
	 output reg valid
    );

reg wr_en = 0;
reg [9:0] wr_addr = 0;
reg [9:0] rd_addr = 0;

BLK_MEM_32b_1k blk_mem(
	 .clka(clk),
    .wea(wr_en),
    .addra(wr_addr),
    .dina(data_in),
    .clkb(clk),
    .addrb(rd_addr),
    .doutb(data_out)
);

always @(posedge clk) begin
	if (fifo_empty == 0) begin
		if (fifo_en == 0) begin
			fifo_en <= 1;
		end else begin
			wr_en <= 1;
			wr_addr <= wr_addr + 1;
		end
	end else begin
		wr_en <= 0;
		fifo_en <= 0;
	end
end

always @(posedge rd_en)
	if (valid == 1)
		rd_addr <= rd_addr + 1;

always @*
	if (rd_addr == wr_addr) begin
		valid = 0;
	else
		valid = 1;
	end
	
always @(posedge clk) begin
	if (rst == 1) begin
		state <= s_empty;
		wr_addr <= 0;
		rd_addr <= 0;
	end else if (clr == 1) begin
		rd_addr <= 0;
	end
end

endmodule
