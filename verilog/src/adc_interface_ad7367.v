`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:04:08 02/09/2020 
// Design Name: 
// Module Name:    adc_interface_ad7366 
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
module adc_interface_ad7367(
	input BUSY,
	output reg SCLK,
	output reg CNVST,
	output reg CS,
	input DOUTA,
	input DOUTB,
	
	input clk,
	input cs,
	output reg rdy,
	output reg [3:0] state,
	
	input [3:0] op,
	input [7:0] addr,
	output [13:0] data_out
	);

// Arguments
wire en, rst;
assign rst = cs ? op[0] : 0;
assign en = cs ? op[1] : 0;

reg channel = 0;
reg [13:0] out_a = 0, out_b = 0;
assign data_out = ~channel ? out_a : out_b;

always @(posedge clk)
	if (cs == 1) begin
		channel <= addr[0];
	end

// FSM basic
localparam
	s_idle =	0,
	s_start = 2,
	s_busy =	5,
	s_read =	6,
	s_wait = 3;
reg [7:0] time_count = 0;
reg [7:0] data_count = 0;
reg time_enable = 0;

localparam
	t1 = 2,
	t2 = 4,
	t_quiet = 3,
	nbit = 14;

always @(posedge clk) begin
	if (rst) begin
		state <= s_idle;
		CS <= 1;
		CNVST <= 1;
		rdy <= 0;
		time_count <= 0;
		time_enable <= 0;
	end else begin
		if (time_enable) begin
			time_count <= time_count + 1;
		end else begin
			time_count <= 0;
		end
		
		// SCLK and ADC DOUT read
		if (~CS) begin
			case (time_count)
				0: begin
					SCLK <= 1;
				end
				2: begin
					SCLK <= 0;
					
					data_count <= data_count + 1;
					out_a <= {out_a[12:0], DOUTA};
					out_b <= {out_b[12:0], DOUTB};
				end
				3: time_count <= 0;
			endcase
		end else begin
			data_count <= 0;
			SCLK <= 1;
		end
	
		// FSM
		case (state)
			s_idle:
				if (en == 1) begin
					state <= s_start;
					rdy <= 0;
					CNVST <= 0;
					time_enable <= 1;
				end else begin
					state <= s_idle;
					rdy <= 1;
				end
				
			s_start:
				if (time_count == t1) begin
					state <= s_busy;
					CNVST <= 1;
					time_count <= 0;
				end else begin
					state <= s_start;
				end
				
			s_busy:
				if ((time_count < t2) || (BUSY == 1)) begin
					state <= s_busy;
				end else begin
					state <= s_read;
					CS <= 0;
					time_count <= 0;
				end
				
			s_read:
				if (data_count == nbit) begin
					state <= s_wait;
					CS <= 1;
					time_count <= 0;
				end else begin
					state <= s_read;
				end
				
			s_wait:
				if (time_count == t_quiet) begin
					state <= s_idle;
					time_enable <= 0;
					rdy <= 1;
				end else begin
					state <= s_wait;
				end
		endcase
	end
end

endmodule
