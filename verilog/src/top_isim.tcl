onerror {resume}

divider add "Wire/Trigger Data"
wave add -radix hex /top_tb/uut/fifo_rst
wave add -radix hex /top_tb/uut/mem_rst
wave add -radix hex /top_tb/uut/logic_rst
wave add -radix hex /top_tb/uut/logic_en
wave add -radix hex /top_tb/uut/logic_rdy_trig

divider add "Pipe Data"
wave add -radix hex /top_tb/uut/data16_in
wave add -radix hex /top_tb/uut/data32_in
wave add -radix hex /top_tb/uut/data16_out
wave add -radix hex /top_tb/uut/time16_in

divider add "Hardward control signals"
wave add -radix hex /top_tb/uut/adc_cs
wave add -radix hex /top_tb/uut/adc_rdy
wave add -radix hex /top_tb/uut/dac_cs
wave add -radix hex /top_tb/uut/dac_rdy
wave add -radix hex /top_tb/uut/switch_cs
wave add -radix hex /top_tb/uut/switch_rdy
wave add -radix hex /top_tb/uut/timer_cs
wave add -radix hex /top_tb/uut/timer_rdy

divider add "Clock signals"
wave add -radix hex /top_tb/uut/clock_en
wave add -radix hex /top_tb/uut/cd_en
wave add -radix hex /top_tb/uut/cd_rdy

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