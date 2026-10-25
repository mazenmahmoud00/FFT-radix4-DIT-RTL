catch {quit -sim}

if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog -sv ../RTL/complex_pack.sv
vlog -sv ../RTL/butterfly.sv
vlog -sv ../RTL/fft_top.sv

vlog -sv ../TB/tb_top_fft.sv

vsim -voptargs=+acc work.tb_top_fft

do ../scripts/wave_top.do

run -all