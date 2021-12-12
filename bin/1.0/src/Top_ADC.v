`timescale 1ns / 1ps
// For full-power ADC control
module Top_ADC(
	input CLK,
	output reg SCLK,
	output reg CNVST,
	output reg CS,
	input BUSY,
	input DoutA,
	input DoutB,

	output [13:0] adc_out_a,
	output [13:0] adc_out_b,
	input adc_enable,
	input adc_reset,
	output reg adc_ready,
	
	output [2:0] debug_adc_stage
);

reg [2:0] _adc_stage = 3'b111;
assign debug_adc_stage = _adc_stage;
/* ADC Stage
	0	ADC readout start, triggered by rising edge of $adc_enable
	1	ADC wair for data conversion
	2	ADC serial data readout
	3	ADC quiet
	4	ADC standby
	3'b111	ADC initial
*/
reg [7:0] _clocker = 8'b0;

reg [3:0] _adc_i = 4'b0;
reg [13:0] _buffer_a = 14'b0;
reg [13:0] _buffer_b = 14'b0;

// Monostable reg&wire
reg _mns_adc_enable = 0;
wire _adc_enable = adc_enable & ~_mns_adc_enable;
reg _mns_adc_reset = 0;
wire _adc_reset = adc_reset & ~_mns_adc_reset;

assign adc_out_a = _buffer_a;
assign adc_out_b = _buffer_b;

always@(posedge CLK) begin
	_mns_adc_enable <= adc_enable;
	_mns_adc_reset <= adc_reset;

	if (_adc_stage==4)
		adc_ready <= 1;
	else
		adc_ready <= 0;

	if (_adc_reset==1) begin
		CS <= 1;
		SCLK <= 1;
		CNVST <= 1;
		_adc_stage <= 4;
		_clocker <= 0;
	end

	if (_adc_stage==4) begin
		if (_adc_enable==1) begin
			_adc_stage <= 0;
			_clocker <= 0;
		end
	end
	else begin
		_clocker <= _clocker+1;

		if (_adc_stage==0) begin
			case (_clocker)
			0:	CNVST <= 0;
			1:	CNVST <= 1;
			5:	_adc_stage <= 1;
			endcase
		end
		if (_adc_stage==1 && BUSY==0) begin
			CS <= 0;
			_adc_i <= 0; //14-bit ADC
			_adc_stage <= 2;
			_clocker <= 0;
		end
		if (_adc_stage==2 && _adc_i<14) begin
			case (_clocker)
			0: begin
				_buffer_a <= {_buffer_a[12:0], DoutA};
				_buffer_b <= {_buffer_b[12:0], DoutB};
				_adc_i <= _adc_i+1;
			end
			1:	SCLK <= 0;
			3: begin
				SCLK <= 1;
				_clocker <= 0;
			end
			endcase
		end
		if (_adc_stage==2 && _adc_i==14) begin
			_adc_stage <= 3;
			_clocker <= 0;
		end
		if (_adc_stage==3) begin
			case (_clocker)
			0:	CS <= 1;
			3: _adc_stage <= 4;
			endcase
		end
	end
end

endmodule
