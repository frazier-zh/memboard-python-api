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
	 output reg [3:0] state,
	 
	 input [3:0] op,
    input [7:0] addr,
    input [15:0] data_in
    );

// Arguments
wire en, rst;
assign rst = cs ? op[0] : 0;
assign en = cs ? op[1] : 0;

reg [1:0] channel = 0;
reg [11:0] data_buffer = 0;

always @(posedge clk)
	if (cs == 1) begin
		channel <= addr[1:0];
		data_buffer <= data_in[11:0];
	end 

// FSM basic
localparam
	s_reset = 1,
	s_clear = 4,
	s_idle =	0,
	s_start = 2;
reg [7:0] time_count = 0;
reg time_enable = 0;

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
					state <= s_start;
					rdy <= 0;
					time_enable <= 1;
				end else begin
					state <= s_idle;
				end
				
			s_start:
				case (time_count)
					0: begin
						RW <= 0;
						LDAC <= 0;
						AD <= channel;
						DB <= data_buffer;
					end
					1: CS <= 0;
					3: CS <= 1;
					4: begin
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
