`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:36:09 07/13/2022 
// Design Name: 
// Module Name:    MUX 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// RevISion: 
// RevISion 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
`default_nettype wire

//------------------------------------------------------------------------------
//----------- Constant Declarations --------------------------------------------
//------------------------------------------------------------------------------

`define CNT_ZERO        16'h0
`define CNT_DEC         16'h1
`define W_CNT           15:0

`define TYPE_ADC        2'b00
`define TYPE_DAC        2'b01
`define TYPE_SW         2'b10

//------------------------------------------------------------------------------
//----------- Module Declaration -----------------------------------------------
//------------------------------------------------------------------------------

module MUX # (parameter N_ADC=1, parameter N_DAC=1, parameter N_SW=1)
    (
        // Clock And Reset Signals
        input                   fpga_clk_i,             // 100MHz
        input                   timer_clk_i,            // 1MHz
        
        // FPGA Interface
        input                   en_i,
        input [7:0]             device_i,
        input [19:0]            data_i,
        output                  idle_o,
        
        // FIFO Interface
        output                  fifo_wr_o,
        output [63:0]           fifo_data_o,

        // ADC Interface
        output reg [N_ADC-1:0]  ADC_EN_OS,
        output reg [N_ADC-1:0]  ADC_RESET_OS,
        input [N_ADC-1:0]       ADC_IDLE_IS,
        
        output reg              ADC_READ_MODE_O,
        input [N_ADC-1:0]       ADC_DATA_READY_IS,
        input [N_ADC*32-1:0]    ADC_DATA_IS,
        
        // DAC Interface
        output reg [N_DAC-1:0]  DAC_EN_OS,
        output reg [N_DAC-1:0]  DAC_RESET_OS,
        input [N_DAC-1:0]       DAC_IDLE_IS,
        
        output reg              DAC_CLEAR_O,
        output reg [11:0]       DAC_DATA_O,
        output reg [1:0]        DAC_ADDR_O,
        
        // SW Interface
        output reg [N_SW-1:0]   SW_EN_OS,
        output reg [N_SW-1:0]   SW_RESET_OS,
        input [N_SW-1:0]        SW_IDLE_IS,
        
        output reg              SW_CLEAR_O,
        output reg [3:0]        SW_AX_O,
        output reg [2:0]        SW_AY_O,
        output reg              SW_DATA_O
    );

