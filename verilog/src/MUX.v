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
//----------- Module Declaration -----------------------------------------------
//------------------------------------------------------------------------------

module MUX
    (
        // Clock And Reset Signals
        input                   fpga_clk_i,             // 100MHz
        input                   reset_i,
        input [47:0]            clock_i,
        
        // FPGA Interface
        input                   en_i,
        input [23:0]            ins_i,
        output                  idle_o,
        output reg              data_ready_o,
        output reg [15:0]       data_o,
        
        // FIFO Interface
        output reg              fifo_wr_o,
        output reg [63:0]       fifo_data_o,

        // ADC Interface
        input [15:0]            ADC_CLK_DIV,
        input [N_ADC-1:0]       ADC_TRIG_MODE,
        
        output reg [N_ADC-1:0]  ADC_EN_OS,
        output reg [N_ADC-1:0]  ADC_RESET_OS,
        
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
parameter               N_ADC=1;
parameter               N_DAC=1;
parameter               N_SW=1;

localparam              W_DEV           = 4;
localparam              DEV_ALL         = {8{1'b1}};

localparam [1:0]        TYPE_ADC        = 2'b00;
localparam [1:0]        TYPE_DAC        = 2'b01;
localparam [1:0]        TYPE_SW         = 2'b10;

localparam [N_ADC-1:0]  ADC_ALL         = {N_ADC{1'b1}};
localparam [N_ADC-1:0]  ADC_NULL        = {N_ADC{1'b0}};
localparam [N_DAC-1:0]  DAC_ALL         = {N_DAC{1'b1}};
localparam [N_DAC-1:0]  DAC_NULL        = {N_DAC{1'b0}};
localparam [N_SW-1:0]   SW_ALL          = {N_SW{1'b1}};
localparam [N_SW-1:0]   SW_NULL         = {N_SW{1'b0}};

// Instruction Decode
wire [7:0]          addr;
wire                flag_reset;
wire                flag_clear;
wire [13:0]         data;
assign {addr, flag_reset, flag_clear, data} = ins_i;

wire [1:0]          type;
wire [W_DEV-1:0]    device;
assign type         = addr[W_DEV+1:W_DEV];
assign device       = addr[W_DEV-1:0];

reg [15:0]          device_selected;            // Select Device
wire                device_all;                 // Select All
assign device_all   = addr[7];

integer i;
always @(*)
begin
    for (i=0; i<15; i=i+1)
    begin
        device_selected[i] = (device == i);
    end
end

// Idle Status, exclude ADC due to auto trigger mode
assign idle_o       = (DAC_IDLE_IS == DAC_ALL) & (SW_IDLE_IS == SW_ALL); 

//------------------------------------------------------------------------------
//----------- ADC Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
// ADC Clock Register
wire                adc_clk;                    // ADC clock
wire [47:0]         adc_timer_q;
BC48 adc_timer
    (
        .clk(fpga_clk_i),
        .l(48'h1),
        .load(adc_clk),
        .q(adc_timer_q)
    );
assign adc_clk = (adc_timer_q[15:0] == ADC_CLK_DIV);

// ADC trigger
reg [W_DEV-1:0]     data_device;
reg                 data_addr;

wire                adc_addr;
assign adc_addr     = data[0]; 

always @(posedge fpga_clk_i)
begin
    ADC_RESET_OS            <= ADC_NULL;
    
    if (reset_i == 1'b1)
    begin
        ADC_EN_OS               <= ADC_NULL;
        data_device             <= 0;
        data_addr               <= 1'b0;
    end
    else if (en_i == 1'b1 && type == TYPE_ADC)
    begin
        if (device_all == 1'b1)
        begin
            if (flag_reset == 1'b1)
            begin
                ADC_EN_OS       <= ADC_NULL;
                ADC_RESET_OS    <= ADC_ALL;
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
                ADC_EN_OS       <= (adc_clk ? ADC_TRIG_MODE : ADC_NULL) & (~device_selected);
                ADC_RESET_OS    <= device_selected;
            end
            else
            begin
                ADC_EN_OS       <= (adc_clk ? ADC_TRIG_MODE : ADC_NULL) | device_selected;
                ADC_RESET_OS    <= ADC_NULL;
                data_device     <= device;
                data_addr       <= adc_addr;
            end
        end
    end
    else
    begin
        ADC_EN_OS               <= (adc_clk ? ADC_TRIG_MODE : ADC_NULL);
    end
end
                 
// ADC Output
reg [W_DEV-1:0]     rr_i = 0;
reg [N_ADC-1:0]     adc_data_ready = 0;
reg [N_ADC*32-1:0]  adc_data = 0;

always @(posedge fpga_clk_i)
begin
    data_ready_o        <= 1'b0;
    fifo_wr_o           <= 1'b0;
    
    if (reset_i == 1'b1)
    begin
        adc_data_ready  <= 0;
        adc_data        <= 0;
        rr_i            <= 0;
        fifo_data_o     <= 0;
    end
    else
    begin
        // Data Register
        for (i=0; i<N_ADC; i=i+1)
        begin
            if ((ADC_TRIG_MODE[i] == 1'b0) && (ADC_DATA_READY_IS[i] == 1'b1))
            begin
                adc_data_ready[i]       <= 1'b1;
                adc_data[i*32 +: 32]    <= ADC_DATA_IS[i*32 +: 32];
            end
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
    
        // Write To FIFO
        if (adc_data_ready[rr_i] == 1'b1)
        begin
            fifo_wr_o       <= 1'b1;
            fifo_data_o     <= {clock_i[23:0], {8-W_DEV{1'b0}}, rr_i, adc_data[rr_i*32 +: 32]};
            adc_data_ready[rr_i] <= 1'b0;
            
            // ADC Data Direct Access
            // Only available for non auto-trigging ADCs
            if (rr_i == data_device)
            begin
                data_o      <= data_addr ? adc_data[rr_i*32+16 +: 16]: adc_data[rr_i*32 +: 16];
                data_ready_o<= 1'b1;
            end
        end
    end
end

//------------------------------------------------------------------------------
//----------- DAC Assign/Always Blocks -----------------------------------------
//------------------------------------------------------------------------------
wire [1:0]          dac_addr;
wire [11:0]         dac_data;
assign dac_addr     = data[13:12];
assign dac_data     = data[11:0];

always @(posedge fpga_clk_i)
begin
    DAC_EN_OS               <= DAC_NULL;
    DAC_RESET_OS            <= DAC_NULL;
    DAC_CLEAR_O             <= 1'b0;
    
    if (en_i == 1'b1 && type == TYPE_DAC)
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
                DAC_DATA_O      <= dac_data;
                DAC_ADDR_O      <= dac_addr;
            end
        end
    end
end

//------------------------------------------------------------------------------
//----------- SW Assign/Always Blocks ------------------------------------------
//------------------------------------------------------------------------------
// Data
wire [3:0]          sw_ax;
wire [2:0]          sw_ay;
wire                sw_data;
assign sw_ax        = data[3:0];
assign sw_ay        = data[6:4];
assign sw_data      = data[8];

always @(posedge fpga_clk_i)
begin
    SW_EN_OS                <= SW_NULL;
    SW_RESET_OS             <= SW_NULL;
    SW_CLEAR_O              <= 1'b0;

    if (en_i == 1'b1 && type == TYPE_SW)
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
                SW_AX_O         <= sw_ax;
                SW_AY_O         <= sw_ay;
                SW_DATA_O       <= sw_data;
            end
        end
    end
end

endmodule
