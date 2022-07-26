//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: FRA
// 
// Create Date:    23:41:19 07/01/2022 
// Design Name: 
// Module Name:    AD5725 
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

`timescale 1ns / 1ps
`default_nettype wire

//------------------------------------------------------------------------------
//----------- Module Declaration -----------------------------------------------
//------------------------------------------------------------------------------

module AD5725
    (
        // Clock and Reset Signals
        input               FPGA_CLK_I,         // 100 MHz
        input               EN_I,               // Enable Signal, Active High
        input               RESET_N_I,          // Reset Signal, Active Low
        
        // Data Interface
        input               CLR_I,              // Clear DAC Output
        input [11:0]        DATA_I,             // Data
        input [1:0]         ADDR_I,             // Addr
        output              IDLE_O,             // Idle State
        
        // AD5725 Control Signals
        output reg [1:0]    AD_O,               // AD5725 AD
        output reg [11:0]   DB_O,               // AD5725 DB
        output reg          RW_N_O,             // AD5725 RW
        output reg          LDAC_N_O,           // AD5725 LDAC
        output reg          CS_N_O,             // AD5725 CS
        output reg          CLR_N_O             // AD5725 CLR
    );
    
//------------------------------------------------------------------------------
//----------- Constant Declarations --------------------------------------------
//------------------------------------------------------------------------------

`define CNT_ZERO        4'h0
`define CNT_DEC         4'h1
`define W_CNT           3:0
    
//------------------------------------------------------------------------------
//----------- Registers Declarations -------------------------------------------
//------------------------------------------------------------------------------

reg [5:0]       present_state;
reg [5:0]       next_state;

reg [`W_CNT]    cs_hold_cnt;
reg [`W_CNT]    clr_hold_cnt;

reg             clear_en;

//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
// DAC States

parameter DAC_IDLE_STATE            = 6'b000001;
parameter DAC_RW_STATE              = 6'b000100;
parameter DAC_CS_STATE              = 6'b001000;
parameter DAC_LDAC_STATE            = 6'b010000;
parameter DAC_CLR_STATE             = 6'b100000;

// DAC Timing
parameter [`W_CNT]      DAC_CS_HOLD_TIME    = 1;
parameter [`W_CNT]      DAC_LDAC_HOLD_TIME  = 1;
parameter [`W_CNT]      DAC_CLR_HOLD_TIME   = 1;

//------------------------------------------------------------------------------
//----------- Assign/Always Blocks ---------------------------------------------
//------------------------------------------------------------------------------
assign IDLE_O = (present_state == DAC_IDLE_STATE);

// Timer
always @(posedge FPGA_CLK_I)
begin
    if (present_state == DAC_CS_STATE)
    begin
        if (cs_hold_cnt > `CNT_ZERO)
        begin
            cs_hold_cnt <= cs_hold_cnt - `CNT_DEC;
        end
    end
    else
    begin
        cs_hold_cnt <= DAC_CS_HOLD_TIME;
    end
    
    if (present_state == DAC_CLR_STATE)
    begin
        if (clr_hold_cnt > `CNT_ZERO)
        begin
            clr_hold_cnt <= clr_hold_cnt - `CNT_DEC;
        end
    end
    else
    begin
        clr_hold_cnt <= DAC_CLR_HOLD_TIME;
    end
end

// Write Mode
always @(posedge FPGA_CLK_I)
begin
    if (present_state == DAC_RW_STATE)
    begin
        AD_O            <= DATA_I;
        DB_O            <= ADDR_I;
    end
end

// Register States
always @(posedge FPGA_CLK_I)
begin
    if (RESET_N_I == 1'b0)
    begin
        present_state <= DAC_IDLE_STATE;
    end
    else
    begin
        present_state <= next_state;
    end
end

// State switching logic
always @(present_state, EN_I, CLR_I, cs_hold_cnt, ldac_hold_cnt, clr_hold_cnt)
begin
    next_state = present_state;
    case (present_state)
        DAC_IDLE_STATE:
            begin
                if (EN_I == 1'b1)
                begin
                    if (CLR_I == 1'b1)
                    begin
                        next_state = DAC_CLR_STATE;
                    end
                    else
                    begin
                        next_state = DAC_RW_STATE;
                    end
                end
            end
        DAC_RW_STATE:
            begin
                next_state = DAC_CS_STATE;
            end
        DAC_CS_STATE:
            begin
                if (cs_hold_cnt == `CNT_ZERO)
                begin
                    next_state = DAC_LDAC_STATE;
                end
            end
        DAC_LDAC_STATE:
            begin
                next_state = DAC_IDLE_STATE;
            end
        DAC_CLR_STATE:
            begin
                if (clr_hold_cnt == `CNT_ZERO)
                begin
                    next_state = DAC_IDLE_STATE;
                end
            end
        default:
            begin
                next_state = DAC_IDLE_STATE;
            end
    endcase
end

// State Output Logic
always @(posedge FPGA_CLK_I)
begin
    case (present_state)
        DAC_IDLE_STATE:
            begin
                RW_N_O      <= 1'b1;
                LDAC_N_O    <= 1'b1;
                CS_N_O      <= 1'b1;
                CLR_N_O     <= 1'b1;
            end
        DAC_RW_STATE:
            begin
                RW_N_O      <= 1'b0;
                LDAC_N_O    <= 1'b0;
                CS_N_O      <= 1'b1;
                CLR_N_O     <= 1'b1;
            end
        DAC_CS_STATE:
            begin
                RW_N_O      <= 1'b0;
                LDAC_N_O    <= 1'b1;
                CS_N_O      <= 1'b0;
                CLR_N_O     <= 1'b1;
            end
        DAC_LDAC_STATE:
            begin
                RW_N_O      <= 1'b1;
                LDAC_N_O    <= 1'b0;
                CS_N_O      <= 1'b1;
                CLR_N_O     <= 1'b1;
            end
        DAC_CLR_STATE:
            begin
                RW_N_O      <= 1'b1;
                LDAC_N_O    <= 1'b1;
                CS_N_O      <= 1'b1;
                CLR_N_O     <= 1'b0;
            end
        default:
            begin
                RW_N_O      <= 1'b1;
                LDAC_N_O    <= 1'b1;
                CS_N_O      <= 1'b1;
                CLR_N_O     <= 1'b1;
            end
    endcase
end

endmodule
