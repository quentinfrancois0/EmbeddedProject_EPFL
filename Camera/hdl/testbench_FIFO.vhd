-- Testbench for the PWM module
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : 10.11.2016
--
-- 2 process :
--	Process to generate the clock during the whole simulation
--	Process to test the component
--
-- 3 procedures :
--	Procedure to toggle the reset
--	Procedure to write a register
--	Procedure to read a register
--
-- Tests done :
--	Writing the internal clock divider register
--	Writing the internal duty cycle register
--	Writing the internal polarity register
--	Writing the internal control register
--	Reading the internal duty cycle register
--	Reading the internal counter register
--
-- All the writing actions allow to generate a PWM signal with a 5,12 us period and a 62.7% duty cycle.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity testbench is
	-- Nothing as input/output
end testbench;

ARCHITECTURE bhv OF testbench IS
-- The system to test under simulation
component FIFO is
	PORT(
		FIFO_Reset			: IN STD_LOGIC ;
		
		FIFO_CIClk			: IN STD_LOGIC ;
		FIFO_CIData			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		FIFO_WriteAccess	: IN STD_LOGIC ;
		FIFO_CIUsedWords	: OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
		
		FIFO_AMClk			: IN STD_LOGIC ;
		FIFO_AMData			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		FIFO_ReadAccess		: IN STD_LOGIC ;
		FIFO_AMUsedWords	: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
	);
end component;

-- The signals provided by the testbench :
signal TB_FIFO_Reset			: STD_LOGIC  := '0';
signal TB_FIFO_CIData			: STD_LOGIC_VECTOR (15 DOWNTO 0) := "0000000000000000";
signal TB_FIFO_AMClk			: STD_LOGIC := '0';
signal TB_FIFO_ReadAccess		: STD_LOGIC := '0';
signal TB_FIFO_CIClk			: STD_LOGIC := '0';
signal TB_FIFO_WriteAccess		: STD_LOGIC := '0';

signal end_sim	: boolean := false;
constant HalfPeriod_CI  : TIME := 53.4 ns;  -- clk_CI = 18.73 MHz -> T_CI = 53.4 ns -> T/2 = 26.7 ns
constant HalfPeriod_AM  : TIME := 20 ns;  -- clk_AM = 25 MHz -> T_AM = 40ns -> T/2 = 20 ns
	
BEGIN 
DUT : FIFO	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		FIFO_Reset => TB_FIFO_Reset,
		FIFO_CIData => TB_FIFO_CIData,
		FIFO_AMClk => TB_FIFO_AMClk,
		FIFO_ReadAccess => TB_FIFO_ReadAccess,
		FIFO_CIClk => TB_FIFO_CIClk,
		FIFO_WriteAccess => TB_FIFO_WriteAccess
	);

-- Process to generate the CI clock during the whole simulation
CIClkProcess :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		TB_FIFO_CIClk <= '0';
		wait for HalfPeriod_CI;
		TB_FIFO_CIClk <= '1';
		wait for HalfPeriod_CI;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process CIClkProcess;

-- Process to generate the AM clock during the whole simulation
AMClkProcess :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		TB_FIFO_AMClk <= '0';
		wait for HalfPeriod_AM;
		TB_FIFO_AMClk <= '1';
		wait for HalfPeriod_AM;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process AMClkProcess;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(TB_FIFO_AMClk);
		TB_FIFO_Reset <= '1';
		
		wait until rising_edge(TB_FIFO_AMClk);
		TB_FIFO_Reset <= '0';
	end procedure toggle_reset;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Start the acquisition
	
	wait for 50 * 2*HalfPeriod_AM;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;