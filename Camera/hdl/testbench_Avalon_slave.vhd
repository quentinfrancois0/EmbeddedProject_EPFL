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
component Avalon_slave is
	PORT(
		nReset			: IN std_logic;							-- nReset input
		Clk				: IN std_logic;							-- clock input
		
		Addr			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
		R				: IN std_logic;							-- read enabler
		W				: IN std_logic;							-- write enabler
		RData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		WData			: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		Start_Address	: OUT std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
		Length			: OUT std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		Start			: OUT std_logic					-- Start information
	);
end component;

-- The interconnection signals :
signal nReset			: std_logic := '1';
signal Clk				: std_logic := '0';

signal Addr				: std_logic_vector (2 DOWNTO 0) := "000";
signal R				: std_logic := '0';
signal W				: std_logic := '0';
signal RData			: std_logic_vector (7 DOWNTO 0) := "00000000";
signal WData			: std_logic_vector (7 DOWNTO 0) := "00000000";

signal Start_Address	: std_logic_vector (15 DOWNTO 0) := "0000000000000000";
signal Length			: std_logic_vector (15 DOWNTO 0) := "0000000000000000";
signal Start			: std_logic := '0';
signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_slave	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		nReset => nReset,
		Clk => Clk,
		
		Addr => Addr,
		R => R,
		W => W,
		RData => RData,
		WData => WData,
		
		Start_Address => Start_Address,
		Length => Length,
		Start => Start
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

	-- Procedure to write a register, inputs are (address, data_to_write)
	Procedure write_register(addr_write: std_logic_vector; data: std_logic_vector) is
	Begin
		wait until rising_edge(clk);	-- write between two consecutive rising edges of the clock
		W <= '1';
		Addr <= addr_write;
		WData <= data;
		
		wait until rising_edge(clk);	-- then reset everything
		W <= '0';
		Addr <= "000";
		WData <= "00000000";
	end procedure write_register;

	-- Procedure to read a register, input is (address)
	Procedure read_register(addr_read: std_logic_vector) is
	Begin
		wait until rising_edge(clk);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		R <= '1';
		
		wait until rising_edge(clk);	-- now the internal phantom read register will be set to 1, we can read the register
		Addr <= addr_read;
		
		wait until rising_edge(clk);	-- then reset everything
		R <= '0';
		Addr <= "000";
	end procedure read_register;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Writing start_address = 20 = 0x0014
	write_register("001", X"14");
	
	-- Writing start_adress = 300 = 0x012C
	write_register("001", X"2C"); --not writing because of the flag
	write_register("010", X"01");
	
	-- Writing length = 32 = 0x4020
	write_register("011", X"20");
	write_register("100", X"40");
	
	-- Writing Start information = 1
	write_register("000", X"01");
	
	-- Reading Start information
	read_register("000");
	
	-- Writing Start information = 0
	write_register("000", X"00");
	
	-- Reading the Start_Address(300 = 0x012C)
	read_register("001");
	read_register("010");
	
	-- Reading the Length (320 = 0x0140)
	read_register("100");
	read_register("101");
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;