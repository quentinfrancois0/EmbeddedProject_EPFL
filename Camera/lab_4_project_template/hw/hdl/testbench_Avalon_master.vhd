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
		AM_nReset			: IN std_logic;							-- nReset input
		AM_Clk				: IN std_logic;							-- clock input
		
		AM_AB_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_AB_MemoryData	: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_AB_WriteAccess	: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_AB_BurstCount	: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_AB_WaitRequest	: IN std_logic;							-- Pin waitrequest which is 0 when the bus is available
		
		AM_AS_Start			: IN std_logic;							-- Start command
		AM_AS_StartAddress	: IN std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AM_AS_Length		: IN std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		AM_AS_Status		: OUT std_logic;						-- 1 when the image has been written to the memory
		
		AM_FIFO_ReadCheck	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		AM_FIFO_ReadData	: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		AM_FIFO_UsedWords	: IN std_logic_vector (8 DOWNTO 0)		-- number of 32 bits words
	);
end component;

-- The interconnection signals :
signal AM_nReset_test			: std_logic := '1';
signal AM_Clk_test				: std_logic := '0';

signal AM_AB_MemoryAddress_test	: std_logic_vector (31 DOWNTO 0);
signal AM_AB_MemoryData_test	: std_logic_vector (31 DOWNTO 0);
signal AM_AB_WriteAccess_test	: std_logic;
signal AM_AB_BurstCount_test	: std_logic_vector (7 DOWNTO 0);
signal AM_AB_WaitRequest_test	: std_logic := '0';

signal AM_AS_Start_test			: std_logic := '0';
signal AM_AS_StartAddress_test	: std_logic_vector (31 DOWNTO 0) := X"10000000";
signal AM_AS_Length_test		: std_logic_vector (31 DOWNTO 0) := X"00025800";
signal AM_AS_Status_test		: std_logic;

signal AM_FIFO_ReadCheck_test	: std_logic;
signal AM_FIFO_ReadData_test	: std_logic_vector (31 DOWNTO 0) := X"00000000";
signal AM_FIFO_UsedWords_test	: std_logic_vector (8 DOWNTO 0) := "000000000";

signal Data_info : std_logic_vector (31 DOWNTO 0) := X"00000002";
signal end_sim	: boolean := false;
constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
	
BEGIN 
DUT : Avalon_master	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		AM_nReset 			=> AM_nReset_test,
		AM_Clk 				=> AM_Clk_test,
		
		AM_AB_MemoryAddress => AM_AB_MemoryAddress_test,
		AM_AB_MemoryData 	=> AM_AB_MemoryData_test,
		AM_AB_WriteAccess 	=> AM_AB_WriteAccess_test,
		AM_AB_BurstCount 	=> AM_AB_BurstCount_test,
		AM_AB_WaitRequest 	=> AM_AB_WaitRequest_test,
		
		AM_AS_StartAddress 	=> AM_AS_StartAddress_test,
		AM_AS_Length 		=> AM_AS_Length_test,
		AM_AS_Start 		=> AM_AS_Start_test,
		AM_AS_Status 		=> AM_AS_Status_test,
		
		AM_FIFO_ReadCheck 	=> AM_FIFO_ReadCheck_test,
		AM_FIFO_ReadData 	=> AM_FIFO_ReadData_test,
		AM_FIFO_UsedWords 	=> AM_FIFO_UsedWords_test
	);

-- Process to generate the clock during the whole simulation
clk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		AM_Clk_test <= '0';
		wait for HalfPeriod;
		AM_Clk_test <= '1';
		wait for HalfPeriod;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process clk_process;

transfer_fifo :
Process

	variable inc1 : std_logic_vector (31 DOWNTO 0) := X"00000000";
	variable inc2 : std_logic_vector (31 DOWNTO 0) := X"00000000";

Begin
	loop_img: FOR img IN 1 TO 2 LOOP

		inc1 := X"00000000";
		
		loop_pix: FOR pix IN 1 TO 38400 LOOP
		
			wait until rising_edge(AM_Clk_test);
			-- if AM_FIFO_ReadCheck_test = '1' then
			if AM_AB_WaitRequest_test = '0' then
				AM_FIFO_ReadData_test <= std_logic_vector(unsigned(inc1) + unsigned(inc2));
				inc1 := std_logic_vector(unsigned(inc1) + 1);
			end if;
			
		END LOOP loop_pix;
		
		inc2 := std_logic_vector(unsigned(inc2) + X"10000000");
		
	END LOOP loop_img;
	
	end_sim <= true;
	wait;
end process transfer_fifo;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(AM_Clk_test);
		AM_nReset_test <= '0';
		
		wait until rising_edge(AM_Clk_test);
		AM_nReset_test <= '1';
	end procedure toggle_reset;
	
Begin
	-- Toggling the reset
	toggle_reset;
	
	-- AM_AS_Start_test => 1
	wait until rising_edge(AM_Clk_test);
	AM_AS_Start_test <= '1';
	
	-- Number words at 1 => not one burst in the FIFO
	wait for 6*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_FIFO_UsedWords_test <= "000010000";
	
	-- Block the third transfer of the first burst
	wait for 6*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AB_WaitRequest_test <= '1';
	
	wait for 10*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AB_WaitRequest_test <= '0';
	
	-- Block the first transfer of the second burst
	wait for 30*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AB_WaitRequest_test <= '1';
	
	wait for 10*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AB_WaitRequest_test <= '0';
	
	wait for 100000*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AS_Start_test <= '0';
	
	wait for 50*HalfPeriod;
	wait until rising_edge(AM_Clk_test);
	AM_AS_Start_test <= '1';

	wait;
end process test;

END bhv;