`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:54:00 12/06/2021 
// Design Name: 
// Module Name:    switch_interface_mt8816 
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

module switch_interface_group(
	output RESET_SW1,
	output CS_SW1,
	output RESET_SW2,
	output CS_SW2,
	
	input clk,
	input cs,
	output reg rdy,
	input [3:0] op,
	input [15:0] data_in,
	
	output reg [3:0] AX,
	output reg [2:0] AY,
	output reg STROBE,
	output reg DATA
);

reg en = 0, rst = 0;
reg sw_no;

// Arguments
always @(posedge clk)
	if (cs == 1) begin
		rst <= op[0];
		en <= op[1];
		
		sw_no <= data_in[4];
		AY <= data_in[10:8];
		DATA <= data_in[12];
		
		case (data_in[3:0])
			6,7,8,9,10,11: AX <= data_in[3:0]+2;
			12: AX <= 6;
			13: AX <= 7;
			default:
				AX <= data_in[3:0];
		endcase
	end else begin
		rst <= 0;
		en <= 0;
	end

reg [1:0] sw_rst = 0;
assign {RESET_SW2, RESET_SW1} = sw_rst;

reg [1:0] sw_cs = 0;
assign {CS_SW2, CS_SW1} = sw_cs;

// FSM basic
localparam
	s_reset =	5'b00001,
	s_clear =	5'b00010,
	s_wait =		5'b00100,
	s_idle =		5'b01000,
	s_start =	5'b10000;
reg [4:0] state;
reg [7:0] time_count;
reg time_enable;

// FSM logic
localparam
	t_reset = 6,
	t_delay = 1;

always @(posedge clk) begin
	if (rst) begin
		state <= s_reset;
		sw_rst <= 0;
		sw_cs <= 0;
		STROBE <= 0;
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
					sw_rst <= 1<<sw_no;
					time_enable <= 1;
				end else begin
					state <= s_reset;
				end
				
			s_clear:
				if (time_count == t_reset) begin
					state <= s_wait;
					sw_rst <= 0;
					time_count <= 0;
				end else begin
					state <= s_clear;
				end
				
			s_wait:
				if (time_count == t_delay) begin
					state <= s_idle;
					rdy <= 1;
					time_enable <= 0;
				end else begin
					state <= s_wait;
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
							sw_cs <= 1<<sw_no;
							AX <= AX;
							AY <= AY;
							DATA <= DATA;
						end
					2: STROBE <= 1;
					5: STROBE <= 0;
					7: begin
							state <= s_wait;
							time_count <= 0;
							sw_cs <= 0;
						end
				endcase
		endcase
	end
end

endmodule