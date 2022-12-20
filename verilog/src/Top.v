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
    output ADDR_ADC,
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

//------------------------------------------------------------------------------
//----------- OkHost Definition ------------------------------------------------
//------------------------------------------------------------------------------
//OkHost
wire        ti_clk;
wire [30:0] ok1;
wire [16:0] ok2;

assign i2c_sda = 1'bz;
assign i2c_scl = 1'bz;
assign hi_muxsel = 1'b0;

//Ok
parameter           N_OK = 16;
wire [17*N_OK-1:0] ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));
okWireOR #(.N(N_OK)) wireOR (.ok2(ok2), .ok2s(ok2x));

//------------------------------------------------------------------------------
//----------- IO Pipe/FIFO Assign Wires ----------------------------------------
//------------------------------------------------------------------------------
// Status and control signal
wire [15:0]     trigger_in;
wire [15:0]     trigger_out;

okTriggerIn okTriggerIn40(.ok1(ok1), .ep_addr(8'h40), .ep_clk(CLK0),
        .ep_trigger(trigger_in));
    
okTriggerOut okTriggerOut60(.ok1(ok1), .ok2(ok2x[2*17 +: 17]), .ep_addr(8'h60), .ep_clk(CLK0),
        .ep_trigger(trigger_out));
        
// Reset_all: trigger_in[0]
assign fifo_in_rst  = trigger_in[1] | trigger_in[0];
assign fifo_out_rst = trigger_in[2] | trigger_in[0];
assign if_main_rst  = trigger_in[3] | trigger_in[0];
assign clock_rst    = trigger_in[4] | trigger_in[0];
assign reg_rst      = trigger_in[5] | trigger_in[0];
assign mux_rst      = trigger_in[6] | trigger_in[0];

assign trigger_out[0] = direct_data_ready;

// Memory interface
wire            pipe80_write;
wire [15:0]     pipe80_dataout;

wire            pipeA0_read;
wire [15:0]     pipeA0_datain;

wire            fifo_in_rd_en;
wire [15:0]     fifo_in_dout;
wire            fifo_in_empty;
wire [14:0]     fifo_in_wr_data_count;

wire [63:0]     fifo_out_din;
wire            fifo_out_wr_en;
wire [15:0]     fifo_out_rd_data_count;

wire [23:0]     mux_ins;
wire            mux_en;
wire            mux_idle;
wire            mux_data_ready;
wire [15:0]     mux_data;

wire [15:0]     direct_data;

wire [15:0]     status;
wire            fifo_in_full;
wire            if_main_idle;
assign status[0]    = if_main_idle;
assign status[1]    = fifo_in_full;

//------------------------------------------------------------------------------
//----------- IO Pipe/FIFO Assign/Always Blocks --------------------------------
//------------------------------------------------------------------------------

okPipeIn okPipeIn80
    (
        .ok1(ok1),
        .ok2(ok2x[0*17 +: 17]),
        .ep_addr(8'h80),
        .ep_write(pipe80_write),
        .ep_dataout(pipe80_dataout)
    );

FIFO_16B32k_16B fifo_in
    (
        .rst(fifo_in_rst),
        .wr_clk(ti_clk),
        .rd_clk(CLK0),
        .din(pipe80_dataout),
        .wr_en(pipe80_write),
        .rd_en(fifo_in_rd_en),
        .dout(fifo_in_dout),
        .full(fifo_in_full),
        .empty(fifo_in_empty),
        .wr_data_count(fifo_in_wr_data_count)
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
        .wr_clk(CLK0),
        .rd_clk(ti_clk),
        .din(fifo_out_din),
        .wr_en(fifo_out_wr_en),
        .rd_en(pipeA0_read),
        .dout(pipeA0_datain),
        .full(),
        .empty(),
        .rd_data_count(fifo_out_rd_data_count)
    );
    
okWireOut okWireOut20(.ok1(ok1), .ok2(ok2x[3*17 +: 17]), .ep_addr(8'h20), .ep_datain({1'b0, fifo_in_wr_data_count}));
okWireOut okWireOut21(.ok1(ok1), .ok2(ok2x[4*17 +: 17]), .ep_addr(8'h21), .ep_datain(fifo_out_rd_data_count));

okWireOut okWireOut22(.ok1(ok1), .ok2(ok2x[5*17 +: 17]), .ep_addr(8'h22), .ep_datain(direct_data));
okWireOut okWireOut23(.ok1(ok1), .ok2(ok2x[6*17 +: 17]), .ep_addr(8'h23), .ep_datain(status));
    
//------------------------------------------------------------------------------
//----------- Global Register Assign/Always Blocks -----------------------------
//------------------------------------------------------------------------------
parameter           N_REG = 7;
reg [N_REG*16-1:0]  regs;

wire [15:0]         reg_addr;
wire [15:0]         reg_din;
wire                reg_wr;

always @(posedge CLK0)
begin
    if (reg_rst == 1'b1)
    begin
        regs[0*16 +: 16]    <= 16'd5000;
        regs[1*16 +: 16]    <= 16'b0;
        regs[2*16 +: 16]    <= 16'b0;
        regs[3*16 +: 16]    <= 16'b0;
    end
    else
    begin
        if (reg_wr == 1'b1)
        begin
            regs[reg_addr*16 +: 16]   <= reg_din;
        end
    end
    regs[4*16 +: 16] <= ADC_IDLE;   // Non-programmble
    regs[5*16 +: 16] <= DAC_IDLE;   // Non-programmble
    regs[6*16 +: 16] <= SW_IDLE;    // Non-programmble
end

// Begin Register Definitions
wire [15:0]         REG_ADC_CLK_DIV;
wire [15:0]         REG_ADC_READ_MODE;
wire [15:0]         REG_ADC_TRIG_MODE;
wire [15:0]         REG_ADC_ADDR;

assign REG_ADC_CLK_DIV      = regs[0*16 +: 16];
assign REG_ADC_READ_MODE    = regs[1*16 +: 16];
assign REG_ADC_TRIG_MODE    = regs[2*16 +: 16];
assign REG_ADC_ADDR         = regs[3*16 +: 16];

okWireIn okWireIn00(.ok1(ok1), .ep_addr(8'h00), .ep_dataout(reg_addr));
okWireIn okWireIn01(.ok1(ok1), .ep_addr(8'h01), .ep_dataout(reg_din));

okWireOut okWireOut30(.ok1(ok1), .ok2(ok2x[ 8*17 +: 17]), .ep_addr(8'h30), .ep_datain(REG_ADC_CLK_DIV));
okWireOut okWireOut31(.ok1(ok1), .ok2(ok2x[ 9*17 +: 17]), .ep_addr(8'h31), .ep_datain(REG_ADC_READ_MODE));
okWireOut okWireOut32(.ok1(ok1), .ok2(ok2x[10*17 +: 17]), .ep_addr(8'h32), .ep_datain(REG_ADC_TRIG_MODE));
okWireOut okWireOut33(.ok1(ok1), .ok2(ok2x[11*17 +: 17]), .ep_addr(8'h33), .ep_datain(REG_ADC_ADDR));
okWireOut okWireOut34(.ok1(ok1), .ok2(ok2x[12*17 +: 17]), .ep_addr(8'h34), .ep_datain(ADC_IDLE));
okWireOut okWireOut35(.ok1(ok1), .ok2(ok2x[13*17 +: 17]), .ep_addr(8'h35), .ep_datain(DAC_IDLE));
okWireOut okWireOut36(.ok1(ok1), .ok2(ok2x[14*17 +: 17]), .ep_addr(8'h36), .ep_datain(SW_IDLE));
    
//------------------------------------------------------------------------------
//----------- Instruction Fetch Assign/Always Blocks ---------------------------
//------------------------------------------------------------------------------
IF if_main
    (
        .fpga_clk_i(CLK0),
        .reset_i(if_main_rst),
        .idle_o(if_main_idle),
        
        .direct_data_ready_o(direct_data_ready),
        .direct_data_o(direct_data),
        
        .reg_io(reg_io),
        .reg_addr_o(reg_addr),
        .reg_oe_o(reg_oe),
        
        .fifo_empty_n_i(fifo_in_empty),
        .fifo_data_i(fifo_in_dout),
        .fifo_rd_o(fifo_in_rd_en),
        
        .mux_ins_o(mux_ins),
        .mux_en_o(mux_en),
        .mux_idle_i(mux_idle),
        
        .mux_data_ready_i(mux_data_ready),
        .mux_data_i(mux_data)
    );
    
//------------------------------------------------------------------------------
//----------- CLK Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
wire [47:0]         clock_q;
BC48 clock
    (
        .clk(CLK1),
        .l(48'b0),
        .load(clock_rst),
        .q(clock_q)
    );

//------------------------------------------------------------------------------
//----------- Device Assign/Always Blocks --------------------------------------
//------------------------------------------------------------------------------
parameter           N_ADC   = 1;
parameter           N_DAC   = 1;
parameter           N_SW    = 6;

// ADC
wire [N_ADC - 1:0]  ADC_EN;
wire [N_ADC - 1:0]  ADC_RESET;
wire [N_ADC - 1:0]  ADC_IDLE;
wire [N_ADC - 1:0]  ADC_DATA_READY;
wire [N_ADC - 1:0]  ADC_TRIG_MODE;
wire [N_ADC*32-1:0] ADC_DATA;

// DAC
wire [N_DAC - 1:0]  DAC_EN;
wire [N_DAC - 1:0]  DAC_RESET;
wire [N_DAC - 1:0]  DAC_IDLE;
wire                DAC_CLEAR;
wire [11:0]         DAC_DATA;
wire [1:0]          DAC_ADDR;

// SW
wire [N_SW - 1:0]   SW_EN;
wire [N_SW - 1:0]   SW_RESET;
wire [N_SW - 1:0]   SW_IDLE;
wire                SW_CLEAR;
wire [3:0]          SW_AX;
wire [2:0]          SW_AY;
wire                SW_DATA;

MUX #(
        .N_ADC(N_ADC),
        .N_DAC(N_DAC),
        .N_SW(N_SW)
    )
    mux
    (
        .fpga_clk_i(CLK0),
        .reset_i(mux_rst),
        .clock_i(clock_q),

        .en_i(mux_en),
        .ins_i(mux_ins),
        .idle_o(mux_idle),
        .data_ready_o(mux_data_ready),
        .data_o(mux_data),
        
        // FIFO Interface
        .fifo_wr_o(fifo_out_wr_en),
        .fifo_data_o(fifo_out_din),
        
        // ADC
        .ADC_CLK_DIV(REG_ADC_CLK_DIV),
        .ADC_TRIG_MODE(ADC_TRIG_MODE),
        
        .ADC_EN_OS(ADC_EN),
        .ADC_RESET_OS(ADC_RESET),
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
assign ADC_TRIG_MODE = REG_ADC_TRIG_MODE[0:0];

AD7367 adc0
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(ADC_EN[0]),
        .RESET_N_I(~ADC_RESET[0]),
        .READ_MODE_I(REG_ADC_READ_MODE[0]),
        .IDLE_O(ADC_IDLE[0]),
        .DATA_RD_READY_O(ADC_DATA_READY[0]),
        .DATA_O(ADC_DATA[0*32 +: 32]),
        
        .DOUTA_I(DOUTA_ADC),
        .DOUTB_I(DOUTB_ADC),
        .BUSY_I(BUSY_ADC),
        .SCLK_O(SCLK_ADC),
        .CNVST_N_O(CNVST_ADC),
        .CS_N_O(CS_ADC)
    );
assign ADDR_ADC = REG_ADC_ADDR[0];

AD5725 dac0
    (
        .FPGA_CLK_I(CLK0),
        .EN_I(DAC_EN[0]),
        .RESET_N_I(~DAC_RESET[0]),
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
        .RESET_N_I(~SW_RESET[0]),
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
        .RESET_N_I(~SW_RESET[1]),
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
        .RESET_N_I(~SW_RESET[2]),
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
        .RESET_N_I(~SW_RESET[3]),
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
        .RESET_N_I(~SW_RESET[4]),
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
        .RESET_N_I(~SW_RESET[5]),
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
