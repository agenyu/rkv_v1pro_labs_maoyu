# ------------------------------------------------------------------
# ppa_wave.do -- PPA 主通路（/tb/dut，即 ppa_top）信号分组
#
# 用法：
#   vsim -view wave/lab3_irq_test.wlf -do wave/ppa_wave.do
# 或者在 GUI 里：
#   do wave/ppa_wave.do
# ------------------------------------------------------------------

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {1. APB clock / reset}
add wave -noupdate                 /tb/PCLK
add wave -noupdate                 /tb/apb/PRESETn

add wave -noupdate -divider {2. APB two-phase transfer (SETUP -> ACCESS)}
add wave -noupdate                 /tb/apb/PSEL
add wave -noupdate                 /tb/apb/PENABLE
add wave -noupdate                 /tb/apb/PWRITE
add wave -noupdate -radix hex      /tb/apb/PADDR
add wave -noupdate -radix hex      /tb/apb/PWDATA
add wave -noupdate -radix hex      /tb/apb/PRDATA
add wave -noupdate                 /tb/apb/PREADY
add wave -noupdate                 /tb/apb/PSLVERR

add wave -noupdate -divider {3. CSR mirrors (write goes to *_r, read is combinational)}
add wave -noupdate                 /tb/dut/u_m1/ctrl_enable_r
add wave -noupdate                 /tb/dut/u_m1/cfg_algo_mode_r
add wave -noupdate -radix hex      /tb/dut/u_m1/cfg_type_mask_r
add wave -noupdate -radix unsigned /tb/dut/u_m1/pkt_len_exp_r

add wave -noupdate -divider {4. PKT_MEM write port (8 words)}
add wave -noupdate                 /tb/dut/u_m1/pkt_mem_we_o
add wave -noupdate -radix unsigned /tb/dut/u_m1/pkt_mem_addr_o
add wave -noupdate -radix hex      /tb/dut/u_m1/pkt_mem_wdata_o
add wave -noupdate                 /tb/dut/u_m1/pkt_mem_re_o
add wave -noupdate -radix hex      /tb/dut/u_m2/mem

add wave -noupdate -divider {5. IRQ}
add wave -noupdate                 /tb/dut/u_m1/done_irq_en_r
add wave -noupdate                 /tb/dut/u_m1/err_irq_en_r
add wave -noupdate                 /tb/dut/u_m1/done_irq_sta_r
add wave -noupdate                 /tb/dut/u_m1/err_irq_sta_r
add wave -noupdate                 /tb/dut/irq_o

add wave -noupdate -divider {6. Packet FSM (u_m3)}
add wave -noupdate -radix symbolic /tb/dut/u_m3/state
add wave -noupdate                 /tb/dut/u_m3/busy_o
add wave -noupdate                 /tb/dut/u_m3/done_o
add wave -noupdate -radix unsigned /tb/dut/u_m3/word_idx_r
add wave -noupdate                 /tb/dut/u_m3/issue_read_r
add wave -noupdate                 /tb/dut/u_m3/wait_read_r

configure wave -namecolwidth 260
configure wave -valuecolwidth 90
configure wave -timelineunits ns
WaveRestoreZoom {0 ns} {1200 ns}
