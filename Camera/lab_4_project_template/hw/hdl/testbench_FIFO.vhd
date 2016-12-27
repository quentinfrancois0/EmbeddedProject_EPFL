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
		
		FIFO_WriteClk		: IN STD_LOGIC ;
		FIFO_CI_WriteData	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		FIFO_CI_WriteEnable	: IN STD_LOGIC ;
		FIFO_CI_UsedWords	: OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
		
		FIFO_ReadClk		: IN STD_LOGIC ;
		FIFO_AM_ReadData	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		FIFO_AM_ReadCheck	: IN STD_LOGIC ;
		FIFO_AM_UsedWords	: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
	);
end component;

-- The signals provided by the testbench :
signal FIFO_Reset_test			: STD_LOGIC  := '0';

signal FIFO_WriteClk_test		: STD_LOGIC := '0';
signal FIFO_CI_WriteData_test	: STD_LOGIC_VECTOR (15 DOWNTO 0) := X"0000";
signal FIFO_CI_WriteEnable_test	: STD_LOGIC := '0';
signal FIFO_CI_UsedWords_test	: STD_LOGIC_VECTOR (9 DOWNTO 0);

signal FIFO_ReadClk_test		: STD_LOGIC := '0';
signal FIFO_AM_ReadData_test	: STD_LOGIC_VECTOR (31 DOWNTO 0);
signal FIFO_AM_ReadCheck_test	: STD_LOGIC := '0';
signal FIFO_AM_UsedWords_test	: STD_LOGIC_VECTOR (8 DOWNTO 0);

constant HalfPeriod_CI  : TIME := 53.4 ns;  -- clk_CI = 18.73 MHz -> T_CI = 53.4 ns -> T/2 = 26.7 ns
constant HalfPeriod_AM  : TIME := 20 ns;  -- clk_AM = 25 MHz -> T_AM = 40ns -> T/2 = 20 ns
signal end_sim : boolean := false;

signal burstcount16 : integer := 0;
	
BEGIN 
DUT : FIFO	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		FIFO_Reset 			=> FIFO_Reset_test,
		
		FIFO_WriteClk 		=> FIFO_WriteClk_test,
		FIFO_CI_WriteData 	=> FIFO_CI_WriteData_test,
		FIFO_CI_WriteEnable => FIFO_CI_WriteEnable_test,
		FIFO_CI_UsedWords 	=> FIFO_CI_UsedWords_test,
		
		FIFO_ReadClk 		=> FIFO_ReadClk_test,
		FIFO_AM_ReadData 	=> FIFO_AM_ReadData_test,
		FIFO_AM_ReadCheck 	=> FIFO_AM_ReadCheck_test,
		FIFO_AM_UsedWords 	=> FIFO_AM_UsedWords_test
	);

-- Process to generate the CI clock during the whole simulation
CIClkProcess :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		FIFO_WriteClk_test <= '0';
		wait for HalfPeriod_CI;
		FIFO_WriteClk_test <= '1';
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
		FIFO_ReadClk_test <= '0';
		wait for HalfPeriod_AM;
		FIFO_ReadClk_test <= '1';
		wait for HalfPeriod_AM;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process AMClkProcess;

--	Process to test the component
WriteProcess :
Process

-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(FIFO_ReadClk_test);
		FIFO_Reset_test <= '1';
		
		wait until rising_edge(FIFO_ReadClk_test);
		FIFO_Reset_test <= '0';
	end procedure toggle_reset;

	variable RGB : std_logic_vector (15 DOWNTO 0) := "0000000000000001";
	
	variable inc : std_logic_vector (15 DOWNTO 0) := "0000000000000000";

Begin
	toggle_reset;

	-- Start the acquisition
	wait until rising_edge(FIFO_WriteClk_test);
	
	loop_r: FOR row IN 1 TO 1 LOOP
	
		loop_row_1: FOR c1 IN 1 TO 320 LOOP
			wait for 2*HalfPeriod_CI;
		END LOOP loop_row_1;
		
		inc := "0000000000000000";
		burstcount16 <= 0;
		
		loop_row_2: FOR c2 IN 1 TO 320 LOOP
		
			wait for 2*HalfPeriod_CI;
			
			wait until falling_edge(FIFO_WriteClk_test);
			FIFO_CI_WriteEnable_test <= '1';
			wait until rising_edge(FIFO_WriteClk_test);
			FIFO_CI_WriteData_test <= std_logic_vector(unsigned(RGB) + unsigned(inc));
			wait until falling_edge(FIFO_WriteClk_test);
			FIFO_CI_WriteEnable_test <= '0';
			
			burstcount16 <= burstcount16 + 1;
			
			if burstcount16 >= 8 then
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '1';
				burstcount16 <= burstcount16 - 2;
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '0';
				
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '1';
				burstcount16 <= burstcount16 - 2;
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '0';
				
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '1';
				burstcount16 <= burstcount16 - 2;
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '0';
				
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '1';
				burstcount16 <= burstcount16 - 2;
				wait until rising_edge(FIFO_ReadClk_test);
				wait for 2*HalfPeriod_AM;
				FIFO_AM_ReadCheck_test <= '0';
			end if;
			
			inc := std_logic_vector(unsigned(inc) + 1);
			
		END LOOP loop_row_2;
		
	END LOOP loop_r;
	
	end_sim <= true;
	wait;
end process WriteProcess;

END bhv;