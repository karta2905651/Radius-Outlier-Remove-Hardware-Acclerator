transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+ROR_design  -L xil_defaultlib -L xilinx_vip -L xpm -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_21 -L processing_system7_vip_v1_0_23 -L axi_datamover_v5_1_37 -L axi_sg_v4_1_21 -L axi_dma_v7_1_36 -L xlconstant_v1_1_10 -L proc_sys_reset_v5_0_17 -L smartconnect_v1_0 -L axi_register_slice_v2_1_35 -L xlconcat_v2_1_7 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.ROR_design xil_defaultlib.glbl

do {ROR_design.udo}

run 1000ns

endsim

quit -force
