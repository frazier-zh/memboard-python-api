`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:34:17 12/12/2021 
// Design Name: 
// Module Name:    timer 
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
module timer_interface(
    input clk,
	 input cs,
    output rdy,
    input [3:0] op,
    input [7:0] addr,
    input [15:0] data_in
    );

reg counter_load = 0;
reg [47:0] counter_data = 0;
assign rdy = counter_end;

always @(posedge clk)
	if (cs == 1) begin
		if (op[0] == 0) begin
			counter_data <= {24'b0, addr, data_in};
		end else begin
			counter_data <= {addr, data_in, 24'b0};
		end
		counter_load <= 1;
	end else begin
		counter_load <= 0;
	end

BC_DOWN_48b counter(
	.clk(clk),
	.load(counter_load),
	.l(counter_data),
	.thresh0(counter_end),
	.q()
);

endmodule
