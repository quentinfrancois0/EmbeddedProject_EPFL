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
		AM_nReset			: IN std_logic;							-- AM_nReset input
		AM_Clk				: IN std_logic;							-- clock input
		
		AM_Start			: IN std_logic;							-- Start command
		AS_StartAddress		: IN std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AM_Length			: IN std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		
		AM_UsedWords		: IN std_logic_vector (7 DOWNTO 0);		-- number of 32 bits words
		AM_ReadAccess		: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		AM_FIFOData			: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
		AM_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_AvalonData		: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_WriteRequest		: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_WaitRequest		: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
		
	);
end component;

-- The interconnection signals :
signal AM_nReset			: std_logic := '1';
signal AM_Clk				: std_logic := '0';

signal Start_Address	: std_logic_vector (31 DOWNTO 0) := X"1000012C";
signal Length			: std_logic_vector (31 DOWNTO 0) := X"10000140";
signal Start			: std_logic := '0';

signal Number_words		: std_logic_vector (7 DOWNTO 0) := X"00";
signal Read_Access		: std_logic := '0';
signal Data				: std_logic_vector (31 DOWNTO 0) := X"00000001";

signal Addr				: std_logic_vector (31 DOWNTO 0) := X"00000000";
signal WData			: std_logic_vector (31 DOWNTO 0) := X"00000000";
signal W				: std_logic := '0';
signal BurstCount		: std_logic_vector (7 DOWNTO 0) := X"00";
signal WaitRequest		: std_logic := '1';

signal Data_info : std_logic_vector (31 DOWNTO 0) := X"00000002";
signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_master	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		AM_nReset => AM_nReset,
		AM_Clk => AM_Clk,
		
		AS_StartAddress => Start_Address,
		AM_Length => Length,
		AM_Start => Start,
		
		AM_UsedWords => Number_words,
		AM_ReadAccess => Read_Access,
		AM_FIFOData => Data,
		
		AM_MemoryAddress => Addr,
		AM_AvalonData => WData,
		AM_WriteRequest => W,
		AM_BurstCount => BurstCount,
		AM_WaitRequest => WaitRequest

	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		AM_Clk <= '0';
		wait for HalfPeriod;
		AM_Clk <= '1';
		wait for HalfPeriod;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process clk_process;

transfer_fifo :
Process
Begin
	if unsigned(Data_info)<6 AND end_sim = false then
		wait until rising_edge(AM_Clk) AND Read_Access = '1';
		Data_info <= std_logic_vector(unsigned(Data_info) + 1);
		Data <= Data_info;
	else 
		end_sim <= true;
		wait;
	end if;
end process transfer_fifo;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(AM_Clk);
		AM_nReset <= '0';
		
		wait until rising_edge(AM_Clk);
		AM_nReset <= '1';
	end procedure toggle_reset;
	
Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Number words at 1 => not one burst in the FIFO
	wait until rising_edge(AM_Clk);
	Number_words <= X"01";
	
	-- Start => 1
	wait until rising_edge(AM_Clk);
	Start <= '1';
	Number_words <= X"10";
	WaitRequest <= '0';
	
--	-- put the FIFO data on the pins when it is asked (0x0300 = 768)
--	wait until rising_edge(AM_Clk) AND Read_Access = '1'; --wait a data asking (1st word)
--	Data <= X"10000300";
--
--	-- put the FIFO data on the pins when it is asked (0x0200 = 512)
--	wait until rising_edge(AM_Clk) AND Read_Access = '1'; --wait a data asking (2nd word)
--	Data <= X"10000200";
--	WaitRequest <= '1';
--	
--	wait until rising_edge(AM_Clk);
--	WaitRequest <= '0';
--	
--	-- put the FIFO data on the pins when it is asked (0x0100 = 256)
--	wait until rising_edge(AM_Clk) AND Read_Access = '1'; --wait a data asking (3rd word)
--	Data <= X"10000100";
--	-- Block the third transfer
	wait until rising_edge(AM_Clk);
	wait until rising_edge(AM_Clk);
	wait until rising_edge(AM_Clk);
	wait until rising_edge(AM_Clk);
	WaitRequest <= '1';
	
	wait until rising_edge(AM_Clk);
	wait until rising_edge(AM_Clk);
	WaitRequest <= '0';
--
--	-- 2nd transfer on the bus
--	wait until rising_edge(AM_Clk) AND Read_Access = '1';
--	Data <= X"10100010"; --(0x0010 = 16) --wait a data asking (4th word)
--	-- 4th transfer on the bus
	
	-- Set end_sim to "true", so the clock generation stops
	wait;
end process test;

END bhv;