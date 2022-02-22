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
	 
	 // Cross clock domain input
	 input ti_clk,	
	 input data_write,
	 input [15:0] data_in,
	 input en,
	 output rdy,
	 
	 // Clock time output
	 input clr,
	 output [47:0] data_out
    );
	
reg load = 0;
reg enable = 0;
wire thresh;
reg [47:0] counter_data;
assign rdy = ~enable;

always @(posedge ti_clk)
	if (data_write == 1) begin
		counter_data <= {counter_data[31:0], data_in};
	end
	
always @(posedge clk)  begin
	if (en) begin
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
	.l(counter_data),
	.thresh0(thresh),
	.q()
);

BC_UP_48b clock(
	.clk(clk),
	.sclr(clr),
	.q(data_out)
);

endmodule
