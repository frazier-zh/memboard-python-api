//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: FRA
// 
// Create Date:    19:55:00 07/02/2022 
// Design Name: 
// Module Name:    MT8816 
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

module MT8816
    (
        // Clock and Reset Signals
        input               FPGA_CLK_I,         // 100 MHz
		input               EN_I,               // Enable Signal, Active High
        input               RESET_N_I,          // Reset Signal, Active Low
        
        // Data Interface
        input               CLR_I,              // Clear Signal
        input [3:0]         AX_I,               // Select AX
        input [2:0]         AY_I,               // Select AY
        input               DATA_I,             // Data On/Off
        output              IDLE_O,             // Idle State
        
        // MT8816 Control Signals
        output reg          RESET_O,            // MT8816 RESET
        output reg          CS_O,               // MT8816 CS
        output reg          STROBE_O,           // MT8816 STROBE
        output reg [3:0]    AX_O,               // MT8816 AX
        output reg [2:0]    AY_O,               // MT8816 AY
        output reg          DATA_O              // MT8816 DATA
    );

//------------------------------------------------------------------------------
//----------- Registers Declarations -------------------------------------------
//------------------------------------------------------------------------------

reg [4:0]       present_state;
reg [4:0]       next_state;

reg [15:0]      cs_setup_cnt;
reg [15:0]      strobe_hold_cnt;
reg [15:0]      cs_hold_cnt;
reg [15:0]      clr_hold_cnt;

//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
// Switch States

parameter SW_IDLE_STATE         = 5'b00001;
parameter SW_CS_STATE           = 5'b00010;
parameter SW_STROBE_STATE       = 5'b00100;
parameter SW_CS_EN_STATE        = 5'b01000;
parameter SW_CLR_STATE          = 5'b10000;

parameter [15:0] TIME_ZERO              = 16'b0;
parameter [15:0] SW_CLR_HOLD_TIME     = 4;
parameter [15:0] SW_STROBE_HOLD_TIME    = 2;
parameter [15:0] SW_CS_SETUP_TIME       = 1;
parameter [15:0] SW_CS_HOLD_TIME        = 1;


//------------------------------------------------------------------------------
//----------- Assign/Always Blocks ---------------------------------------------
//------------------------------------------------------------------------------
assign IDLE_O = (present_state == SW_IDLE_STATE);

// Timer
always @(posedge FPGA_CLK_I)
begin
    if (present_state == SW_CS_STATE)
    begin
        if (cs_setup_cnt > TIME_ZERO)
        begin
            cs_setup_cnt <= cs_setup_cnt - 1'b1;
        end
    end
    else
    begin
        cs_setup_cnt <= SW_CS_SETUP_TIME;
    end
    
    if (present_state == SW_STROBE_STATE)
    begin
        if (strobe_hold_cnt > TIME_ZERO)
        begin
            strobe_hold_cnt <= strobe_hold_cnt - 1'b1;
        end
    end
    else
    begin
        strobe_hold_cnt <= SW_STROBE_HOLD_TIME;
    end
    
    if (present_state == SW_CS_EN_STATE)
    begin
        if (cs_hold_cnt > TIME_ZERO)
        begin
            cs_hold_cnt <= cs_hold_cnt - 1'b1;
        end
    end
    else
    begin
        cs_hold_cnt <= SW_CS_HOLD_TIME;
    end
    
    if (present_state == SW_CLR_STATE)
    begin
        if (clr_hold_cnt > TIME_ZERO)
        begin
            clr_hold_cnt <= clr_hold_cnt - 1'b1;
        end
    end
    else
    begin
        clr_hold_cnt <= SW_CLR_HOLD_TIME;
    end
end

always @(posedge FPGA_CLK_I)
begin
	if (present_state == SW_CS_STATE)
    begin
        //AX_O          <= AX_I;
        AY_O            <= AY_I;
        DATA_O          <= DATA_I;
        // Explicit port mapping due to chip error
        case (AX_I)
            4'h6: AX_O  <= 4'h8;
            4'h7: AX_O  <= 4'h9;
            4'h8: AX_O  <= 4'hA;
            4'h9: AX_O  <= 4'hB;
            4'hA: AX_O  <= 4'hC;
            4'hB: AX_O  <= 4'hD;
            4'hC: AX_O  <= 4'h6;
            4'hD: AX_O  <= 4'h7;
            default:
                AX_O    <= AX_I;
        endcase
    end
end

// Register States
always @(posedge FPGA_CLK_I)
begin
    if (RESET_N_I == 1'b0)
    begin
        present_state <= SW_IDLE_STATE;
    end
    else
    begin
        present_state <= next_state;
    end
end

// State switching logic
always @(*)
begin
    next_state = present_state;
    case (present_state)
        SW_IDLE_STATE:
            begin
                if (EN_I == 1'b1)
                begin
                    if (CLR_I == 1'b1)
                    begin
                        next_state = SW_CLR_STATE;
                    end
                    else
                    begin
                        next_state = SW_CS_STATE;
                    end
                end 
            end
        SW_CS_STATE:
            begin
                if (cs_setup_cnt == TIME_ZERO)
                begin
                    next_state = SW_STROBE_STATE;
                end
            end
        SW_STROBE_STATE:
            begin
                if (strobe_hold_cnt == TIME_ZERO)
                begin
                    next_state = SW_CS_EN_STATE;
                end
            end
        SW_CS_EN_STATE:
            begin
                if (cs_hold_cnt == TIME_ZERO)
                begin
                    next_state = SW_IDLE_STATE;
                end
            end
        SW_CLR_STATE:
            begin
                if (clr_hold_cnt == TIME_ZERO)
                begin
                    next_state = SW_IDLE_STATE;
                end
            end
        default:
            begin
                next_state = SW_IDLE_STATE;
            end
    endcase
end

always @(posedge FPGA_CLK_I)
begin
    case (present_state)
        SW_IDLE_STATE:
            begin
                RESET_O     <= 1'b0;
                CS_O        <= 1'b0;
                STROBE_O    <= 1'b0;
            end
        SW_CS_STATE:
            begin
                RESET_O     <= 1'b0;
                CS_O        <= 1'b1;
                STROBE_O    <= 1'b0;
            end
        SW_STROBE_STATE:
            begin
                RESET_O     <= 1'b0;
                CS_O        <= 1'b1;
                STROBE_O    <= 1'b1;
            end
        SW_CS_EN_STATE:
            begin
                RESET_O     <= 1'b0;
                CS_O        <= 1'b1;
                STROBE_O    <= 1'b0;
            end
        SW_CLR_STATE:
            begin
                RESET_O     <= 1'b1;
                CS_O        <= 1'b0;
                STROBE_O    <= 1'b0;
            end
        default:
            begin
                RESET_O     <= 1'b0;
                CS_O        <= 1'b0;
                STROBE_O    <= 1'b0;
            end
    endcase
end

endmodule