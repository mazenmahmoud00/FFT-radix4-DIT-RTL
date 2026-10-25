onerror {resume}
quietly WaveActivateNextPane {} 0

# ==========================================
# 0. Define Custom Fixed-Point Radices
# ==========================================
catch {radix delete Q412}
catch {radix delete Q214}

# Q4.12 Format: Signed fixed-point with 12 fractional bits
radix define Q412 -fixed -signed -fraction 12

# Q2.14 Format: Signed fixed-point with 14 fractional bits
radix define Q214 -fixed -signed -fraction 14


# ==========================================
# 1. System Clocks & Controls (Orange & Red)
# ==========================================
add wave -divider -height 24 { Clocks & Controls }
add wave -noupdate -color {#FF9900} -label {CLK}          /tb_top_fft/clk
add wave -noupdate -color {#FF3333} -label {RST_N}        /tb_top_fft/rst_n

# ==========================================
# 2. Input Data - Top Level (Cyan)
# ==========================================
add wave -divider -height 24 { FFT Input (x) - Q4.12 }
add wave -noupdate -color {#00FFFF} -label {x [0:63]} -radix Q412 /tb_top_fft/x

# ==========================================
# 3. Pipeline Intermediates (Medium Orchid)
# ==========================================
add wave -divider -height 24 { Pipeline Stages }
add wave -noupdate -color {#BA55D3} -label {x_shuffled}  -radix Q412 /tb_top_fft/dut/x_shuffled
add wave -noupdate -color {#DA70D6} -label {s1_reg}      -radix Q412 /tb_top_fft/dut/s1_reg
add wave -noupdate -color {#EE82EE} -label {s2_reg}      -radix Q412 /tb_top_fft/dut/s2_reg

# ==========================================
# 4. Twiddle Factors ROM (Yellow/Gold)
# ==========================================
add wave -divider -height 24 { Twiddle ROM - Q2.14 }
add wave -noupdate -color {#EEDD82} -label {twiddle_rom [0:63]} -radix Q214 /tb_top_fft/dut/twiddle_rom

# ==========================================
# 5. Output Data - Top Level (Spring Green)
# ==========================================
add wave -divider -height 24 { FFT Output (y) - Q4.12 }
add wave -noupdate -color {#00FF7F} -label {y [0:63]} -radix Q412 /tb_top_fft/y


# ==========================================
# Wave Window UI Layout & Configuration
# ==========================================
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 140
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 8
configure wave -childrowmargin 4
configure wave -gridoffset 0
configure wave -gridperiod 10
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {600 ns}
