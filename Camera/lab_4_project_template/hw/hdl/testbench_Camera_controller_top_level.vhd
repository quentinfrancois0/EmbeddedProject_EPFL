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
component Top_Camera_Controller is
	PORT(
		TL_nReset			: IN std_logic;							-- nReset input
		TL_Clk				: IN std_logic;							-- clock input
		
		AS_Address			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
		AS_ReadEnable		: IN std_logic;							-- read enabler
		AS_WriteEnable		: IN std_logic;							-- write enabler
		AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		AM_MemoryAddress	: OUT std_logic_vector (15 DOWNTO 0);	-- Address sent on the Avalon bus
		AM_AvalonData		: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_WriteRequest		: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_WaitRequest		: IN std_logic;							-- Pin waitrequest which is 0 when the bus is available
		
		CA_PixClk			: IN std_logic;							-- pixel clock received from the camera
		CA_Data				: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		CA_FrameValid		: IN std_logic;							-- 1 if the frame is valid
		CA_LineValid		: IN std_logic							-- 1 if the line is valid
	);
end component;

-- The signals provided by the testbench :
signal TB_TL_nReset			: std_logic := '1';										-- nReset input
signal TB_TL_Clk			: std_logic := '0';										-- clock input
	
signal TB_TL_Address		: std_logic_vector (2 DOWNTO 0) := "000";				-- address bus
signal TB_TL_ReadEnable		: std_logic := '0';										-- read enabler
signal TB_TL_WriteEnable	: std_logic := '0';										-- write enabler
signal TB_TL_WriteData		: std_logic_vector (7 DOWNTO 0) := X"00";				-- data bus (write)

signal TB_TL_WaitRequest	: std_logic := '0';										-- Pin waitrequest which is 0 when the bus is available

signal TB_TL_PixClk			: std_logic := '0';										-- pixel clock received from the camera
signal TB_TL_Data			: std_logic_vector (11 DOWNTO 0) := "000000000000";		-- pixel sent by the camera
signal TB_TL_FrameValid		: std_logic := '0';										-- 1 if the frame is valid
signal TB_TL_LineValid		: std_logic := '0';										-- 1 if the line is valid

signal end_sim	: boolean := false;

constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
constant HalfPeriod_cam  : TIME := 53.4 ns;  -- clk_CAM = 18.73 MHz -> T_CAM = 53.4 ns -> T/2 = 26.7 ns
	
BEGIN 
DUT : Top_Camera_Controller	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		TL_nReset => TB_TL_nReset,
		TL_Clk => TB_TL_Clk,
		
		AS_Address => TB_TL_Address,
		AS_ReadEnable => TB_TL_ReadEnable,
		AS_WriteEnable => TB_TL_WriteEnable,
		AS_WriteData => TB_TL_WriteData,
		
		AM_WaitRequest => TB_TL_WaitRequest,
		
		CA_PixClk => TB_TL_PixClk,
		CA_Data => TB_TL_Data,
		CA_FrameValid => TB_TL_FrameValid,
		CA_LineValid => TB_TL_LineValid
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		TB_TL_Clk <= '0';
		wait for HalfPeriod;
		TB_TL_Clk <= '1';
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
		wait until rising_edge(TB_TL_Clk);
		TB_TL_nReset <= '0';
		
		wait until rising_edge(TB_TL_Clk);
		TB_TL_nReset <= '1';
	end procedure toggle_reset;
	
	-- Procedure to write a register, inputs are (address, data_to_write)
	Procedure write_register(addr_write: std_logic_vector; data: std_logic_vector) is
	Begin
		wait until rising_edge(TB_TL_Clk);	-- write between two consecutive rising edges of the clock
		TB_TL_WriteEnable <= '1';
		TB_TL_Address <= addr_write;
		TB_TL_WriteData <= data;
		
		wait until rising_edge(TB_TL_Clk);	-- then reset everything
		TB_TL_WriteEnable <= '0';
		TB_TL_Address <= "000";
		TB_TL_WriteData <= "00000000";
	end procedure write_register;

	-- Procedure to read a register, input is (address)
	Procedure read_register(addr_read: std_logic_vector) is
	Begin
		wait until rising_edge(TB_TL_Clk);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		TB_TL_ReadEnable <= '1';
		
		wait until rising_edge(TB_TL_Clk);	-- now the internal phantom read register will be set to 1, we can read the register
		TB_TL_Address <= addr_read;
		
		wait until rising_edge(TB_TL_Clk);	-- then reset everything
		TB_TL_ReadEnable <= '0';
		TB_TL_Address <= "000";
	end procedure read_register;

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;