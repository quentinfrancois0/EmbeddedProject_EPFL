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
component Avalon_master is
	PORT(
		nReset				: IN std_logic;								-- nReset input
		Clk					: IN std_logic;								-- clock input
		
		AS_Start				: IN std_logic;								-- Start command
		AS_Start_Address		: IN std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
		AS_Length			: IN std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		
		FIFO_almost_empty	: IN std_logic;								-- 1 when FIFO contains at least the burst length, 0 otherwise
		FIFO_Read_Access	: OUT std_logic;								-- 1 = information asked to the Fifo, 0 = no demand
		FIFO_Data			: IN std_logic_vector (15 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
		AM_Addr				: OUT std_logic_vector (15 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_Data				: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_Write				: OUT std_logic;								-- Pin write, 1 when the component wants to use the bus
		AM_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_WaitRequest		: IN std_logic									-- Pin waitrequest which is 0 when the bus is available
		
	);
end component;

-- The interconnection signals :
signal nReset			: std_logic := '1';
signal Clk				: std_logic := '0';

signal Start_Address	: std_logic_vector (15 DOWNTO 0) := X"012C";
signal Length			: std_logic_vector (15 DOWNTO 0) := X"0140";
signal Start			: std_logic := '0';

signal Almost_empty	: std_logic := '1';
signal Read_Access	: std_logic := '0';
signal Data				: std_logic_vector (15 DOWNTO 0) := "0000000000000000";

signal Addr				: std_logic_vector (15 DOWNTO 0) := "0000000000000000";
signal WData			: std_logic_vector (15 DOWNTO 0) := "0000000000000000";
signal W					: std_logic := '0';
signal BurstCount		: std_logic_vector (7 DOWNTO 0) := "00000000";
signal WaitRequest	: std_logic := '1';

signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_master	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		nReset => nReset,
		Clk => Clk,
		
		AS_Start_Address => Start_Address,
		AS_Length => Length,
		AS_Start => Start,
		
		FIFO_almost_empty => Almost_Empty,
		FIFO_Read_Access => Read_Access,
		FIFO_Data => Data,
		
		AM_Addr => Addr,
		AM_Data => WData,
		AM_Write => W,
		AM_BurstCount => BurstCount,
		AM_WaitRequest => WaitRequest

	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		Clk <= '0';
		wait for HalfPeriod;
		Clk <= '1';
		wait for HalfPeriod;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process clk_process;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(clk);
		nReset <= '0';
		
		wait until rising_edge(clk);
		nReset <= '1';
	end procedure toggle_reset;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Almost empty at 0 => one burst in the FIFO but start = 0 => not start
	wait until rising_edge(clk);
	Almost_empty <= '0';
	
	-- Start => 1
	wait until rising_edge(clk);
	Start <= '1';
	
	-- put the FIFO data on the pins when it is asked (0x0300 = 768)
	wait until rising_edge(clk) AND Read_Access = '1'; --wait a data asking (1st word)
	Data <= X"0300";
	
	-- put the FIFO data on the pins when it is asked (0x0200 = 512)
	wait until rising_edge(clk) AND Read_Access = '1'; --wait a data asking (2nd word)
	Data <= X"0200";
	WaitRequest <= '0';
	-- 1st transfer on the bus
	Almost_empty <= '1';
	
	-- put the FIFO data on the pins when it is asked (0x0100 = 256)
	wait until rising_edge(clk) AND Read_Access = '1'; --wait a data asking (3rd word)
	Data <= X"0100";
	WaitRequest <= '1';
	-- 2nd transfer is blocked
	
	wait until rising_edge(clk);
	wait until rising_edge(clk);
	WaitRequest <= '0';
	-- 2nd transfer on the bus
	wait until rising_edge(clk) AND Read_Access = '1';
	Data <= X"0010"; --(0x0010 = 16) --wait a data asking (4th word)
	-- 3rd transfer on the bus
	-- 4th transfer on the bus
	
	wait for 10 * 2*HalfPeriod; -- wait for 10*(2*HalfPeriod)
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;