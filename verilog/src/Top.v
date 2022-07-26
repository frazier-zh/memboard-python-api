`timescale 1ns / 1ps
module TOP(
	//Peripheral control signals
	inout [11:0] DB_DAC,
	output [1:0] AD_DAC,
	output RW_DAC,
	output LDAC_DAC,
	output CS_DAC,
	output CLR_DAC,
	output RESET_SW1,
	output CS_SW1,
	output [3:0] AX_SW1,
	output [2:0] AY_SW1,
	output STROBE_SW1,
	output DATA_SW1,
	output RESET_SW2,
	output CS_SW2,
	output [3:0] AX_SW2,
	output [2:0] AY_SW2,
	output STROBE_SW2,
	output DATA_SW2,
	output RESET_SW3,
	output CS_SW3,
	output [3:0] AX_SW3,
	output [2:0] AY_SW3,
	output STROBE_SW3,
	output DATA_SW3,
	output RESET_SW4,
	output CS_SW4,
	output [3:0] AX_SW4,
	output [2:0] AY_SW4,
	output STROBE_SW4,
	output DATA_SW4,
	output RESET_SW5,
	output CS_SW5,
	output [3:0] AX_SW5,
	output [2:0] AY_SW5,
	output STROBE_SW5,
	output DATA_SW5,
	output RESET_SW6,
	output CS_SW6,
	output [3:0] AX_SW6,
	output [2:0] AY_SW6,
	output STROBE_SW6,
	output DATA_SW6,
	output SCLK_ADC,
    output CNVST_ADC,
    output CS_ADC,
    input BUSY_ADC,
    output reg ADDR_ADC=0,
    input DOUTA_ADC,
	input DOUTB_ADC,
	
    input CLK0,
    input CLK1,
	output [7:0] LED,
	
	//OkHostInterface
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,
	output wire        i2c_sda,
	output wire        i2c_scl,
	output wire        hi_muxsel
 );

//OkHost
wire        ti_clk;
wire [30:0] ok1;
wire [16:0] ok2;

assign i2c_sda = 1'bz;
assign i2c_scl = 1'bz;
assign hi_muxsel = 1'b0;

//Ok
wire [17*6-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));
okWireOR #(.N(6)) wireOR (.ok2(ok2), .ok2s(ok2x));

// Status and control signal
wire [15:0]     trigger;
wire            fifo_in_rst;
wire            fifo_out_rst;
wire            if_main_rst;

assign fifo_in_rst  = trigger[0];
assign fifo_out_rst = trigger[0];
assign if_main_rst  = trigger[1];

// Memory interface
wire            pipe80_write;
wire [15:0]     pipe80_dataout;

wire            pipeA0_read;
wire [15:0]     pipeA0_datain;

wire            fifo_in_rd_en;
wire [31:0]     fifo_in_dout;
wire            fifo_in_empty;

wire [63:0]     fifo_out_din;
wire            fifo_out_wr_en;
wire [15:0]     fifo_out_rd_data_count;

wire [27:0]     mux_data;
wire            mux_en;
wire            mux_idle;

okPipeIn okPipeIn80
    (
        .ok1(ok1),
        .ok2(ok2x[0*17 +: 17]),
        .ep_addr(8'h80),
        .ep_write(pipe80_write),
        .ep_dataout(pipe80_dataout)
    );

FIFO_16B16k_32B fifo_in
    (
        .rst(fifo_in_rst),
        .wr_clk(ti_clk),
        .rd_clk(CLK),
        .din(pipe80_dataout),
        .wr_en(pipe80_write),
        .rd_en(fifo_in_rd_en),
        .dout(fifo_in_dout),
        .full(),
        .empty(fifo_in_empty)
    );

okPipeOut okPipeOutA0
    (
        .ok1(ok1),
        .ok2(ok2x[1*17 +: 17]),
        .ep_addr(8'hA0),
        .ep_read(pipeA0_read),
        .ep_datain(pipeA0_datain)
    );

FIFO_64B16k_16B fifo_out
    (
        .rst(fifo_out_rst),
        .wr_clk(CLK),
        .rd_clk(ti_clk),
        .din(fifo_out_din),
        .wr_en(fifo_out_wr_en),
        .rd_en(pipeA0_read),
        .dout(pipeA0_datain),
        .full(),
        .empty(),
        .rd_data_count(fifo_out_rd_data_count)
    );

okTriggerIn okTriggerIn40
    (
        .ok1(ok1),
        .ep_addr(8'h40),
        .ep_clk(CLK),
        .ep_trigger(trigger)
    );
    
okWireOut okWireOut20
    (
        .ok1(ok1),
        .ok2(ok2x[2*17 +: 17]),
        .ep_addr(8'h20),
        .ep_datain(fifo_out_rd_data_count),
    );
    
IF if_main
    (
        .fpga_clk_i(CLK),
        .reset_n_i(),
        
        .fifo_empty_n_i(fifo_in_empty),
        .fifo_data_i(fifo_in_dout),
        .fifo_rd_o(fifo_in_rd_en),
        
        .mux_data_o(mux_data),
        .mux_en_o(mux_en),
        .mux_idle_i(mux_idle)
    );

// Device definitions
parameter real      n_adc   = 1;
parameter real      n_dac   = 1;
parameter real      n_sw    = 6;
// ADC
wire [n_adc - 1:0]  ADC_EN;
wire [n_adc - 1:0]  ADC_RESET;
wire [n_adc - 1:0]  ADC_IDLE;
wire                ADC_READ_MODE;
wire [n_adc - 1:0]  ADC_DATA_READY;
wire [n_adc*32-1:0] ADC_DATA;

// DAC
wire [n_dac - 1:0]  DAC_EN;
wire [n_dac - 1:0]  DAC_RESET;
wire [n_dac - 1:0]  DAC_IDLE;
wire                DAC_CLEAR;
wire [11:0]         DAC_DATA;
wire [1:0]          DAC_ADDR;

// SW
wire [n_sw - 1:0]   SW_EN;
wire [n_sw - 1:0]   SW_RESET;
wire [n_sw - 1:0]   SW_IDLE;
wire                SW_CLEAR;
wire [3:0]          SW_AX;
wire [2:0]          SW_AY;
wire                SW_DATA;

MUX #(
        .N_ADC(n_adc),
        .N_DAC(n_dac),
        .N_SW(n_sw)
    )
    mux0
    (
        .fpga_clk_i(CLK0),
        .timer_clk_i(CLK1),

        .en_i(mux_en),
        .device_i(mux_data[27:20]),
        .data_i(mux_data[19:0]),
        .idle_o(mux_idle),
        
        // FIFO Interface
        .fifo_wr_o(fifo_out_wr_en),
        .fifo_data_o(fifo_out_din),
        
        // ADC
        .ADC_EN_OS(ADC_EN),
        .ADC_RESET_OS(ADC_RESET),
        .ADC_IDLE_IS(ADC_IDLE),
        .ADC_READ_MODE_O(ADC_READ_MODE),
        .ADC_DATA_READY_IS(ADC_DATA_READY),
        .ADC_DATA_IS(ADC_DATA),
        
        // DAC
        .DAC_EN_OS(DAC_EN),
        .DAC_RESET_OS(DAC_RESET),
        .DAC_IDLE_IS(DAC_IDLE),
        .DAC_CLEAR_O(DAC_CLEAR),
        .DAC_DATA_O(DAC_DATA),
        .DAC_ADDR_O(DAC_ADDR),
        
        // SW
        .SW_EN_OS(SW_EN),
        .SW_RESET_OS(SW_RESET),
        .SW_IDLE_IS(SW_IDLE),
        .SW_CLEAR_O(SW_CLEAR),
        .SW_AX_O(SW_AX),
        .SW_AY_O(SW_AY),
        .SW_DATA_O(SW_DATA)
    );

AD7367 adc0
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(ADC_EN[0]),
        .RESET_N_I(ADC_RESET[0]),
        .READ_MODE_I(ADC_READ_MODE),
        .IDLE_O(ADC_IDLE[0]),
        .DATA_READY_O(ADC_DATA_READY[0]),
        .DATA_O(ADC_DATA[0*32 +: 32]),
        
        .DOUTA_I(DOUTA_ADC),
        .DOUTB_I(DOUTB_ADC),
        .BUSY_I(BUSY_ADC),
        .SCLK_O(SCLK_ADC),
        .CNVST_O(CNVST_ADC),
        .CS_O(CS_ADC)
    );

AD5725 dac0
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(DAC_EN[0]),
        .RESET_I(DAC_RESET[0]),
        .CLR_I(DAC_CLEAR),
        .DATA_I(DAC_DATA),
        .ADDR_I(DAC_ADDR),
        .IDLE_O(DAC_IDLE[0]),
        
        .AD_O(AD_DAC),
        .DB_O(DB_DAC),
        .RW_N_O(RW_DAC),
        .LDAC_N_O(LDAC_DAC),
        .CS_N_O(CS_DAC),
        .CLR_N_O(CLR_DAC)
    );

MT8816 sw0
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[0]),
        .RESET_I(SW_RESET[0]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[0]),
        
        .RESET_O(RESET_SW1),
        .CS_O(CS_SW1),
        .STROBE_O(STROBE_SW1),
        .AX_O(AX_SW1),
        .AY_O(AY_SW1),
        .DATA_O(DATA_SW1)
    );
    
MT8816 sw1
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[1]),
        .RESET_I(SW_RESET[1]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[1]),
        
        .RESET_O(RESET_SW2),
        .CS_O(CS_SW2),
        .STROBE_O(STROBE_SW2),
        .AX_O(AX_SW2),
        .AY_O(AY_SW2),
        .DATA_O(DATA_SW2)
    );

MT8816 sw2
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[2]),
        .RESET_I(SW_RESET[2]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[2]),
        
        .RESET_O(RESET_SW3),
        .CS_O(CS_SW3),
        .STROBE_O(STROBE_SW3),
        .AX_O(AX_SW3),
        .AY_O(AY_SW3),
        .DATA_O(DATA_SW3)
    );

MT8816 sw3
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[3]),
        .RESET_I(SW_RESET[3]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[3]),
        
        .RESET_O(RESET_SW4),
        .CS_O(CS_SW4),
        .STROBE_O(STROBE_SW4),
        .AX_O(AX_SW4),
        .AY_O(AY_SW4),
        .DATA_O(DATA_SW4)
    );
    
MT8816 sw4
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[4]),
        .RESET_I(SW_RESET[4]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[4]),
        
        .RESET_O(RESET_SW5),
        .CS_O(CS_SW5),
        .STROBE_O(STROBE_SW5),
        .AX_O(AX_SW5),
        .AY_O(AY_SW5),
        .DATA_O(DATA_SW5)
    );
    
MT8816 sw5
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(SW_EN[5]),
        .RESET_I(SW_RESET[5]),
        .CLR_I(SW_CLEAR),
        .AX_I(SW_AX),
        .AY_I(SW_AY),
        .DATA_I(SW_DATA),
        .IDLE_O(SW_IDLE[5]),
        
        .RESET_O(RESET_SW6),
        .CS_O(CS_SW6),
        .STROBE_O(STROBE_SW6),
        .AX_O(AX_SW6),
        .AY_O(AY_SW6),
        .DATA_O(DATA_SW6)
    );

endmodule
