// -----------------------------------------------------------------------------
//
// Copyright 2012(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//  - Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//  - Neither the name of Analog Devices, Inc. nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//  - The use of this software may or may not infringe the patent rights
//    of one or more patent holders.  This license does not release you
//    from the requirement that you obtain separate licenses from these
//    patent holders to use this software.
//  - Use of the software either in source or binary form, must be run
//    on or directly connected to an Analog Devices Inc. component.
//
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY
// AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// -----------------------------------------------------------------------------
// FILE NAME : AD7367.v
// MODULE NAME : AD7367
// AUTHOR : atofan
// AUTHOR'S EMAIL : adrian.costina@analog.com
// -----------------------------------------------------------------------------
// SVN REVISION: 468
// -----------------------------------------------------------------------------
// KEYWORDS : AD7367
// -----------------------------------------------------------------------------
// PURPOSE : Driver for the AD7367
// -----------------------------------------------------------------------------
// REUSE ISSUES
// Reset Strategy      :
// Clock Domains       : FPGA_CLK_I 100 MHz
// Critical Timing     :
// Test Features       :
// Asynchronous I/F    :
// Instantiations      :
// Synthesizable (y/n) : Y
// Target Device       :
// Other               : The driver is intended to be used with AD7367SDZ
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype wire

//------------------------------------------------------------------------------
//----------- Module Declaration -----------------------------------------------
//------------------------------------------------------------------------------

module AD7367
    (
        // Clock and Reset Signals
        input               FPGA_CLK_I,         // 100 MHz
		input               EN_I,               // Enable Signal, Active High
        input               RESET_N_I,          // Reset Signal, Active Low

        // Select Read Mode
        input               READ_MODE_I,        // Select Read Mode (0 dual, 1 single line)
        output              IDLE_O,             // Idle State
        
        // Data Interface
        output reg          DATA_RD_READY_O,    // Signals when new data is available
        output reg  [31:0]  DATA_O,             // Data Output from ADC

        // AD7367 Control Signals
        input               DOUTA_I,            // AD7367 DoutA
        input               DOUTB_I,            // AD7367 DoutB
        input               BUSY_I,             // AD7367 BUSY
        output reg          SCLK_O,             // SCLK
        output reg          CNVST_N_O,          // CNVST
        output reg          CS_N_O              // CS
    );

//------------------------------------------------------------------------------
//----------- Registers Declarations -------------------------------------------
//------------------------------------------------------------------------------

reg [7:0]   present_state;
reg [7:0]   next_state;

reg         sync_en;
reg         div_by_4;
reg         sync_read_mode;
reg [27:0]  adc_sclk_cnt;

reg [13:0]  data_a_s;
reg [13:0]  data_b_s;
reg [27:0]  data_mix_s;

reg [31:0]  cycle_cnt;

//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
// ADC States

parameter ADC_IDLE_STATE            = 8'b00000001;
parameter ADC_START_CNV_STATE       = 8'b00000010;
parameter ADC_WAIT_BUSY_LOW_STATE   = 8'b00000100;
parameter ADC_CS_LOW_STATE          = 8'b00001000;
parameter ADC_RW_DATA_STATE         = 8'b00010000;
parameter ADC_CS_EN_STATE           = 8'b00100000;
parameter ADC_TRANSFER_DATA_STATE   = 8'b01000000;
parameter ADC_WAIT_END_STATE        = 8'b10000000;

// Number of SCLK Pulses to be applied
parameter ADC_SCLK_PERIODS_DUAL     = 14'h2000;
parameter ADC_SCLK_PERIODS_SINGLE   = 28'h8000000;

// ADC Timing
parameter real      FPGA_CLOCK_FREQ = 100 ;
parameter real      CYCLE_TIME      = 2;
parameter [31:0]    ADC_CYCLE_TIME  = FPGA_CLOCK_FREQ * CYCLE_TIME - 2;

//------------------------------------------------------------------------------
//----------- Assign/Always Blocks ---------------------------------------------
//------------------------------------------------------------------------------
assign IDLE_O = (present_state == ADC_IDLE_STATE);

