onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color Gold /tb_usb_ahb_transceiver/clk
add wave -noupdate -color Gold /tb_usb_ahb_transceiver/n_rst
add wave -noupdate -color Maroon /tb_usb_ahb_transceiver/testname
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/dp_in
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/dm_in
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/hsel
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/hwrite
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/hready
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/haddr
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/htrans
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/hsize
add wave -noupdate -expand -group INPUTS /tb_usb_ahb_transceiver/hwdata
add wave -noupdate -expand -group AHB_TL_OUTS -color {Dark Orchid} /tb_usb_ahb_transceiver/hrdata
add wave -noupdate -expand -group AHB_TL_OUTS -color {Dark Orchid} /tb_usb_ahb_transceiver/hresp
add wave -noupdate -expand -group AHB_TL_OUTS -color {Dark Orchid} /tb_usb_ahb_transceiver/d_mode
add wave -noupdate -expand -group TX_TL_OUTS /tb_usb_ahb_transceiver/decode_nrzi/eop
add wave -noupdate -expand -group TX_TL_OUTS /tb_usb_ahb_transceiver/decode_nrzi/pdp
add wave -noupdate -expand -group TX_TL_OUTS -radix unsigned /tb_usb_ahb_transceiver/decode_nrzi/i
add wave -noupdate -expand -group TX_TL_OUTS -color Thistle /tb_usb_ahb_transceiver/dp_out
add wave -noupdate -expand -group TX_TL_OUTS -color Thistle /tb_usb_ahb_transceiver/dm_out
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/memarr
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/buffer_occupancy
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/store_rx_packet_data
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/get_tx_packet_data
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/flush
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/clear
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/store_tx_data
add wave -noupdate -group FIFO_SIGS -color Aquamarine /tb_usb_ahb_transceiver/DUT/FIFO/get_rx_data
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/tx_packet
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/tx_transfer_active
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/tx_error
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/rollover_flag_t
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/DP_OUT
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/DM_OUT
add wave -noupdate -expand -group TX_SIGS -color {Violet Red} /tb_usb_ahb_transceiver/DUT/TX_MODULE/state
add wave -noupdate -group RX_SIGS -color Orange /tb_usb_ahb_transceiver/DUT/RX_MODULE/rx_packet
add wave -noupdate -group RX_SIGS -color Orange /tb_usb_ahb_transceiver/DUT/RX_MODULE/rx_data_ready
add wave -noupdate -group RX_SIGS -color Orange /tb_usb_ahb_transceiver/DUT/RX_MODULE/rx_transfer_active
add wave -noupdate -group RX_SIGS -color Orange /tb_usb_ahb_transceiver/DUT/RX_MODULE/rx_error
add wave -noupdate -group RX_SIGS -color Orange /tb_usb_ahb_transceiver/DUT/RX_MODULE/state
add wave -noupdate -group AHB_SIGS -color {Blue Violet} /tb_usb_ahb_transceiver/DUT/AHB_SUB/reg_status
add wave -noupdate -group AHB_SIGS -color {Blue Violet} /tb_usb_ahb_transceiver/DUT/AHB_SUB/reg_tx_ctrl
add wave -noupdate -group AHB_SIGS -color {Blue Violet} /tb_usb_ahb_transceiver/DUT/AHB_SUB/reg_flush_ctrl
add wave -noupdate -group AHB_SIGS -color {Blue Violet} /tb_usb_ahb_transceiver/DUT/AHB_SUB/reg_haddr
add wave -noupdate -group AHB_SIGS -color {Blue Violet} /tb_usb_ahb_transceiver/DUT/AHB_SUB/reg_wen
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {10820240 ps} 0}
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
WaveRestoreZoom {0 ps} {2939648 ps}