//------------------------------------------------------------------------------
//----------- Parameters Declarations ------------------------------------------
//------------------------------------------------------------------------------
parameter [8:0]         ADC_CLK_DIV     = 500;
parameter [N_ADC-1:0]   ADC_ALL         = {N_ADC{1'b1}};
parameter [N_ADC-1:0]   ADC_NULL        = {N_ADC{1'b0}};
parameter [N_DAC-1:0]   DAC_ALL         = {N_DAC{1'b1}};
parameter [N_DAC-1:0]   DAC_NULL        = {N_DAC{1'b0}};
parameter [N_SW-1:0]    SW_ALL          = {N_SW{1'b1}};
parameter [N_SW-1:0]    SW_NULL         = {N_SW{1'b0}};

// Chip select
wire [1:0]          device_type;
wire [5:0]          device_no;
reg [N_ADC-1:0]     device_selected;            // Select Device
reg                 device_all;                 // Select All

assign device_type  = device_i[7:6];
assign device_no    = device_i[5:0];

always @(device_no)
begin
    for (int i=0; i<N_ADC; i=i+1)
    begin
        if (device_no == i)
            device_selected[i] = 1'b1;
        else
            device_selected[i] = 1'b0;
    end
    
    if (device_no == 6'b111111)
        device_all = 1'b1;
    else
        device_all = 1'b0;
end

// Flag
wire                flag_reset;
wire                flag_clear;
assign flag_reset   = data_i[16];
assign flag_clear   = data_i[17];

// Idle Status, exclude ADC due to auto trigger mode
assign idle_o       = (DAC_IDLE_IS == DAC_ALL) & (SW_IDLE_IS == SW_ALL); 

//------------------------------------------------------------------------------
//----------- CLK Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
wire [47:0]         _timer_q;
wire [31:0]         time_q;
assign time_q       = _timer_q[31:0];
BC48 timer
    (
        .clk(timer_clk_i),
        .sclr(),
        .q(_timer_q)
    );

//------------------------------------------------------------------------------
//----------- ADC Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
// Data
wire                flag_adc_read_mode;
wire                flag_adc_trig_mode;
assign flag_adc_read_mode   = data_i[18];
assign flag_adc_trig_mdoe   = data_i[19];       // Trigger mode 1=auto, 0=external

// ADC Clock Register
reg                 adc_read_mode;
reg [N_ADC-1:0]     adc_trig_mode;
reg [8:0]           adc_clk_count;
reg                 adc_clk;                    // ADC clock

// ADC Clock Generator
always @(posedge fpga_clk_i)
begin
    if (adc_trig_mode == 1'b1)
    begin
        if (adc_clk_count == ADC_CLK_DIV)
        begin
            adc_clk_conut <= 0;
            adc_clk <= 1'b1;
        end
        else
        begin
            adc_clk_count <= adc_clk_count + 1;
            adc_clk <= 1'b0;
        end
    end
    else
    begin
        adc_clk_count <= 0;
        adc_clk <= 1'b0;
    end
end
                 
// ADC trigger
always @(posedge fpga_clk_i)
begin
    if (en_i == 1'b1)
    begin
        ADC_READ_MODE_O         <= flag_adc_read_mode;
        if (device_all == 1'b1)
        begin
            if (flag_reset == 1'b1)
            begin
                ADC_EN_OS       <= ADC_NULL;
                ADC_RESET_OS    <= ADC_ALL;
                adc_trig_mode   <= ADC_NULL;
            end
            else if (flag_adc_trig_mode == 1'b1)
            begin
                ADC_EN_OS       <= ADC_ALL;
                ADC_RESET_OS    <= ADC_NULL;
                adc_trig_mode   <= ADC_ALL;
            end
            else
            begin
                ADC_EN_OS       <= ADC_ALL;
                ADC_RESET_OS    <= ADC_NULL;
            end
        end
        else
        begin
            if (flag_reset == 1'b1)
            begin
                ADC_EN_OS       <= (adc_clk ? adc_trig_mode : ADC_NULL) & (~device_selected);
                ADC_RESET_OS    <= device_selected;
                adc_trig_mode   <= adc_trig_mode & (~device_selected);
            end
            else if (flag_adc_trig_mode == 1'b1)
            begin
                ADC_EN_OS       <= (adc_clk ? adc_trig_mode : ADC_NULL) | device_selected;
                ADC_RESET_OS    <= ADC_NULL;
                adc_trig_mode   <= adc_trig_mode | device_selected;
            end
            else
            begin
                ADC_EN_OS       <= (adc_clk ? adc_trig_mode : ADC_NULL) | device_selected;
                ADC_RESET_OS    <= ADC_NULL;
            end
        end
    end
    else
    begin
        ADC_EN_OS               <= (adc_clk ? adc_trig_mode : ADC_NULL);
        ADC_RESET_OS            <= ADC_NULL;
    end
end
                 
// ADC Input
reg [5:0]     rr_i = 0;
always @(posedge fpga_clk_i)
begin
    // Data Register
    for (int i=0; i<N_ADC; i=i+1)
    begin
        if (ADC_DATA_READY_IS[i] == 1'b1)
        begin
            adc_data_ready[i]       <= 1'b1;
            adc_data[i*32 +: 32]    <= ADC_DATA_IS[i*32 +: 32];
        end
    end
    
    // Write To FIFO
    if (adc_data_ready[rr_i] == 1'b1)
    begin
        fifo_wr_o       <= 1'b1;
        fifo_data_o     <= {timer_q, adc_data[rr_i*32 +: 32]};
    end
    else
    begin
        fifo_wr_o       <= 1'b0;
    end
    
    // Round Robin
    if (rr_i < N_ADC-1)
    begin
        rr_i            <= rr_i + 1;
    end
    else
    begin
        rr_i            <= 0;
    end
end

//------------------------------------------------------------------------------
//----------- DAC Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
// Data
wire [13:0]         dac_data;
assign dac_data     = data_i[13:0];

always @(posedge fpga_clk_i)
begin
    if (en_i == 1'b1)
    begin
        if (device_all == 1'b1)
        begin
            if (flag_reset == 1'b1)
            begin
                DAC_EN_OS       <= DAC_NULL;
                DAC_RESET_OS    <= DAC_ALL;
                DAC_CLEAR_O     <= 1'b0;
            end
            else if (flag_clear == 1'b1)
            begin
                DAC_EN_OS       <= DAC_ALL;
                DAC_RESET_OS    <= DAC_NULL;
                DAC_CLEAR_O     <= 1'b1;
            end
            else
            begin
                DAC_EN_OS       <= DAC_NULL;
                DAC_RESET_OS    <= DAC_NULL;
                DAC_CLEAR_O     <= 1'b0;
            end
        end
        else
        begin
            if (flag_reset == 1'b1)
            begin
                DAC_EN_OS       <= DAC_NULL;
                DAC_RESET_OS    <= device_selected;
                DAC_CLEAR_O     <= 1'b0;
            end
            else if (flag_clear == 1'b1)
            begin
                DAC_EN_OS       <= device_selected;
                DAC_RESET_OS    <= DAC_NULL;
                DAC_CLEAR_O     <= 1'b1;
            end
            else
            begin
                DAC_EN_OS       <= device_selected;
                DAC_RESET_OS    <= DAC_NULL;
                DAC_CLEAR_O     <= 1'b0;
                DAC_DATA_O      <= dac_data[11:0];
                DAC_ADDR_O      <= dac_data[13:12];
            end
        end
    end
    else
    begin
        DAC_EN_OS               <= DAC_NULL;
        DAC_RESET_OS            <= DAC_NULL;
        DAC_CLEAR_O             <= 1'b0;
    end
end

//------------------------------------------------------------------------------
//----------- SW Assign/Always Blocks ------------------------------------------
//------------------------------------------------------------------------------
// Data
wire [7:0]          sw_data;
assign sw_data      = data_i[7:0];

always @(posedge fpga_clk_i)
begin
    if (en_i == 1'b1)
    begin
        if (device_all == 1'b1)
        begin
            if (flag_reset == 1'b1)
            begin
                SW_EN_OS        <= SW_NULL;
                SW_RESET_OS     <= SW_ALL;
                SW_CLEAR_O      <= 1'b0;
            end
            else if (flag_clear == 1'b0)
            begin
                SW_EN_OS        <= SW_ALL;
                SW_RESET_OS     <= SW_NULL;
                SW_CLEAR_O      <= 1'b1;
            end
            else
            begin
                SW_EN_OS        <= SW_NULL;
                SW_RESET_OS     <= SW_NULL;
                SW_CLEAR_O      <= 1'b0;
            end
        end
        else
        begin
            if (flag_reset == 1'b1)
            begin
                SW_EN_OS        <= SW_NULL;
                SW_RESET_OS     <= device_selected;
                SW_CLEAR_O      <= 1'b0;
            end
            else if (flag_clear == 1'b1)
            begin
                SW_EN_OS        <= device_selected;
                SW_RESET_OS     <= SW_NULL;
                SW_CLEAR_O      <= 1'b1;
            end
            else
            begin
                SW_EN_OS        <= device_selected;
                SW_RESET_OS     <= SW_NULL;
                SW_CLEAR_O      <= 1'b0;
                SW_AX_O         <= sw_data[3:0];
                SW_AY_O         <= sw_data[6:4];
                SW_DATA_O       <= sw_data[7];
            end
        end
    end
    else
    begin
        SW_EN_OS                <= SW_NULL;
        SW_RESET_OS             <= SW_NULL;
        SW_CLEAR_O              <= 1'b0;
    end
end

endmodule
