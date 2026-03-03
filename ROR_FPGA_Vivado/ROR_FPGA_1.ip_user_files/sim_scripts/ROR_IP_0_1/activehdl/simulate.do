transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+ROR_IP_0  -L xil_defaultlib -L xilinx_vip -L xpm -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.ROR_IP_0 xil_defaultlib.glbl

do {ROR_IP_0.udo}

run 1000ns

endsim

quit -force
