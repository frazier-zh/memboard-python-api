`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:05:15 12/12/2021 
// Design Name: 
// Module Name:    multiclock_interface 
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
module multiclock_interface(
    input clk,
	 input rst,
	 
	 // Cross clock domain input
	 input ti_clk,
	 input data_write,
	 input [15:0] data_in,
	 input en,
	 output cd,
	 
	 // Clock time output
	 input cs,
	 input clr,
	 output [47:0] data_out,
	 output reg rdy
    );
	
reg [47:0] counter_data;
wire clock_en;
assign clock_en = ~clr;

always @(posedge ti_clk)
	if (data_write == 1) begin
		counter_data <= {counter_data[31:0], data_in};
	end

reg [7:0] time_count;
reg time_enable;

always @(posedge clk)
	if (time_enable) begin
		time_count <= time_count + 1;
	end else begin
		time_count <= 0;
	end
	
always @(posedge clk)
	if (cs == 1) begin
		rdy <= 0;
		time_enable <= 1;
	end else if (time_enable == 1) begin
		case (time_count)
			1: begin
					data_out_en <= 1;
					data_out <= clock_data[15:0];
				end
			2: data_out <= clock_data[31:16];
			3: data_out <= clock_data[47:32];
			4: begin
					time_enable <= 0;
					data_out_en <= 0;
					rdy <= 1;
				end
		endcase
	end

BC_DOWN_48b counter(
	.clk(clk),
	.load(en),
	.l(counter_data),
	.thresh0(cd),
	.q()
);

BC_UP_48b clock(
	.clk(clk),
	.ce(clock_en),
	.sclr(clr),
	.q(data_out)
);

endmodule
