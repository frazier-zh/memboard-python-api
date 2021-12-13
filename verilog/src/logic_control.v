`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:34:09 12/09/2021 
// Design Name: 
// Module Name:    logic_control 
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
module logic_control(
    input clk,
	 input en,
	 input rst,
	 output reg rdy,
	 
	 // Memory block
	 output reg mblock_en,
	 output reg mblock_clr,
	 input mblock_valid,
    input [3:0] dev_no,
	 input [15:0] data_bus,
	 
	 // Result output
	 output reg data_out_en,
    output reg [15:0] data_out,
	 
	 // Device
	 output reg switch_cs,
	 output reg adc_cs,
	 output reg dac_cs,
	 output reg timer_cs,
	 output reg clock_cs,
	 input switch_rdy,
	 input adc_rdy,
	 input dac_rdy,
	 input timer_rdy,
	 input clock_rdy,
	 
	 input [13:0] adc_out,
	 
	 // Clock
	 input clock_cd,
	 output reg clock_en,
	 output reg clock_clr
    );

reg [7:0] time_count;
reg time_enable;

always @(posedge clk or posedge rst)
	if (rst) begin
		time_count <= 0;
	end else if (time_enable) begin
		time_count <= time_count + 1;
	end else begin
		time_count <= 0;
	end
	
localparam
	s_idle = 0,
	s_read = 1,
	s_call = 2,
	s_wait = 3,
	s_out_adc = 4,
	s_standby = 5;
reg [3:0] state;

always @(posedge clk) begin
	if (rst) begin
		state <= s_idle;
		mblock_clr <= 1;
		clock_clr <= 1;
		rdy <= 0;
	end else begin
		case (state)
			s_idle:
				if (en == 1) begin
					state <= s_read;
					clock_en <= 1;
					mblock_clr <= 0;
					clock_clr <= 0;
					rdy <= 0;
				end else begin
					state <= s_idle;
				end
				
			s_read:
				if (mblock_valid == 1) begin
					state <= s_call;
					mblock_en <= 1;
					time_enable <= 1;
				end else begin
					state <= s_standby;
					rdy <= 1;
				end
			
			s_call:
				case (time_count)
					1: mblock_en <= 0;
					2: case (dev_no)
							0: begin
									state <= s_read;
									time_enable <= 0;
								end
							1: adc_cs <= 1;
							2: dac_cs <= 1;
							3: switch_cs <= 1;
							4: timer_cs <= 1;
							6: clock_cs <= 1;
						endcase
					3: {adc_cs, dac_cs, switch_cs, timer_cs, clock_cs} <= 5'b0;
					4: begin
							state <= s_wait;
							time_enable <= 0;
						end
				endcase
				
			s_wait:
				if ({adc_rdy, dac_rdy, switch_rdy, timer_rdy, clock_rdy} == 5'b1111) begin
					if (dev_no == 1) begin
						state <= s_out_adc;
						time_enable <= 1;
					end else begin
						state <= s_read;
					end
				end else begin
					state <= s_wait;
				end
				
			s_out_adc:
				case (time_count)
					1: begin
							data_out <= {2'b0, adc_out};
							data_out_en <= 1;
						end
					2: begin
							state <= s_read;
							data_out_en <= 0;
							time_enable <= 0;
						end
				endcase
				
			s_standby:
				if (en == 0) begin
					state <= s_idle;
					mblock_clr <= 1;
					clock_clr <= 1;
				end else begin
					if (clock_cd) begin
						state <= s_idle;
						mblock_clr <= 1;
					end else begin
						state <= s_standby;
					end
				end
		endcase
	end
end

endmodule
