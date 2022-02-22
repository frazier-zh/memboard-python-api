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
	 output reg [3:0] state,
	 
	 input en,
	 input auto_en,
	 output reg [15:0] auto_count,
	 
	 // Memory block
	 output reg mem_read,
	 output reg mem_zero,
	 input mem_valid,
	 input [31:0] mem_in,
	 output reg [31:0] main_bus,

	 output reg [7:0] dev_cs,
	 input [7:0] dev_rdy,
	 
	 // Result output
	 output reg data_write,
    output reg [15:0] data_out,
	 
	 // Device
	 input [13:0] adc_out,
	 input [47:0] time_out,
	 
	 // Clock
	 output reg cd_en,
	 input cd_rdy,
	 output reg clock_clr
    );

wire [3:0] dev_no;
wire dev_rst;
assign dev_no = main_bus[3:0];
assign dev_rst = main_bus[4];

reg [7:0] time_count;
reg time_enable;
	
localparam
	s_idle = 0,
	s_wait = 3,
	s_start = 2,
	s_busy = 5,
	s_read = 6,
	s_read2 = 7,
	s_clear = 4;

always @(posedge clk) begin
	if (rst) begin
		state <= s_idle;
		mem_read <= 0;
		mem_zero <= 1;
		data_write <= 0;
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
				if (en && mem_valid) begin
					clock_clr <= 0;
					if (auto_en) begin
						state <= s_clear;
						cd_en <= 1;
						mem_zero <= 1;
					end else begin
						state <= s_wait;
						mem_zero <= 0;
					end
				end else
					state <= s_idle;
				
			s_wait:
				if (en && mem_valid) begin
					mem_read <= 1;
					if (mem_in == 31'b0) begin
						state <= s_wait;
					end begin
						state <= s_start;
						main_bus <= mem_in;
						time_enable <= 1;
					end
				end else if (en && auto_en) begin
					if (cd_rdy) begin
						state <= s_clear;
						auto_count <= auto_count+1;
						cd_en <= 1;
						mem_zero <= 1;
					end else
						state <= s_wait;
				end else
					state <= s_idle;
				
			s_clear: begin
				state <= s_wait;	
				cd_en <= 0;
				mem_zero <= 0;
			end
							
			s_start:
				case (time_count)
					0: begin
						dev_cs[dev_no] <= 1;
						mem_read <= 0;
					end
					1: begin
						dev_cs <= 0;
						state <= s_busy;
						time_enable <= 0;
					end
				endcase
				
			s_busy:
				if (dev_rdy[dev_no]) begin
					if (dev_no == 7) begin
						state <= s_read2;
						time_enable <= 1;
					end else if ((dev_no == 1) && (dev_rst == 0)) begin
						state <= s_read;
						time_enable <= 1;
					end else begin
						state <= s_wait;
					end
				end else begin
					state <= s_busy;
				end
				
			s_read:
				case (time_count)
					0: begin
						data_out <= {2'b0, adc_out};
						data_write <= 1;
					end
					1: begin
						state <= s_wait;
						data_write <= 0;
						time_enable <= 0;
					end
				endcase
				
			s_read2:
				case (time_count)
					0: begin
						data_out <= time_out[47:32];
						data_write <= 1;
					end
					1: data_out <= time_out[31:16];
					2: data_out <= time_out[15:0];
					3: begin
						state <= s_wait;
						data_write <= 0;
						time_enable <= 0;
					end
				endcase
		endcase
	end
end

endmodule
