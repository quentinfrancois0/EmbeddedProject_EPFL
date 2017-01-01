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
		
		CI_CA_PixClk		: IN std_logic;							-- pixel clock received from the camera
		CI_CA_Data			: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		CI_CA_FrameValid	: IN std_logic;							-- 1 if the frame is valid
		CI_CA_LineValid		: IN std_logic;							-- 1 if the line is valid
		
		CI_AS_Start			: IN std_logic;							-- Start information
		
		CI_FIFO_WriteEnable	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
		CI_FIFO_WriteData	: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
		CI_FIFO_UsedWords	: IN std_logic_vector (9 DOWNTO 0)		-- 16 bits used words in the FIFO
	);
end component;

-- The signals provided by the testbench :
signal CI_nReset_test			: std_logic := '1';
signal CI_Clk_test				: std_logic := '0';

signal CI_CA_PixClk_test		: std_logic := '0';
signal CI_CA_Data_test			: std_logic_vector (11 DOWNTO 0) := "000000000000";
signal CI_CA_FrameValid_test	: std_logic := '0';
signal CI_CA_LineValid_test		: std_logic := '0';

signal CI_AS_Start_test			: std_logic := '0';

signal CI_FIFO_WriteEnable_test	: std_logic;
signal CI_FIFO_WriteData_test	: std_logic_vector (15 DOWNTO 0);
signal CI_FIFO_UsedWords_test	: std_logic_vector (9 DOWNTO 0) := "0000000000";

signal end_sim	: boolean := false;

constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
constant HalfPeriod_cam  : TIME := 53.4 ns;  -- clk_CAM = 18.73 MHz -> T_CAM = 53.4 ns -> T/2 = 26.7 ns
	
BEGIN 
DUT : Camera_Interface	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		CI_nReset 			=> CI_nReset_test,
		CI_Clk 				=> CI_Clk_test,
		
		CI_CA_PixClk 		=> CI_CA_PixClk_test,
		CI_CA_Data 			=> CI_CA_Data_test,
		CI_CA_FrameValid 	=> CI_CA_FrameValid_test,
		CI_CA_LineValid 	=> CI_CA_LineValid_test,
		
		CI_AS_Start 		=> CI_AS_Start_test,
		
		CI_FIFO_WriteEnable => CI_FIFO_WriteEnable_test,
		CI_FIFO_WriteData 	=> CI_FIFO_WriteData_test,
		CI_FIFO_UsedWords 	=> CI_FIFO_UsedWords_test
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		CI_Clk_test <= '0';
		wait for HalfPeriod;
		CI_Clk_test <= '1';
		wait for HalfPeriod;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process clk_process;

-- Process to generate the clock during the whole simulation
PixClk_process :
Process
Begin
	if not end_sim then	-- generate the clock while simulation is running
		CI_CA_PixClk_test <= '0';
		wait for HalfPeriod_cam;
		CI_CA_PixClk_test <= '1';
		wait for HalfPeriod_cam;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process PixClk_process;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(CI_Clk_test);
		CI_nReset_test <= '0';
		
		wait until rising_edge(CI_Clk_test);
		CI_nReset_test <= '1';
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
	wait until rising_edge(CI_Clk_test);
	CI_AS_Start_test <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	-- CAM_Line_Valid = 1
	CI_CA_LineValid_test <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	-- CAM_Frame_Valid = 1
	CI_CA_FrameValid_test <= '1';
	
	wait for 2*HalfPeriod_cam;
	
	inc2 := "000000000000";
	
	loop_r: FOR row IN 1 TO 2 LOOP
	
		inc1 := "000000000000";
	
		loop_row_1a: FOR c1 IN 1 TO 100 LOOP		
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G1) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(R) + unsigned(inc1) + unsigned(inc2));
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_1a;
		
		-- CI_CA_LineValid_test <= '0';
		
		loop_row_1b: FOR c1 IN 101 TO 120 LOOP		
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G1) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(R) + unsigned(inc1) + unsigned(inc2));
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_1b;
		
		-- CI_CA_LineValid_test <= '1';
		
		loop_row_1c: FOR c1 IN 121 TO 320 LOOP		
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G1) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(R) + unsigned(inc1) + unsigned(inc2));
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_1c;
		
		inc1 := "000000000000";
		
		loop_row_2a: FOR c2 IN 1 TO 59 LOOP
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(B) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G2) + unsigned(inc1) + unsigned(inc2));
			
			if CI_FIFO_UsedWords_test <= "1111111011" then
				CI_FIFO_UsedWords_test <= std_logic_vector(unsigned(CI_FIFO_UsedWords_test) + 1);
			end if;
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_2a;
		
		-- CI_CA_FrameValid_test <= '0';
		
		loop_row_2b: FOR c2 IN 60 TO 227 LOOP
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(B) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G2) + unsigned(inc1) + unsigned(inc2));
			
			if CI_FIFO_UsedWords_test <= "1111111011" then
				CI_FIFO_UsedWords_test <= std_logic_vector(unsigned(CI_FIFO_UsedWords_test) + 1);
			end if;
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_2b;
		
		-- CI_CA_FrameValid_test <= '1';
		
		loop_row_2c: FOR c2 IN 228 TO 320 LOOP
			-- First pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(B) + unsigned(inc1) + unsigned(inc2));
		
			-- Second pixel
			wait until rising_edge(CI_CA_PixClk_test);
			CI_CA_Data_test <= std_logic_vector(unsigned(G2) + unsigned(inc1) + unsigned(inc2));
			
			if CI_FIFO_UsedWords_test <= "1111111011" then
				CI_FIFO_UsedWords_test <= std_logic_vector(unsigned(CI_FIFO_UsedWords_test) + 1);
			end if;
			
			inc1 := std_logic_vector(unsigned(inc1) + 1);
		END LOOP loop_row_2c;
		
		inc2 := std_logic_vector(unsigned(inc2) + 1);
		
	END LOOP loop_r;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process test;

END bhv;