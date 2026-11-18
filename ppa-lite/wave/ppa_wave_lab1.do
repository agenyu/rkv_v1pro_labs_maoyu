# ------------------------------------------------------------------
# ppa_wave_lab1.do -- 实验1 专用 M1 实例（/tb/u_lab1_m1）信号分组
#
# lab1_defaults_test / lab1_pkt_mem_test / lab1_pslverr_test 三个用例
# 驱动的是 tb 里单独例化的 apb_slave_if（u_lab1_m1），不是 ppa_top
# 内部的 u_m1。所以实验1的波形要看这一组。
#
# 用法：
#   vsim -view wave/lab1_pkt_mem_test.wlf -do wave/ppa_wave_lab1.do
# ------------------------------------------------------------------

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {1. APB clock / reset}
add wave -noupdate                 /tb/PCLK
add wave -noupdate                 /tb/m1_apb/PRESETn

add wave -noupdate -divider {2. APB two-phase transfer: SETUP(PSEL=1,PENABLE=0) -> ACCESS(PENABLE=1)}
add wave -noupdate                 /tb/m1_apb/PSEL
add wave -noupdate                 /tb/m1_apb/PENABLE
add wave -noupdate                 /tb/m1_apb/PWRITE
add wave -noupdate -radix hex      /tb/m1_apb/PADDR
add wave -noupdate -radix hex      /tb/m1_apb/PWDATA
add wave -noupdate -radix hex      /tb/m1_apb/PRDATA
add wave -noupdate                 /tb/m1_apb/PREADY
add wave -noupdate                 /tb/m1_apb/PSLVERR

add wave -noupdate -divider {3. CSR reset values (CTRL / CFG / STATUS)}
add wave -noupdate                 /tb/u_lab1_m1/ctrl_enable_r
add wave -noupdate                 /tb/u_lab1_m1/cfg_algo_mode_r
add wave -noupdate -radix hex      /tb/u_lab1_m1/cfg_type_mask_r
add wave -noupdate                 /tb/u_lab1_m1/done_irq_en_r
add wave -noupdate                 /tb/u_lab1_m1/err_irq_en_r

add wave -noupdate -divider {4. PKT_MEM write port: we / addr / wdata (8 words)}
add wave -noupdate                 /tb/u_lab1_m1/pkt_mem_we_o
add wave -noupdate -radix unsigned /tb/u_lab1_m1/pkt_mem_addr_o
add wave -noupdate -radix hex      /tb/u_lab1_m1/pkt_mem_wdata_o
add wave -noupdate                 /tb/u_lab1_m1/pkt_mem_re_o
add wave -noupdate -radix hex      /tb/m1_apb/pkt_mem_rdata_stub

add wave -noupdate -divider {5. RES_* stub inputs -> APB read path}
add wave -noupdate -radix hex      /tb/m1_apb/res_pkt_len_stub
add wave -noupdate -radix hex      /tb/m1_apb/res_pkt_type_stub
add wave -noupdate -radix hex      /tb/m1_apb/res_payload_sum_stub
add wave -noupdate -radix hex      /tb/m1_apb/res_payload_xor_stub

configure wave -namecolwidth 280
configure wave -valuecolwidth 90
configure wave -timelineunits ns
WaveRestoreZoom {0 ns} {900 ns}
