`timescale 1ns / 1ps
// For single switch status controlling 16 lines
module Switch_Single (
	input CLK,
	output reg RESET,
	output reg CS,
	output reg [3:0] AX,
	output reg [2:0] AY,
	output reg STROBE,
	output reg DATA,

	input sw_set,
	input sw_reset,
	output reg sw_ready,
	input [3:0] sw_ax,
	input [2:0] sw_ay,
	input sw_data
);

reg [2:0] _sw_stage = 3'b111;
/* Switch Stage
	0	Switch set new address
	1	Switch standby
	2	Switch reset3
	3'b111
*/
reg [7:0] _clocker = 8'b0;

always@(posedge CLK) begin
	if (_sw_stage==1)
		sw_ready <= 1;
	else
		sw_ready <= 0;

	if (sw_reset==1) begin
		_sw_stage <= 2;
		_clocker <= 0;
	end

	if (_sw_stage==1) begin
		if (sw_set==1) begin
				_sw_stage <= 0;
				_clocker <= 0;
		end
	end
	else begin
		_clocker <= _clocker+1;

		if (_sw_stage==0) begin
			case (_clocker)
			0: begin
				CS <= 1;
				AX <= sw_ax;
				AY <= sw_ay;
			end
			1:	STROBE <= 1;
			2:	DATA <= sw_data;
			3:	STROBE <= 0;
			4: begin
				CS <= 0;
				DATA <= 0;
				_sw_stage <= 1;
			end
			endcase
		end
		if (_sw_stage==2) begin
			case (_clocker)
			0: begin
				CS <= 0;
				RESET <= 0;
				STROBE <= 0;
				DATA <= 0;
			end
			1:	RESET <= 1;
			5: begin
				RESET <= 0;
				_sw_stage <= 1;
			end
			endcase
		end
	end
end

endmodule 

// For dual switches controlling 28(16+12) lines
module Top_Switch (
	input clk,
	output sw1_reset,
	output sw1_cs,
	output [3:0] sw1_ax,
	output [2:0] sw1_ay,
	output sw1_strobe,
	output sw1_data,
	
	output sw2_reset,
	output sw2_cs,
	output [3:0] sw2_ax,
	output [2:0] sw2_ay,
	output sw2_strobe,
	output sw2_data,
	
	input sw_set,
	input sw_reset,
	output sw_ready,
	input [7:0] address, // {[7:5]AY | [4:0]AX}
	input onoff
);

// Monostable reg&wire
reg _mns_sw_set = 0;
wire _sw_set = sw_set & ~_mns_sw_set;
reg _mns_sw_reset = 0;
wire _sw_reset = sw_reset & ~_mns_sw_reset;

reg _sw1_set = 0;
reg _sw2_set = 0;
wire _sw1_ready;
wire _sw2_ready;

Switch_Single SW1(
	.CLK(clk),.RESET(sw1_reset),.CS(sw1_cs),.AX(sw1_ax),.AY(sw1_ay),.STROBE(sw1_strobe),.DATA(sw1_data),
	.sw_set(_sw1_set),.sw_reset(_sw_reset),.sw_ready(_sw1_ready),
	.sw_ax(address[3:0]),.sw_ay(address[7:5]),.sw_data(onoff)
);
Switch_Single SW2(
	.CLK(clk),.RESET(sw2_reset),.CS(sw2_cs),.AX(sw2_ax),.AY(sw2_ay),.STROBE(sw2_strobe),.DATA(sw2_data),
	.sw_set(_sw2_set),.sw_reset(_sw_reset),.sw_ready(_sw2_ready),
	.sw_ax(address[3:0]),.sw_ay(address[7:5]),.sw_data(onoff)
);

assign sw_ready = _sw1_ready & _sw2_ready;

always@(posedge clk) begin
	_mns_sw_set <= sw_set;
	_mns_sw_reset <= sw_reset;

	if (_sw1_set==1)
		_sw1_set <= 0;
	if (_sw2_set==1)
		_sw2_set <= 0;

	if (_sw_set==1) begin
		_sw1_set <= ~address[4];
		_sw2_set <= address[4];
	end
end

endmodule 