// Conversion counter
always @(posedge FPGA_CLK_I)
begin
    if(present_state == ADC_IDLE_STATE)
    begin
        cycle_cnt  <= ADC_CYCLE_TIME;
    end
    else if (cycle_cnt > 32'h0)
    begin
        cycle_cnt  <= cycle_cnt - 32'd1;
    end
end

// Shift in serial data on rising edge of SCLK
always @(negedge SCLK_O )
begin
    data_a_s    <= { data_a_s[12:0], DOUTA_I };
    data_b_s    <= { data_b_s[12:0], DOUTB_I };
    data_mix_s  <= { data_mix_s[26:0], DOUTA_I} ;
end

always @(posedge FPGA_CLK_I)
begin
    if (div_by_4 == 1'b1 && SCLK_O == 1'b1)
    begin
        adc_sclk_cnt    <= adc_sclk_cnt >> 1;
    end
    else if (sync_en == 1'b0)
    begin
        if ( sync_read_mode == 1'b0 )
        begin
            adc_sclk_cnt    <= ADC_SCLK_PERIODS_DUAL;
        end
        else
        begin
            adc_sclk_cnt    <= ADC_SCLK_PERIODS_SINGLE;
        end
    end
end

//SCLK generation
always @(posedge FPGA_CLK_I)
begin
    if (RESET_N_I == 1'b0)
    begin
        div_by_4 <= 1'b0;
        SCLK_O   <= 1'b1;
    end
    else
    begin
        if (sync_en == 1'b1 )
        begin
            div_by_4 <= ~div_by_4;
            if ( div_by_4 == 1'b1 )
            begin
                SCLK_O              <= ~SCLK_O;
            end
            else
            begin
                SCLK_O  <= SCLK_O;
            end
        end
        else
        begin
            SCLK_O              <= 1'b1;
        end
    end
end

// Register States
always @(posedge FPGA_CLK_I)
begin
    if(RESET_N_I == 1'b0)
    begin
        present_state <= ADC_IDLE_STATE;
    end
    else
    begin
        present_state <= next_state;
    end
end

// State switching logic
always @ ( present_state, cycle_cnt, adc_sclk_cnt, BUSY_I, EN_I )
begin
    next_state = present_state;
    case(present_state)
        ADC_IDLE_STATE:
            begin
                if ( EN_I == 1'b1 )
				begin
                    next_state = ADC_START_CNV_STATE;
                end
            end
        ADC_START_CNV_STATE:
            begin
                if ( BUSY_I == 1'b1 )
                begin
                    next_state = ADC_WAIT_BUSY_LOW_STATE;
                end
            end
        ADC_WAIT_BUSY_LOW_STATE:
            begin
                if ( BUSY_I == 1'b0 )
                begin
                    next_state = ADC_CS_LOW_STATE;
                end
            end
        ADC_CS_LOW_STATE:
        begin
            next_state = ADC_RW_DATA_STATE;
        end
        ADC_RW_DATA_STATE:
            begin
                if ( adc_sclk_cnt == 5'h0 )
                begin
                    next_state = ADC_CS_EN_STATE;
                end
            end
        ADC_CS_EN_STATE:
            begin
                next_state = ADC_TRANSFER_DATA_STATE;
            end
        ADC_TRANSFER_DATA_STATE:
            begin
                next_state = ADC_WAIT_END_STATE;
            end
        ADC_WAIT_END_STATE:
            begin
                if ( cycle_cnt == 32'h0 )
                begin
                    next_state = ADC_IDLE_STATE;
                end
            end
        default:
            begin
                next_state = ADC_IDLE_STATE;
            end
    endcase
end

// State Output Logic
always @(posedge FPGA_CLK_I)
begin
    case(present_state)
        ADC_IDLE_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b1;
        end
        ADC_START_CNV_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b0;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b1;
        end
        ADC_WAIT_BUSY_LOW_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b1;
        end
        ADC_CS_LOW_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b0;
        end
        ADC_RW_DATA_STATE:
        begin
            sync_en         <= 1'b1;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b0;
        end
        ADC_CS_EN_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b0;
            DATA_O          <= sync_read_mode ? {2'h0,data_mix_s[25:14],2'h0,data_mix_s[13:0] } : {2'h0, data_a_s, 2'h0, data_b_s} ;
        end
        ADC_TRANSFER_DATA_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b1;
            CS_N_O          <= 1'b0;
        end
        ADC_WAIT_END_STATE:
        begin
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
            CS_N_O          <= 1'b1;
            sync_read_mode  <= READ_MODE_I;
        end
        default:
        begin
            CS_N_O          <= 1'b1;
            sync_en         <= 1'b0;
            CNVST_N_O       <= 1'b1;
            DATA_RD_READY_O <= 1'b0;
        end
    endcase
end
endmodule

