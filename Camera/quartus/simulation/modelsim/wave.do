onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /testbench/DUT/nReset
add wave -noupdate -radix hexadecimal /testbench/DUT/Clk
add wave -noupdate -radix hexadecimal /testbench/DUT/AS_Start
add wave -noupdate -radix hexadecimal /testbench/DUT/AS_Start_Address
add wave -noupdate -radix hexadecimal /testbench/DUT/AS_Length
add wave -noupdate -radix hexadecimal /testbench/DUT/FIFO_almost_empty
add wave -noupdate -radix hexadecimal /testbench/DUT/FIFO_Read_Access
add wave -noupdate -radix hexadecimal /testbench/DUT/FIFO_Data
add wave -noupdate -radix hexadecimal /testbench/DUT/AM_Addr
add wave -noupdate -radix hexadecimal /testbench/DUT/AM_Data
add wave -noupdate -radix hexadecimal /testbench/DUT/AM_Write
add wave -noupdate -radix hexadecimal /testbench/DUT/AM_BurstCount
add wave -noupdate -radix hexadecimal /testbench/DUT/AM_WaitRequest
add wave -noupdate -radix hexadecimal /testbench/DUT/iRegCounterAddress
add wave -noupdate -radix hexadecimal /testbench/DUT/iRegData
add wave -noupdate -radix hexadecimal /testbench/DUT/SM_State
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {16870 ps} 0}
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {483 ns}
