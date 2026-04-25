onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group Systtem -color Orange /tb_usb_rx/DUT/clk
add wave -noupdate -expand -group Systtem -color Orange /tb_usb_rx/DUT/n_rst
add wave -noupdate -expand -group Inputs -color {Steel Blue} /tb_usb_rx/DUT/dp_in
add wave -noupdate -expand -group Inputs -color {Steel Blue} /tb_usb_rx/DUT/dm_in
add wave -noupdate -expand -group Inputs -color {Steel Blue} /tb_usb_rx/DUT/buffer_occupancy
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/rx_packet
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/rx_data_ready
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/rx_transfer_active
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/rx_error
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/store_rx_packet_data
add wave -noupdate -expand -group Outputs /tb_usb_rx/DUT/flush
add wave -noupdate -expand -group Outputs -color Plum /tb_usb_rx/DUT/rx_packet_data
add wave -noupdate /tb_usb_rx/test_name
add wave -noupdate -expand -group NRZI /tb_usb_rx/DUT/nrzi/edge_state
add wave -noupdate -expand -group NRZI /tb_usb_rx/DUT/nrzi/n_edge_state
add wave -noupdate -expand -group NRZI -color Gray90 /tb_usb_rx/DUT/d_orig
add wave -noupdate -expand -group NRZI /tb_usb_rx/DUT/edge_detected
add wave -noupdate -expand -group NRZI /tb_usb_rx/DUT/nrzi/hold_edge
add wave -noupdate -expand -group NRZI -color {Yellow Green} /tb_usb_rx/DUT/nrzi/state
add wave -noupdate -expand -group NRZI -color {Yellow Green} /tb_usb_rx/DUT/nrzi/next_state
add wave -noupdate -expand -group NRZI -color Magenta /tb_usb_rx/DUT/nrzi/eop1
add wave -noupdate -expand -group NRZI -color Magenta /tb_usb_rx/DUT/nrzi/eop2
add wave -noupdate -expand -group NRZI -color Magenta /tb_usb_rx/DUT/nrzi/eop3
add wave -noupdate -expand -group NRZI -color Magenta /tb_usb_rx/DUT/eop_detected
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/count_enable_timer
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/shift_strobe
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/eight_bit_done
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/seven_bit_done
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/four_bit_done
add wave -noupdate -expand -group Timer /tb_usb_rx/DUT/five_bit_done
add wave -noupdate -expand -group States /tb_usb_rx/DUT/state
add wave -noupdate -expand -group States /tb_usb_rx/DUT/next_state
add wave -noupdate -expand -group Registers /tb_usb_rx/DUT/out0
add wave -noupdate -expand -group Registers /tb_usb_rx/DUT/out1
add wave -noupdate -expand -group Registers /tb_usb_rx/DUT/out2
add wave -noupdate -group {REG Support} /tb_usb_rx/DUT/valid1
add wave -noupdate -group {REG Support} /tb_usb_rx/DUT/valid2
add wave -noupdate -expand -group {bit stuffing} /tb_usb_rx/DUT/count6
add wave -noupdate -expand -group {bit stuffing} /tb_usb_rx/DUT/stuff_error
add wave -noupdate -expand -group {bit stuffing} /tb_usb_rx/DUT/n_count6
add wave -noupdate -expand -group {bit stuffing} /tb_usb_rx/DUT/valid_bit
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {24835000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {28507500 ps}
