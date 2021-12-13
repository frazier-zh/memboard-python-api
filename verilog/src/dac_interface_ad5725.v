`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:39:17 12/05/2021 
// Design Name: 
// Module Name:    dac_interface_ad5725 
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
module dac_interface_ad5725(
    output reg [1:0] AD,
    output reg [11:0] DB,
    output reg RW,
    output reg LDAC,
    output reg CS,
    output reg CLR,
	 
    input clk,
	 input cs,
	 output reg rdy,
	 input [3:0] op,
    input [7:0] addr,
    input [15:0] data_in
    );

// Arguments
reg en = 0, rst = 0;
reg [1:0] channel;
reg [11:0] data_buffer;

always @(posedge clk)
	if (cs == 1) begin
		rst <= op[0];
		en <= op[1];
		channel <= addr[1:0];
		data_buffer <= data_in[11:0];
	end else begin
		rst <= 0;
		en <= 0;
	end
	
// FSM basic
localparam
	s_reset =	4'b0001,
	s_clear =	4'b0010,
	s_idle =		4'b0100,
	s_set =		4'b1000;
reg [5:0] state;
reg [7:0] time_count;
reg time_enable;

// FSM logic
localparam
	t_clear = 2;

always @(posedge clk) begin
	if (rst) begin
		state <= s_reset;
		CS <= 1;
		RW <= 1;
		LDAC <= 1;
		CLR <= 1;
		rdy <= 0;
		time_count <= 8'b0;
		time_enable <= 0;
	end else begin
		if (time_enable) begin
			time_count <= time_count + 1;
		end else begin
			time_count <= 0;
		end
	
		case (state)
			s_reset:
				if (~rst) begin
					state <= s_clear;
					CLR <= 0;
					time_enable <= 1;
				end else begin
					state <= s_reset;
				end
				
			s_clear:
				if (time_count == t_clear) begin
					state <= s_idle;
					CLR <= 1;
					rdy <= 1;
					time_enable <= 0;
				end else begin
					state <= s_clear;
				end
				
			s_idle:
				if (en == 1) begin
					state <= s_set;
					rdy <= 0;
					time_enable <= 1;
				end else begin
					state <= s_idle;
				end
				
			s_set:
				case (time_count)
					1: begin
							RW <= 0;
							LDAC <= 0;
							AD <= channel;
							DB <= data_buffer;
						end
					2: CS <= 0;
					4: CS <= 1;
					5: begin
							state <= s_idle;
							RW <= 1;
							LDAC <= 1;
							rdy <= 1;
							time_enable <= 0;
						end
				endcase
		endcase
	end
end

endmodule
