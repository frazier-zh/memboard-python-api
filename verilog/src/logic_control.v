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
	 input rst,
	 output rdy,
	 
	 input en,
	 input auto_en,
	 output reg [15:0] auto_count,
	 
	 // Memory block
	 output reg mem_read,
	 output reg mem_zero,
	 input mem_valid,
    input [3:0] dev_no,
	 input dev_op_rst,
	 output reg [6:0] dev_cs,
	 input [6:0] dev_rdy,
	 
	 // Result output
	 output reg data_out_en,
    output reg [15:0] data_out,
	 
	 // Device
	 input [13:0] adc_out,
	 input [47:0] time_out,
	 
	 // Clock
	 output reg cd_en,
	 input cd_rdy,
	 output reg clock_clr
    );

reg [3:0] dev_no_s;
reg dev_op_rst_s;

reg [7:0] time_count;
reg time_enable;
	
localparam
	s_idle = 0,
	s_next = 1,
	s_call = 2,
	s_wait = 3,
	s_out_adc = 4,
	s_out_time = 5,
	s_restart = 6;
reg [3:0] state;
assign rdy = (state==s_idle);

always @(posedge clk) begin
	if (rst) begin
		state <= s_idle;
		mem_read <= 0;
		mem_zero <= 1;
		data_out_en <= 0;
		dev_cs <= 0;
		cd_en <= 0;
		clock_clr <= 1;
		auto_count <= 0;
	end else begin
		if (time_enable)
			time_count <= time_count + 1;
		else
			time_count <= 0;
			
		case (state)
			s_idle:
				if (en) begin
					clock_clr <= 0;
					if (auto_en) begin
						state <= s_restart;
						cd_en <= 0;
						mem_zero <= 1;
					end else
						state <= s_next;
				end else
					state <= s_idle;
				
			s_next:
				if (en && mem_valid) begin
					state <= s_call;
					
					mem_read <= 1;
					time_enable <= 1;
					dev_no_s <= dev_no;
					dev_op_rst_s <= dev_op_rst;
					case (dev_no)
						1,2,3,4,5,6: dev_cs <= 1<<dev_no;
					endcase
				end else if (auto_en && cd_rdy) begin
					state <= s_restart;
					auto_count <= auto_count+1;
					cd_en <= 0;
					mem_zero <= 1;
				end else
					state <= s_idle;
				
			s_restart: begin
				state <= s_next;	
				cd_en <= 1;
				mem_zero <= 0;
			end
							
			s_call:
				case (time_count)
					0: begin
						dev_cs <= 0;
						mem_read <= 0;
						if (dev_no_s == 0) begin
							state <= s_next;
							time_enable <= 0;
						end else if (dev_no_s == 7) begin
							state <= s_out_time;
							time_count <= 0;
						end
					end
					1: begin
						state <= s_wait;
						time_enable <= 0;
					end
				endcase
				
			s_wait:
				if (dev_rdy[dev_no_s]) begin
					if ((dev_no_s == 1) && (dev_op_rst_s == 0)) begin
						state <= s_out_adc;
						time_enable <= 1;
					end else begin
						state <= s_next;
					end
				end else begin
					state <= s_wait;
				end
				
			s_out_adc:
				case (time_count)
					0: begin
						data_out <= {2'b0, adc_out};
						data_out_en <= 1;
					end
					1: begin
						state <= s_next;
						data_out_en <= 0;
						time_enable <= 0;
					end
				endcase
				
			s_out_time:
				case (time_count)
					0: begin
						data_out <= time_out[15:0];
						data_out_en <= 1;
					end
					1: data_out <= time_out[31:16];
					2: data_out <= time_out[47:32];
					3: begin
						state <= s_next;
						data_out_en <= 0;
						time_enable <= 0;
					end
				endcase
		endcase
	end
end

endmodule
