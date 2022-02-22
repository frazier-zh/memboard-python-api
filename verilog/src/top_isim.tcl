onerror {resume}

wave add -radix bin CLK
wave add -radix bin /top_tb/uut/ti_clk

divider add "Wire/Trigger data"
wave add -radix bin /top_tb/uut/fifo_rst
wave add -radix bin /top_tb/uut/mem_rst
wave add -radix bin /top_tb/uut/logic_rst
wave add -radix bin /top_tb/uut/logic_en
wave add -radix bin /top_tb/uut/logic_auto

divider add "Pipe data"
wave add -radix hex /top_tb/uut/data16_in
wave add -radix hex /top_tb/uut/data32_in
wave add -radix hex /top_tb/uut/data16_out
wave add -radix hex /top_tb/uut/time16_in

divider add "Memeory"
wave add -radix bin /top_tb/uut/mem_valid
wave add -radix bin /top_tb/uut/mem_read
wave add -radix bin /top_tb/uut/mem_zero
wave add -radix bin /top_tb/uut/mem_ctrl/din_empty
wave add -radix hex /top_tb/uut/mem_ctrl/rd_addr
wave add -radix hex /top_tb/uut/mem_ctrl/wr_addr

divider add "Main data"
wave add -radix hex /top_tb/uut/logic_count
wave add -radix hex /top_tb/uut/logic_state
wave add -radix hex /top_tb/uut/mem_in
wave add -radix hex /top_tb/uut/main_bus
wave add -radix bin /top_tb/uut/data_write
wave add -radix hex /top_tb/uut/data_out

divider add "Clock signals"
wave add -radix hex /top_tb/uut/clock_clr
wave add -radix hex /top_tb/uut/cd_en
wave add -radix hex /top_tb/uut/cd_rdy
wave add -radix hex /top_tb/uut/clock/counter_data
wave add -radix hex /top_tb/uut/time16_write

divider add "Hardward control signals"
wave add -radix bin /top_tb/uut/dev_cs
wave add -radix bin /top_tb/uut/dev_rdy

divider add "Hardware signals"
wave add -radix hex /top_tb/CS_DAC
wave add -radix hex /top_tb/CS_SW1
wave add -radix hex /top_tb/CS_SW2
wave add -radix hex /top_tb/CS_SW3
wave add -radix hex /top_tb/CS_SW4
wave add -radix hex /top_tb/CS_SW5
wave add -radix hex /top_tb/CS_SW6

wave add -radix hex /top_tb/CS_ADC
wave add -radix hex /top_tb/BUSY_ADC
wave add -radix hex /top_tb/DOUTA_ADC
wave add -radix hex /top_tb/DOUTB_ADC
wave add -radix hex /top_tb/SCLK_ADC
wave add -radix hex /top_tb/CNVST_ADC

run 20us;