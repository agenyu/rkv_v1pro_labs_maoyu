# ------------------------------------------------------------------
# ppa_wave_m3.do -- 实验2 用的独立 M3 通路（/tb/u_m3_standalone）
#
# lab2_valid_test / lab2_errors_test 通过 m3vif 驱动 standalone 的
# packet_proc_core，不经过 APB，所以波形看这一组。
#
# 用法：
#   vsim -view wave/lab2_valid_test.wlf -do wave/ppa_wave_m3.do
# ------------------------------------------------------------------

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {1. clock / reset}
add wave -noupdate                 /tb/PCLK
add wave -noupdate                 /tb/m3/rst_n

add wave -noupdate -divider {2. start / configuration}
add wave -noupdate                 /tb/m3/start_i
add wave -noupdate                 /tb/m3/algo_mode_i
add wave -noupdate -radix hex      /tb/m3/type_mask_i
add wave -noupdate -radix unsigned /tb/m3/exp_pkt_len_i

add wave -noupdate -divider {3. FSM}
add wave -noupdate -radix symbolic /tb/u_m3_standalone/state
add wave -noupdate                 /tb/u_m3_standalone/issue_read_r
add wave -noupdate                 /tb/u_m3_standalone/wait_read_r
add wave -noupdate -radix unsigned /tb/u_m3_standalone/word_idx_r
add wave -noupdate                 /tb/u_m3_standalone/busy_o
add wave -noupdate                 /tb/u_m3_standalone/done_o

add wave -noupdate -divider {4. SRAM read port (word 0 -> 7)}
add wave -noupdate                 /tb/u_m3_standalone/mem_rd_en_o
add wave -noupdate -radix unsigned /tb/u_m3_standalone/mem_rd_addr_o
add wave -noupdate -radix hex      /tb/u_m3_standalone/mem_rd_data_i
add wave -noupdate -radix hex      /tb/m3/mem_words

add wave -noupdate -divider {5. results}
add wave -noupdate -radix unsigned /tb/u_m3_standalone/res_pkt_len_o
add wave -noupdate -radix hex      /tb/u_m3_standalone/res_pkt_type_o
add wave -noupdate -radix hex      /tb/u_m3_standalone/res_payload_sum_o
add wave -noupdate -radix hex      /tb/u_m3_standalone/res_payload_xor_o

add wave -noupdate -divider {6. checks (format_ok / three error sources)}
add wave -noupdate                 /tb/u_m3_standalone/format_ok_o
add wave -noupdate                 /tb/u_m3_standalone/length_error_o
add wave -noupdate                 /tb/u_m3_standalone/type_error_o
add wave -noupdate                 /tb/u_m3_standalone/chk_error_o

configure wave -namecolwidth 280
configure wave -valuecolwidth 90
configure wave -timelineunits ns
WaveRestoreZoom {0 ns} {900 ns}
