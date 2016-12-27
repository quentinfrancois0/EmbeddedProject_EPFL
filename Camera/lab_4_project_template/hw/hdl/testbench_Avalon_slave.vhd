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
		AS_nReset			: IN std_logic;							-- nReset input
		AS_Clk				: IN std_logic;							-- clock input
		
		AS_AB_Address		: IN std_logic_vector (3 DOWNTO 0);		-- address bus
		AS_AB_ReadEnable	: IN std_logic;							-- read enabler
		AS_AB_WriteEnable	: IN std_logic;							-- write enabler
		AS_AB_ReadData		: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		AS_AB_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		AS_AMCI_Start		: OUT std_logic;						-- Start information
		AS_AM_StartAddress	: OUT std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AS_AM_Length		: OUT std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		AS_AM_Status		: IN std_logic
	);
end component;

-- The interconnection signals :
signal AS_nReset_test			: std_logic := '1';
signal AS_Clk_test				: std_logic := '0';

signal AS_AB_Address_test		: std_logic_vector (3 DOWNTO 0) := X"0";
signal AS_AB_ReadEnable_test	: std_logic := '0';
signal AS_AB_WriteEnable_test	: std_logic := '0';
signal AS_AB_ReadData_test		: std_logic_vector (7 DOWNTO 0);
signal AS_AB_WriteData_test		: std_logic_vector (7 DOWNTO 0) := X"00";

signal AS_AMCI_Start_test		: std_logic;
signal AS_AM_StartAddress_test	: std_logic_vector (31 DOWNTO 0);
signal AS_AM_Length_test		: std_logic_vector (31 DOWNTO 0);
signal AS_AM_Status_test		: std_logic := '0';

signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_slave	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		AS_nReset 			=> AS_nReset_test,
		AS_Clk 				=> AS_Clk_test,
		
		AS_AB_Address 		=> AS_AB_Address_test,
		AS_AB_ReadEnable 	=> AS_AB_ReadEnable_test,
		AS_AB_WriteEnable 	=> AS_AB_WriteEnable_test,
		AS_AB_ReadData 		=> AS_AB_ReadData_test,
		AS_AB_WriteData 	=> AS_AB_WriteData_test,
		
		AS_AMCI_Start 		=> AS_AMCI_Start_test,
		AS_AM_StartAddress 	=> AS_AM_StartAddress_test,
		AS_AM_Length 		=> AS_AM_Length_test,
		AS_AM_Status 		=> AS_AM_Status_test
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		AS_Clk_test <= '0';
		wait for HalfPeriod;
		AS_Clk_test <= '1';
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
		wait until rising_edge(AS_Clk_test);
		AS_nReset_test <= '0';
		
		wait until rising_edge(AS_Clk_test);
		AS_nReset_test <= '1';
	end procedure toggle_reset;

	-- Procedure to write a register, inputs are (address, data_to_write)
	Procedure write_register(addr_write: std_logic_vector; data: std_logic_vector) is
	Begin
		wait until rising_edge(AS_Clk_test);	-- write between two consecutive rising edges of the clock
		AS_AB_WriteEnable_test <= '1';
		AS_AB_Address_test <= addr_write;
		AS_AB_WriteData_test <= data;
		
		wait until rising_edge(AS_Clk_test);	-- then reset everything
		AS_AB_WriteEnable_test <= '0';
		AS_AB_Address_test <= X"0";
		AS_AB_WriteData_test <= X"00";
	end procedure write_register;

	-- Procedure to read a register, input is (address)
	Procedure read_register(addr_read: std_logic_vector) is
	Begin
		wait until rising_edge(AS_Clk_test);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		AS_AB_ReadEnable_test <= '1';
		
		wait until rising_edge(AS_Clk_test);	-- now the internal phantom read register will be set to 1, we can read the register
		AS_AB_Address_test <= addr_read;
		
		wait until rising_edge(AS_Clk_test);	-- then reset everything
		AS_AB_ReadEnable_test <= '0';
		AS_AB_Address_test <= X"0";
	end procedure read_register;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Writing AS_AM_StartAddress = 20 = 0x00000014
	write_register(X"1", X"14");
	
	-- Writing start_adress = 300 = 0x1010012C -> 0x10100114
	write_register(X"1", X"2C"); --not writed because of the flag
	write_register(X"2", X"01");
	write_register(X"3", X"10");
	write_register(X"4", X"10");
	
	-- Writing AS_AM_Length = 32 = 0x20204020
	write_register(X"5", X"20");
	write_register(X"6", X"40");
	write_register(X"7", X"20");
	write_register(X"8", X"20");
	
	-- Writing AS_AM_Status of buffers
	write_register(X"9", X"05");
	
	-- Writing AS_AMCI_Start information = 1
	write_register(X"0", X"01");
	
	-- Reading AS_AMCI_Start information
	read_register(X"0");
	
	-- Writing AS_AMCI_Start information = 0
	write_register(X"0", X"00");
	
	-- Reading the AS_AM_StartAddress(0x10100114)
	read_register(X"1");
	read_register(X"2");
	read_register(X"3");
	read_register(X"4");
	
	-- Reading the AS_AM_Length (320 = 0x20204020)
	read_register(X"5");
	read_register(X"6");
	read_register(X"7");
	read_register(X"8");
	
	-- Reading AS_AM_Status of buffers
	read_register(X"9");
	
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '1';
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '0';
	
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '1';
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '0';
	
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '1';
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '0';
	
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '1';
	wait for 2*HalfPeriod;
	AS_AM_Status_test <= '0';
	
	wait for 4*HalfPeriod;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;