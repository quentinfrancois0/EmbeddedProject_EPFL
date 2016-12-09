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
		
		CI_Start			: IN std_logic;							-- Start information
		
		CI_XClkIn			: OUT std_logic;						-- clock sent to the camera
		CI_PixClk			: IN std_logic;							-- pixel clock received from the camera
		CI_CAMData			: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		CI_FrameValid		: IN std_logic;							-- 1 if the frame is valid
		CI_LineValid		: IN std_logic;							-- 1 if the line is valid
		
		CI_FIFOClk			: OUT std_logic;						-- FIFO clock = PixClk
		CI_WriteAccess		: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
		CI_FIFOData			: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
		CI_UsedWords		: IN std_logic_vector (9 DOWNTO 0)		-- 16 bits used words in the FIFO
	);
end component;

-- The signals provided by the testbench :
signal nReset			: std_logic := '1';										-- nReset input
signal clk				: std_logic := '0';										-- clock input

signal CI_Start			: std_logic :='0';										-- start information

signal CI_PixClk		: std_logic := '0';										-- pixel clock received from the camera
signal CI_CAMData		: std_logic_vector (11 DOWNTO 0) := "000000000000";		-- pixel sent by the camera
signal CI_FrameValid	: std_logic := '0';										-- 1 if the frame is valid
signal CI_LineValid		: std_logic := '0';										-- 1 if the line is valid

signal CI_UsedWords		: std_logic_vector (9 DOWNTO 0) := "0000000000";		-- 16 bits used words in the FIFO

signal end_sim	: boolean := false;

constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
constant HalfPeriod_cam  : TIME := 53.4 ns;  -- clk_CAM = 18.73 MHz -> T_CAM = 53.4 ns -> T/2 = 26.7 ns
	
BEGIN 
DUT : Camera_Interface	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		CI_nReset => nReset,
		CI_Clk => clk,
		
		CI_Start => CI_Start,
		
		CI_PixClk => CI_PixClk,
		CI_CAMData => CI_CAMData,
		CI_FrameValid => CI_FrameValid,
		CI_LineValid => CI_LineValid,
		
		CI_UsedWords => CI_UsedWords
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
	
	variable G1 : std_logic_vector (11 DOWNTO 0) := "110000000000";
	variable R : std_logic_vector (11 DOWNTO 0) := "100000000000";
	variable B : std_logic_vector (11 DOWNTO 0) := "010000000000";
	variable G2 : std_logic_vector (11 DOWNTO 0) := "000000000000";
	
	variable inc1 : std_logic_vector (11 DOWNTO 0) := "000000000000";
	variable inc2 : std_logic_vector (11 DOWNTO 0) := "000000000000";

Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Start the acquisition
	wait until rising_edge(clk);
	CI_Start <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	-- CAM_Line_Valid = 1
	CI_LineValid <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	-- CAM_Frame_Valid = 1
	CI_FrameValid <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	inc2 := "000000000000";
	
	loop_r: FOR row IN 1 TO 240 LOOP
	
		inc1 := "000000000000";
	
		loop_row_1: FOR c1 IN 1 TO 320 LOOP		
			-- First pixel
			CI_PixClk <= '1';
			CI_CAMData <= std_logic_vector(unsigned(G1) + unsigned(inc1) + unsigned(inc2));
			wait for HalfPeriod_cam;
			CI_PixClk <= '0';
			wait for HalfPeriod_cam;
		
			-- Second pixel
			CI_PixClk <= '1';
			CI_CAMData <= std_logic_vector(unsigned(R) + unsigned(inc1) + unsigned(inc2));
			wait for HalfPeriod_cam;
			CI_PixClk <= '0';
			wait for HalfPeriod_cam;
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_1;
		
		inc1 := "000000000000";
		
		loop_row_2: FOR c2 IN 1 TO 320 LOOP
			-- First pixel
			CI_PixClk <= '1';
			CI_CAMData <= std_logic_vector(unsigned(B) + unsigned(inc1) + unsigned(inc2));
			wait for HalfPeriod_cam;
			CI_PixClk <= '0';
			wait for HalfPeriod_cam;
		
			-- Second pixel
			CI_PixClk <= '1';
			CI_CAMData <= std_logic_vector(unsigned(G2) + unsigned(inc1) + unsigned(inc2));
			wait for HalfPeriod_cam;
			CI_PixClk <= '0';
			wait for HalfPeriod_cam;
			
			if CI_UsedWords <= "1111111011" then
				CI_UsedWords <= std_logic_vector(unsigned(CI_UsedWords) + 1);
			end if;
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_2;
		
		inc2 := std_logic_vector(unsigned(inc2) + 1);
		
	END LOOP loop_r;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;