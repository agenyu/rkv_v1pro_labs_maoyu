# ---------------------------------------------------------------
# wave.do -- 打开 .wlf 之后加载这个脚本, 波形窗口就有信号了
#
# 用法:
#   vsim -view wave/mcdt_burst_test.wlf -do wave.do
# 或者在已经打开的 GUI 里:
#   do wave.do
# ---------------------------------------------------------------

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {clock / reset}
add wave -noupdate /tb/clk
add wave -noupdate /tb/rstn

add wave -noupdate -divider {channel 0 input}
add wave -noupdate -radix hex       /tb/chnl0_if/ch_data
add wave -noupdate                  /tb/chnl0_if/ch_valid
add wave -noupdate                  /tb/chnl0_if/ch_ready
add wave -noupdate -radix unsigned  /tb/chnl0_if/ch_margin

add wave -noupdate -divider {channel 1 input}
add wave -noupdate -radix hex       /tb/chnl1_if/ch_data
add wave -noupdate                  /tb/chnl1_if/ch_valid
add wave -noupdate                  /tb/chnl1_if/ch_ready
add wave -noupdate -radix unsigned  /tb/chnl1_if/ch_margin

add wave -noupdate -divider {channel 2 input}
add wave -noupdate -radix hex       /tb/chnl2_if/ch_data
add wave -noupdate                  /tb/chnl2_if/ch_valid
add wave -noupdate                  /tb/chnl2_if/ch_ready
add wave -noupdate -radix unsigned  /tb/chnl2_if/ch_margin

add wave -noupdate -divider {mcdt output}
add wave -noupdate                  /tb/mcdt_if/mcdt_val
add wave -noupdate -radix hex       /tb/mcdt_if/mcdt_data
add wave -noupdate -radix unsigned  /tb/mcdt_if/mcdt_id

add wave -noupdate -divider {arbiter state}
add wave -noupdate -radix unsigned  /tb/dut/inst_arbiter/c_state
add wave -noupdate -radix unsigned  /tb/dut/inst_arbiter/n_state

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 120
configure wave -signalnamewidth 1
configure wave -timelineunits ns
update

WaveRestoreZoom {0 ns} {20 us}
