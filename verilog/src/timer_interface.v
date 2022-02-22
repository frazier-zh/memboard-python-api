`timescale 1ns / 1ps
`default_nettype wire
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
	 input [23:0] data_in
    );

reg load = 0;
reg enable = 0;
reg [47:0] data = 0;
wire thresh;

assign rdy = ~enable;

always @(posedge clk) begin
	if (cs) begin
		if (op[3] == 0) begin
			data <= {24'b0, data_in};
		end else begin
			data <= {data_in, 24'b0};
		end
		load <= 1;
		enable <= 1;
	end
	
	if (load)
		load <= 0;
	
	if (thresh)
		enable <= 0;
end

BC_DOWN_48b counter(
	.clk(clk),
	.ce(enable),
	.load(load),
	.l(data),
	.thresh0(thresh),
	.q()
);

endmodule
