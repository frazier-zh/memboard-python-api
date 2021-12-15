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
	 
	 input data_in_empty,
	 output data_read,
    input [31:0] data_in,
    output [31:0] data_out,
	 
	 input rst,
	 input zero,
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

assign data_read = ~data_in_empty;

always @*
	if (rd_addr == wr_addr+1)
		valid = 0;
	else
		valid = 1;

always @(posedge clk) begin
	if (rst == 1) begin
		wr_addr <= 0;
		rd_addr <= 1;
		wr_en <= 0;
	end else begin
		if (zero == 1) begin
			rd_addr <= 1;
		end
		
		if (data_read == 1) begin
			wr_en <= 1;
			wr_addr <= wr_addr + 1;
		end else begin
			wr_en <= 0;
		end
	
		if ((rd_en == 1) && (valid == 1))
			rd_addr <= rd_addr + 1;
	end
end

endmodule
