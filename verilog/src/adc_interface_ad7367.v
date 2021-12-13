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
	input [3:0] op,
	input [7:0] addr,
	output [13:0] data_out
	);

// Arguments
reg en = 0, rst = 0;
reg channel = 0;
reg [13:0] out_a, out_b;
assign data_out = ~channel?out_a:out_b;

always @(posedge clk)
	if (cs == 1) begin
		rst <= op[0];
		en <= op[1];
		channel <= addr[0];
	end else begin
		rst <= 0;
		en <= 0;
	end

// FSM basic
localparam
	s_idle =		5'b00001,
	s_start =	5'b00010,
	s_busy =		5'b00100,
	s_read =		5'b01000,
	s_quiet =	5'b10000;
reg [4:0] state;
reg [7:0] time_count;
reg [7:0] data_count;
reg time_enable;

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
		time_count <= 8'b0;
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
					state <= s_quiet;
					CS <= 1;
					time_count <= 0;
				end else begin
					state <= s_read;
				end
				
			s_quiet:
				if (time_count == t_quiet) begin
					state <= s_idle;
					time_enable <= 0;
					rdy <= 1;
				end else begin
					state <= s_quiet;
				end
		endcase
	end
end

endmodule
