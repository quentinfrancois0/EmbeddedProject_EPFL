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
		AS_nReset			: IN std_logic;							-- AS_nReset input
		AS_Clk				: IN std_logic;							-- clock input
		
		AS_Address			: IN std_logic_vector (3 DOWNTO 0);		-- address bus
		AS_ReadEnable		: IN std_logic;							-- read enabler
		AS_WriteEnable		: IN std_logic;							-- write enabler
		AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		AS_StartAddress		: OUT std_logic_vector (31 DOWNTO 0); 	-- AS_Start Adress in the memory
		AS_Length			: OUT std_logic_vector (31 DOWNTO 0);	-- AS_Length of the stored datas
		AS_Start			: OUT std_logic	;			-- AS_Start information
		AS_Status			: IN std_logic
	);
end component;

-- The interconnection signals :
signal AS_nReset			: std_logic := '1';
signal AS_Clk				: std_logic := '0';

signal AS_Address			: std_logic_vector (3 DOWNTO 0) := X"0";
signal AS_ReadEnable		: std_logic := '0';
signal AS_WriteEnable		: std_logic := '0';
signal AS_ReadData			: std_logic_vector (7 DOWNTO 0) := X"00";
signal AS_WriteData			: std_logic_vector (7 DOWNTO 0) := X"00";

signal AS_StartAddress		: std_logic_vector (31 DOWNTO 0) := X"00000000";
signal AS_Length			: std_logic_vector (31 DOWNTO 0) := X"00000000";
signal AS_Start				: std_logic := '0';
signal AS_Status			: std_logic := '0';

signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_slave	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		AS_nReset => AS_nReset,
		AS_Clk => AS_Clk,
		
		AS_Address => AS_Address,
		AS_ReadEnable => AS_ReadEnable,
		AS_WriteEnable => AS_WriteEnable,
		AS_ReadData => AS_ReadData,
		AS_WriteData => AS_WriteData,
		
		AS_StartAddress => AS_StartAddress,
		AS_Length => AS_Length,
		AS_Start => AS_Start,
		AS_Status => AS_Status
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		AS_Clk <= '0';
		wait for HalfPeriod;
		AS_Clk <= '1';
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
		wait until rising_edge(AS_Clk);
		AS_nReset <= '0';
		
		wait until rising_edge(AS_Clk);
		AS_nReset <= '1';
	end procedure toggle_reset;

	-- Procedure to write a register, inputs are (address, data_to_write)
	Procedure write_register(addr_write: std_logic_vector; data: std_logic_vector) is
	Begin
		wait until rising_edge(AS_Clk);	-- write between two consecutive rising edges of the clock
		AS_WriteEnable <= '1';
		AS_Address <= addr_write;
		AS_WriteData <= data;
		
		wait until rising_edge(AS_Clk);	-- then reset everything
		AS_WriteEnable <= '0';
		AS_Address <= X"0";
		AS_WriteData <= X"00";
	end procedure write_register;

	-- Procedure to read a register, input is (address)
	Procedure read_register(addr_read: std_logic_vector) is
	Begin
		wait until rising_edge(AS_Clk);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		AS_ReadEnable <= '1';
		
		wait until rising_edge(AS_Clk);	-- now the internal phantom read register will be set to 1, we can read the register
		AS_Address <= addr_read;
		
		wait until rising_edge(AS_Clk);	-- then reset everything
		AS_ReadEnable <= '0';
		AS_Address <= X"0";
	end procedure read_register;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Writing AS_StartAddress = 20 = 0x00000014
	write_register(X"1", X"14");
	
	-- Writing start_adress = 300 = 0x1010012C -> 0x10100114
	write_register(X"1", X"2C"); --not writed because of the flag
	write_register(X"2", X"01");
	write_register(X"3", X"10");
	write_register(X"4", X"10");
	
	-- Writing AS_Length = 32 = 0x20204020
	write_register(X"5", X"20");
	write_register(X"6", X"40");
	write_register(X"7", X"20");
	write_register(X"8", X"20");
	
	-- Writing AS_Status of buffers
	write_register(X"9", X"05");
	
	-- Writing AS_Start information = 1
	write_register(X"0", X"01");
	
	-- Reading AS_Start information
	read_register(X"0");
	
	-- Writing AS_Start information = 0
	write_register(X"0", X"00");
	
	-- Reading the AS_StartAddress(0x10100114)
	read_register(X"1");
	read_register(X"2");
	read_register(X"3");
	read_register(X"4");
	
	-- Reading the AS_Length (320 = 0x20204020)
	read_register(X"5");
	read_register(X"6");
	read_register(X"7");
	read_register(X"8");
	
	-- Reading AS_Status of buffers
	read_register(X"9");
	
	wait for 2*HalfPeriod;
	AS_Status <= '1';
	wait for 2*HalfPeriod;
	AS_Status <= '0';
	
	wait for 2*HalfPeriod;
	AS_Status <= '1';
	wait for 2*HalfPeriod;
	AS_Status <= '0';
	
	wait for 2*HalfPeriod;
	AS_Status <= '1';
	wait for 2*HalfPeriod;
	AS_Status <= '0';
	
	wait for 2*HalfPeriod;
	AS_Status <= '1';
	wait for 2*HalfPeriod;
	AS_Status <= '0';
	
	wait for 4*HalfPeriod;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;