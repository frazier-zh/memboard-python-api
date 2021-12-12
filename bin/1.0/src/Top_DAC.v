`timescale 1ns / 1ps

module Top_DAC (
	input CLK,
	output reg [11:0] DB,
	output reg [1:0] AD,
	output reg RW,
	output reg LDAC,
	output reg CS,
	output reg CLR,

	input dac_enable,
	input dac_reset,
	output reg dac_ready,
	input [1:0] address,
	input [11:0] data
);

reg [2:0] _dac_stage = 3'b111;
/* DAC Stage
	0	DAC set new value
	1	DAC standby
	2	DAC initial
	3'b111
*/
reg [7:0] _clocker = 8'b0;

// Monostable reg&wire
reg _mns_dac_reset = 0;
wire _dac_reset = dac_reset & ~_mns_dac_reset;
reg _mns_dac_enable = 0;
wire _dac_enable = dac_enable & ~_mns_dac_enable;

always@(posedge CLK) begin
	_mns_dac_reset <= dac_reset;
	_mns_dac_enable <= dac_enable;

	if (_dac_stage==1)
		dac_ready <= 1;
	else
		dac_ready <= 0;

	if (_dac_reset==1) begin
		_dac_stage <= 2;
		_clocker <= 0;
	end

	if (_dac_stage==1) begin
		if (_dac_enable==1) begin
			_dac_stage <= 0;
			_clocker <= 0;
		end
	end
	else begin
		_clocker <= _clocker+1;

		if (_dac_stage==0) begin
			case (_clocker)
			0: begin
				CS <= 1;
				LDAC <= 0;
				RW <= 0;
				AD <= address;
				DB <= data;
			end
			1:	CS <= 0;
			2:	CS <= 1;
			3: begin
				RW <= 1;
				LDAC <= 1;
				_dac_stage <= 1;
			end
			endcase
		end
		if (_dac_stage==2) begin
			case (_clocker)
			0: begin
				CS <= 1;
				RW <= 1;
				LDAC <= 1;
				CLR <= 0;
			end
			1: begin
				CLR <= 1;
				_dac_stage <= 1;
			end
			endcase
		end
	end
end

endmodule 
