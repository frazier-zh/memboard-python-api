onerror {resume}

wave add -radix bin CLK0
wave add -radix bin CLK1
wave add -radix bin /Top_tb/uut/ti_clk

divider add "Trigger"
wave add -radix bin /Top_tb/uut/trigger_in
wave add -radix bin /Top_tb/uut/direct_data_ready

divider add "Data"
wave add -radix bin /Top_tb/uut/pipe80_write
wave add -radix hex /Top_tb/uut/pipe80_dataout
wave add -radix bin /Top_tb/uut/fifo_in_empty
wave add -radix hex /Top_tb/uut/fifo_in_dout
wave add -radix bin /Top_tb/uut/fifo_in_rd_en
wave add -radix hex /Top_tb/uut/fifo_out_rd_data_count
wave add -radix hex /Top_tb/uut/direct_data

divider add "IF"
wave add -radix bin /Top_tb/uut/if_main/ins_rdy
wave add -radix bin /Top_tb/uut/if_main/ins_stall
wave add -radix bin /Top_tb/uut/if_main/INS
wave add -radix hex /Top_tb/uut/if_main/sr0
wave add -radix hex /Top_tb/uut/if_main/sr1
wave add -radix bin /Top_tb/uut/mux_en

divider add "Register"
wave add -radix hex /Top_tb/uut/reg_addr
wave add -radix hex /Top_tb/uut/reg_data
wave add -radix hex /Top_tb/uut/REG_ADC_CLK_DIV
wave add -radix bin /Top_tb/uut/REG_ADC_READ_MODE
wave add -radix bin /Top_tb/uut/REG_ADC_TRIG_MODE
wave add -radix bin /Top_tb/uut/REG_ADC_ADDR
wave add -radix bin /Top_tb/uut/ADC_IDLE
wave add -radix bin /Top_tb/uut/DAC_IDLE
wave add -radix bin /Top_tb/uut/SW_IDLE

divider add "Clock"
wave add -radix hex /Top_tb/uut/clock_q

divider add "Hardware signals"
wave add -radix hex /Top_tb/CS_DAC
wave add -radix hex /Top_tb/CS_SW1
wave add -radix hex /Top_tb/CS_SW2
wave add -radix hex /Top_tb/CS_SW3
wave add -radix hex /Top_tb/CS_SW4
wave add -radix hex /Top_tb/CS_SW5
wave add -radix hex /Top_tb/CS_SW6
wave add -radix hex /Top_tb/CNVST_ADC
wave add -radix hex /Top_tb/BUSY_ADC
wave add -radix hex /Top_tb/CS_ADC
wave add -radix hex /Top_tb/SCLK_ADC