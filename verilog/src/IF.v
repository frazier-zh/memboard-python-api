//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:31:34 07/04/2022 
// Design Name: 
// Module Name:    IF 
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

module IF
    (
        // Clock And Reset Signals
        input               fpga_clk_i,             // 100MHz
        input               reset_n_i,
        
        // FIFO Interface
        input               fifo_empty_n_i,
        input [31:0]        fifo_data_i,
        output reg          fifo_rd_o,
        
        // MUX Interface
        output [27:0]       mux_data_o,
        output reg          mux_en_o,
        input               mux_idle_i
    );
    
//------------------------------------------------------------------------------
//----------- Registers Declarations -------------------------------------------
//------------------------------------------------------------------------------
reg [2:0]   present_state;
reg [2:0]   next_state;

//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
parameter IDLE_STATE            = 3'b001;
parameter EXEC_STATE            = 3'b010;
parameter WAIT_STATE            = 3'b100;

parameter INS_NULL              = {32{1'b0}};
parameter TIMER_MAX             = {48{1'b1}};

//------------------------------------------------------------------------------
//----------- Assign/Always Blocks ---------------------------------------------
//------------------------------------------------------------------------------
reg [31:0]          ins;
assign mux_data_o   = ins[27:0];

wire [27:0]         data;
assign data         = ins[27:0];

wire                flag_wait;
wire                flag_loadh;
assign {flag_wait, flag_loadh} = ins[29:28];

reg                 timer_en;

// EX Register States
always @(posedge fpga_clk_i)
begin
    if (reset_n_i == 1'b0)
    begin
        present_state <= IDLE_STATE;
    end
    else
    begin
        present_state <= next_state;
    end
end

// EX
always @(present_state, fifo_empty_n_i, timer_rdy, flag_wait)
begin
    next_state = present_state;
    case (present_state)
        IDLE_STATE:
            begin
                if (fifo_empty_n_i == 1'b0)
                begin
                    next_state = EXEC_STATE;
                end
            end
         EXEC_STATE:
            begin
                if (flag_wait == 1'b1)
                begin
                    next_state = WAIT_STATE;
                end
                else
                begin
                    next_state = IDLE_STATE;
                end
            end
         WAIT_STATE:
            begin
                if (timer_rdy == 1'b1)
                begin
                    next_state = IDLE_STATE;
                end
            end
         default:
            begin
                next_state = IDLE_STATE;
            end
    endcase
end

always @(posedge fpga_clk_i)
begin
    case (present_state)
        IDLE_STATE:
        begin
            ins             <= fifo_data_i;
            fifo_rd_o       <= 1'b0;
            timer_en        <= 1'b0;
            mux_en_o        <= 1'b0;
        end
        EXEC_STATE:
        begin
            fifo_rd_o       <= 1'b1;
            timer_en        <= 1'b0;
            mux_en_o        <= 1'b0;
            
            if (flag_wait == 1'b1)
            begin
                if (flag_loadh == 1'b1)
                begin
                    timer_target[47:24] <= data[23:0];
                end
                else
                begin
                    timer_target[23:0]  <= data[23:0];
                end
            end
            else
            begin
                mux_en_o    <= 1'b1;
                timer_target            <= TIMER_MAX;
            end
        end
        WAIT_STATE:
        begin
            fifo_rd_o       <= 1'b0;
            timer_en        <= 1'b1;
            mux_en_o        <= 1'b0;
        end
        default:
        begin
            ins             <= INS_NULL;
            fifo_rd_o       <= 1'b0;
            timer_en        <= 1'b0;
            mux_en_o        <= 1'b0;
        end
    endcase
end

//------------------------------------------------------------------------------
//----------- Timer Assign/Always Blocks ---------------------------------------
//------------------------------------------------------------------------------
wire [47:0]         timer_q;
reg [47:0]          timer_target;

wire                timer_clr;
assign timer_clr    = ~time_en;
BC48 timer
    (
        .clk(fpga_clk_i),
        .sclr(timer_clr),
        .q(timer_q)
    );
   
wire                timer_rdy;
assign timer_rdy    = (timer_en) ? (timer_q == timer_target) : 1'b0;


endmodule
