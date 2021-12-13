`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:54:00 12/06/2021 
// Design Name: 
// Module Name:    switch_interface_mt8816 
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
module switch_interface_mt8816(
	output reg RESET,
	output reg CS,
	output reg [3:0] AX,
	output reg [2:0] AY,
	output reg STROBE,
	output reg DATA,

	input clk,
	input en,
	input rst,
	output reg rdy,
	input [3:0] x,
	input [2:0] y,
	input on
	);

// FSM basic
localparam
	s_reset =	5'b00001,
	s_clear =	5'b00010,
	s_wait =		5'b00100,
	s_idle =		5'b01000,
	s_start =	5'b10000;
reg [4:0] state;
reg [7:0] time_count;
reg time_enable;

// FSM logic
localparam
	t_reset = 6,
	t_delay = 9;

always @(posedge clk) begin
	if (rst) begin
		state <= s_reset;
		CS <= 0;
		RESET <= 0;
		STROBE <= 0;
		rdy <= 0;
		time_count <= 8'b0;
		time_enable <= 0;
	end else begin
		if (time_enable) begin
			time_count <= time_count + 1;
		end else begin
			time_count <= 0;
		end
	
		case (state)
			s_reset:
				if (~rst) begin
					state <= s_clear;
					RESET <= 1;
					time_enable <= 1;
				end else begin
					state <= s_reset;
				end
				
			s_clear:
				if (time_count == t_reset) begin
					state <= s_wait;
					RESET <= 0;
					time_count <= 0;
				end else begin
					state <= s_clear;
				end
				
			s_wait:
				if (time_count == t_delay) begin
					state <= s_idle;
					rdy <= 1;
					time_enable <= 0;
				end else begin
					state <= s_wait;
				end
				
			s_idle:
				if (en == 1) begin
					state <= s_start;
					rdy <= 0;
					time_enable <= 1;
				end else begin
					state <= s_idle;
				end
				
			s_start:
				case (time_count)
					1: begin
							CS <= 1;
							AX <= x;
							AY <= y;
							DATA <= on;
						end
					3: STROBE <= 1;
					6: STROBE <= 0;
					8: begin
							state <= s_wait;
							time_count <= 0;
							CS <= 0;
						end
				endcase
		endcase
	end
end

endmodule

module switch_interface_group(
	output RESET_switch1,
	output CS_switch1,
	output [3:0] AX_switch1,
	output [2:0] AY_switch1,
	output Strobe_switch1,
	output DATA_switch1,
	output RESET_switch2,
	output CS_switch2,
	output [3:0] AX_switch2,
	output [2:0] AY_switch2,
	output Strobe_switch2,
	output DATA_switch2,
	output RESET_switch3,
	output CS_switch3,
	output [3:0] AX_switch3,
	output [2:0] AY_switch3,
	output Strobe_switch3,
	output DATA_switch3,
	output RESET_switch4,
	output CS_switch4,
	output [3:0] AX_switch4,
	output [2:0] AY_switch4,
	output Strobe_switch4,
	output DATA_switch4,
	output RESET_switch5,
	output CS_switch5,
	output [3:0] AX_switch5,
	output [2:0] AY_switch5,
	output Strobe_switch5,
	output DATA_switch5,
	output RESET_switch6,
	output CS_switch6,
	output [3:0] AX_switch6,
	output [2:0] AY_switch6,
	output Strobe_switch6,
	output DATA_switch6,
	
	input clk,
	input cs,
	output rdy,
	input [3:0] op,
	input [7:0] addr,
	input [15:0] data_in
);

reg en = 0, rst = 0;

reg [3:0] x = 0;
reg [2:0] y = 0;
reg on = 0;

reg [5:0] sw_en = 0;
wire sw1_en, sw2_en, sw3_en, sw4_en, sw5_en, sw6_en;
assign {sw1_en, sw2_en, sw3_en, sw4_en, sw5_en, sw6_en} = sw_en;

wire sw1_rdy, sw2_rdy, sw3_rdy, sw4_rdy, sw5_rdy, sw6_rdy;
assign rdy = {sw1_rdy, sw2_rdy, sw3_rdy, sw4_rdy, sw5_rdy, sw6_rdy} == 6'b111111;

// Arguments
always @(posedge clk)
	if (cs == 1) begin
		rst <= op[0];
		en <= op[1];
		
		y <= data_in[5:4];
		on <= data_in[8];
		
		case (data_in[3:0])
			6,7,8,9,10,11: x <= data_in[3:0]+2;
			12: x <= 6;
			13: x <= 7;
			default:
				x <= data_in[3:0];
		endcase
	end else begin
		rst <= 0;
		en <= 0;
	end

always @(posedge clk) begin
	if (rst == 1) begin
		sw_en <= 0;
	end else begin
		if (en == 1) begin
			sw_en[1<<addr[3:0]] <= 1;
		end else begin
			sw_en <= 0;
		end
	end
end

switch_interface_mt8816 switch_1(
	.RESET(RESET_switch1), .CS(CS_switch1), .AX(AX_switch1), .AY(AY_switch1), .STROBE(Strobe_switch1), .DATA(DATA_switch1),
	.clk(clk), .en(sw1_en), .rst(rst), .rdy(sw1_rdy), .x(x), .y(y), .on(on)
);
switch_interface_mt8816 switch_2(
	.RESET(RESET_switch2), .CS(CS_switch2), .AX(AX_switch2), .AY(AY_switch2), .STROBE(Strobe_switch2), .DATA(DATA_switch2),
	.clk(clk), .en(sw2_en), .rst(rst), .rdy(sw2_rdy), .x(x), .y(y), .on(on)
);
switch_interface_mt8816 switch_3(
	.RESET(RESET_switch3), .CS(CS_switch3), .AX(AX_switch3), .AY(AY_switch3), .STROBE(Strobe_switch3), .DATA(DATA_switch3),
	.clk(clk), .en(sw3_en), .rst(rst), .rdy(sw3_rdy), .x(x), .y(y), .on(on)
);
switch_interface_mt8816 switch_4(
	.RESET(RESET_switch4), .CS(CS_switch4), .AX(AX_switch4), .AY(AY_switch4), .STROBE(Strobe_switch4), .DATA(DATA_switch4),
	.clk(clk), .en(sw4_en), .rst(rst), .rdy(sw4_rdy), .x(x), .y(y), .on(on)
);
switch_interface_mt8816 switch_5(
	.RESET(RESET_switch5), .CS(CS_switch5), .AX(AX_switch5), .AY(AY_switch5), .STROBE(Strobe_switch5), .DATA(DATA_switch5),
	.clk(clk), .en(sw5_en), .rst(rst), .rdy(sw5_rdy), .x(x), .y(y), .on(on)
);
switch_interface_mt8816 switch_6(
	.RESET(RESET_switch6), .CS(CS_switch6), .AX(AX_switch6), .AY(AY_switch6), .STROBE(Strobe_switch6), .DATA(DATA_switch6),
	.clk(clk), .en(sw6_en), .rst(rst), .rdy(sw6_rdy), .x(x), .y(y), .on(on)
);

endmodule