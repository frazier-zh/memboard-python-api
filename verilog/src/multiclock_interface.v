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
	 input cd_en,
	 output cd_rdy,
	 
	 // Clock time output
	 input en,
	 output [47:0] data_out
    );
	
reg cd_load;
reg [47:0] counter_data;
wire clr;
assign clr = ~en;

wire cd_en_oneshot;
reg cd_en_delay;
always @(posedge clk)
	cd_en_delay <= cd_en;
assign cd_en_oneshot = cd_en & ~cd_en_delay;

always @(posedge ti_clk)
	if (data_write == 1) begin
		counter_data <= {counter_data[31:0], data_in};
	end

always @(posedge clk)
	if ((cd_en_oneshot == 1) || (cd_rdy == 1))
		cd_load <= 1;
	else
		cd_load <= 0;

BC_DOWN_48b counter(
	.clk(clk),
	.load(cd_load),
	.l(counter_data),
	.thresh0(cd_rdy),
	.q()
);

BC_UP_48b clock(
	.clk(clk),
	.ce(en),
	.sclr(clr),
	.q(data_out)
);

endmodule
