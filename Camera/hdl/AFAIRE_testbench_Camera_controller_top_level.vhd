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
component Camera_Interface is
	PORT(
		CI_nReset			: IN std_logic;							-- nReset input
		CI_Clk				: IN std_logic;							-- clock input
		
		AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- write data bus
		AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- read data bus
		AS_WriteEnable		: IN std_logic;							-- write enable
		AS_ReadEnable		: IN std_logic;							-- read enable
		AS_Address			: IN std_logic_vector (1 DOWNTO 0);		-- address bus
		
		CAM_nReset			: OUT std_logic;						-- nReset sent to the camera
		CAM_XClk			: OUT std_logic;						-- clock sent to the camera
		CAM_PixClk			: IN std_logic;							-- pixel clock received from the camera
		CAM_Data			: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		CAM_Frame_Valid		: IN std_logic;							-- 1 if the frame is valid
		CAM_Line_Valid		: IN std_logic;							-- 1 if the line is valid
		
		FIFO_Write_Access	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
		FIFO_Data			: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
		FIFO_Almost_Full	: IN std_logic							-- 1 = FIFO has less than four words free, 0 = everything is okay
	);
end component;

-- The signals provided by the testbench :
signal nReset			: std_logic := '1';							-- nReset input
signal clk				: std_logic := '0';							-- clock input
		
signal WData			: std_logic_vector (7 DOWNTO 0) := "00000000";		-- write data bus
signal RData			: std_logic_vector (7 DOWNTO 0) := "00000000";	-- read data bus
signal W				: std_logic := '0';							-- write enable
signal R				: std_logic := '0';							-- read enable
signal Addr				: std_logic_vector (1 DOWNTO 0) := "00";		-- address bus
		
signal CAM_nReset			: std_logic := '1';						-- nReset sent to the camera
signal CAM_XClk				: std_logic := '0';						-- clock sent to the camera
signal CAM_PixClk			: std_logic := '0';							-- pixel clock received from the camera
signal CAM_Data				: std_logic_vector (11 DOWNTO 0) := "000000000000";	-- pixel sent by the camera
signal CAM_Frame_Valid		: std_logic := '0';							-- 1 if the frame is valid
signal CAM_Line_Valid		: std_logic := '0';							-- 1 if the line is valid
		
signal FIFO_Write_Access	: std_logic := '0';						-- 1 = write asked to the FIFO, 0 = no demand
signal FIFO_Data			: std_logic_vector (15 DOWNTO 0) := "0000000000000000";	-- 16 bits pixel stored in the FIFO by the camera controller
signal FIFO_Almost_Full		: std_logic := '0';							-- 1 = FIFO has less than four words free, 0 = everything is okay

signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Camera_Interface	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		CI_nReset => nReset,
		CI_Clk => clk,
		
		AS_WriteData => WData,
		AS_ReadData => RData,
		AS_WriteEnable => W,
		AS_ReadEnable => R,
		AS_Address => Addr,
		
		CAM_nReset => CAM_nReset,
		CAM_XClk => CAM_XClk,
		CAM_PixClk => CAM_PixClk,
		CAM_Data => CAM_Data,
		CAM_Frame_Valid => CAM_Frame_Valid,
		CAM_Line_Valid => CAM_Line_Valid,
		
		FIFO_Write_Access => FIFO_Write_Access,
		FIFO_Data => FIFO_Data,
		FIFO_Almost_Full => FIFO_Almost_Full
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		clk <= '0';
		wait for HalfPeriod;
		clk <= '1';
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
		Addr <= "00";
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
		Addr <= "00";
	end procedure read_register;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Start the acquisition
	wait until rising_edge(clk);
	write_register(X"00", "10000000");
	
	wait for 50 * 2*HalfPeriod;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;