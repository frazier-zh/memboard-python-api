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
        input               reset_i,
        output              idle_o,
        
        // Direct Access
        output reg          direct_data_ready_o,
        output reg [15:0]   direct_data_o,
        
        // FIFO Interface
        input               fifo_empty_n_i,
        input [15:0]        fifo_data_i,
        output reg          fifo_rd_o,
        
        // MUX Interface
        output reg [23:0]   mux_ins_o,
        output reg          mux_en_o,
        input               mux_idle_i,
        
        input               mux_data_ready_i,
        input [15:0]        mux_data_i
    );
    
//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
localparam [15:0] INS_NULL      = 16'b0;

//--------------------------------------
//--------- Instrcution Format ---------
//---- OP[2:0] IREG(0/1) DATA[11:0] ----
//--------------------------------------
localparam [2:0] OP_NULL        = 3'b000;       // Null Operation
localparam [2:0] OP_SETSR       = 3'b001;       // Set  SR[IREG]=DATA
localparam [2:0] OP_LDSR        = 3'b010;       // Load SR[IREG]<-DATA
localparam [2:0] OP_MUX         = 3'b011;       // Call MUX {DATA, 0}
localparam [2:0] OP_MUXE        = 3'b100;       // Call MUX {DATA, SR[IREG]}
localparam [2:0] OP_WAIT        = 3'b101;       // Wait SR[IREG]

//------------------------------------------------------------------------------
//----------- INS Fetch Assign/Always Blocks -----------------------------------
//------------------------------------------------------------------------------
reg [15:0]          INS;

reg                 ins_rdy;
wire                ins_stall;
assign ins_stall    = timer_stall;

// INS Fetch
always @(negedge fpga_clk_i)
begin
    ins_rdy         <= 1'b0;
    fifo_rd_o       <= 1'b0;
    if (reset_i == 1'b1)
    begin
        INS         <= INS_NULL;
    end
    else if ((ins_stall == 1'b0) && (fifo_empty_n_i == 1'b0))
    begin
        ins_rdy     <= 1'b1;
        fifo_rd_o   <= 1'b1;
        INS         <= fifo_data_i; 
    end
    else
    begin
        INS         <= INS_NULL;
    end
end
assign idle_o       = ~ins_stall & ~ins_rdy;

//------------------------------------------------------------------------------
//----------- INS Decode Assign/Always Blocks ----------------------------------
//------------------------------------------------------------------------------
wire [2:0]          OP;
wire                IREG;
wire [11:0]         DATA;
assign {OP, IREG, DATA} = INS;

wire [47:0]         sr;
reg                 sr_ld;
reg                 sr_set;
reg                 timer_en;
reg                 rd_reg_en;

always @(posedge fpga_clk_i)
begin
    sr_ld       <= 1'b0;
    sr_set      <= 1'b0;
    mux_en_o    <= 1'b0;
    timer_en    <= 1'b0;
    reg_oe_o    <= 1'b0;
    rd_reg_en   <= 1'b0;
    if (reset_i == 1'b1)
    begin
        timer_data  <= 48'b0;
        mux_ins_o   <= 24'b0;
        reg_addr_o  <= 8'b0;
    end
    else if (ins_rdy == 1'b1)
    begin
        case (OP)
            OP_NULL:
                begin
                end
            OP_SETSR:
                begin
                    sr_set      <= 1'b1;
                end
            OP_LDSR:
                begin
                    sr_ld       <= 1'b1;
                end
            OP_MUX:
                begin
                    mux_ins_o   <= {DATA, 12'b0};
                    mux_en_o    <= 1'b1;
                end
            OP_MUXE:
                begin
                    mux_ins_o   <= {DATA, sr[11:0]};
                    mux_en_o    <= 1'b1;
                end
            OP_WAIT:
                begin
                    timer_data  <= sr;
                    timer_en    <= 1'b1;
                end
            OP_LDREG:
                begin
                    reg_addr_o  <= DATA[7:0];
                    reg_data    <= sr[15:0];
                    reg_oe_o    <= 1'b1;
                end
            OP_RDREG:
                begin
                    reg_addr_o  <= DATA[7:0];
                    rd_reg_en   <= 1'b1;
                end
        endcase
    end
end

//------------------------------------------------------------------------------
//----------- Shift Register Assign/Always Blocks ------------------------------
//------------------------------------------------------------------------------
assign sr           = (IREG == 1'b0) ? sr0 : sr1;

// Register 0
wire                sr0_ld  = (IREG == 1'b0) ? sr_ld : 1'b0;
wire                sr0_set = (IREG == 1'b0) ? sr_set : 1'b0;
reg [47:0]          sr0;
always @(negedge fpga_clk_i)
begin
    sr0 <= sr0;
    if (reset_i == 1'b1)
    begin
        sr0 <= 48'b0;
    end
    else if (sr0_set == 1'b1)
    begin
        sr0 <= {36'b0, DATA};
    end
    else if (sr0_ld == 1'b1)
    begin
        sr0 <= {sr0[35:0], DATA};
    end
end

wire                sr1_ld  = (IREG == 1'b1) ? sr_ld : 1'b0;
wire                sr1_set = (IREG == 1'b1) ? sr_set : 1'b0;
reg [47:0]          sr1;
always @(negedge fpga_clk_i)
begin
    sr1 <= sr1;
    if (reset_i == 1'b1)
    begin
        sr1 <= 48'b0;
    end
    else if (sr1_set == 1'b1)
    begin
        sr1 <= {36'b0, DATA};
    end
    else if (sr1_ld == 1'b1)
    begin
        sr1 <= {sr1[35:0], DATA};
    end
end

//------------------------------------------------------------------------------
//----------- Direct Data Access -----------------------------------------------
//------------------------------------------------------------------------------
reg rd_reg_en_dly;
always @(posedge fpga_clk_i)
    rd_reg_en_dly <= rd_reg_en;

always @(posedge fpga_clk_i)
begin
    direct_data_ready_o <= 1'b0;
    direct_data_o       <= direct_data_o;
    if (reset_i == 1'b1)
    begin
        direct_data_o   <= 16'b0;
    end
    else if (mux_data_ready_i == 1'b1)
    begin
        direct_data_ready_o <= 1'b1;
        direct_data_o   <= mux_data_i;
    end
    else if (rd_reg_en_dly == 1'b1)
    begin
        direct_data_ready_o <= 1'b1;
        direct_data_o   <= reg_io;
    end
end

//------------------------------------------------------------------------------
//----------- Timer Assign/Always Blocks ---------------------------------------
//------------------------------------------------------------------------------
wire [47:0]         timer_q;
reg [47:0]          timer_data;
reg                 timer_stall;

BC48 timer
    (
        .clk(fpga_clk_i),
        .l(48'h1),
        .load(~timer_stall),
        .q(timer_q)
    );
   
always @(negedge fpga_clk_i)
begin
    if (reset_i == 1'b1)
    begin
        timer_stall <= 1'b0;
    end
    else if (timer_en == 1'b1)
    begin
        timer_stall <= 1'b1;
    end
    else if ((timer_stall == 1'b1) && (timer_q == timer_data))
    begin
        timer_stall <= 1'b0;
    end
end


endmodule
