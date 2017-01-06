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
		TL_nReset				: IN std_logic;							-- nReset input
		TL_MainClk				: IN std_logic;							-- main clock input, FIFO read clock input
		TL_PixClk				: IN std_logic;							-- pixel clock received from the camera, FIFO write clock input
		
		TL_AS_AB_Address		: IN std_logic_vector (3 DOWNTO 0);		-- address bus
		TL_AS_AB_ReadEnable		: IN std_logic;							-- read enabler
		TL_AS_AB_WriteEnable	: IN std_logic;							-- write enabler
		TL_AS_AB_ReadData		: OUT std_logic_vector (31 DOWNTO 0);	-- data bus (read)
		TL_AS_AB_WriteData		: IN std_logic_vector (31 DOWNTO 0);	-- data bus (write)
		
		TL_AM_AB_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Address sent on the Avalon bus
		TL_AM_AB_MemoryData		: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		TL_AM_AB_WriteAccess	: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		TL_AM_AB_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		TL_AM_AB_WaitRequest	: IN std_logic;							-- Pin waitrequest which is 0 when the bus is available
		
		TL_CI_CA_Data			: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		TL_CI_CA_FrameValid		: IN std_logic;							-- 1 if the frame is valid
		TL_CI_CA_LineValid		: IN std_logic							-- 1 if the line is valid
	);
end component;

-- The signals provided by the testbench :
signal TL_nReset_test				: std_logic := '1';
signal TL_MainClk_test				: std_logic := '0';
signal TL_PixClk_test				: std_logic := '0';

signal TL_AS_AB_Address_test		: std_logic_vector (3 DOWNTO 0) := "0000";
signal TL_AS_AB_ReadEnable_test		: std_logic := '0';
signal TL_AS_AB_WriteEnable_test	: std_logic := '0';
signal TL_AS_AB_ReadData_test		: std_logic_vector (31 DOWNTO 0);
signal TL_AS_AB_WriteData_test		: std_logic_vector (31 DOWNTO 0) := X"00000000";

signal TL_AM_AB_MemoryAddress_test	: std_logic_vector (31 DOWNTO 0);
signal TL_AM_AB_MemoryData_test		: std_logic_vector (31 DOWNTO 0);
signal TL_AM_AB_WriteAccess_test	: std_logic;
signal TL_AM_AB_BurstCount_test		: std_logic_vector (7 DOWNTO 0);
signal TL_AM_AB_WaitRequest_test	: std_logic := '0';

signal TL_CI_CA_Data_test			: std_logic_vector (11 DOWNTO 0) := X"000";
signal TL_CI_CA_FrameValid_test		: std_logic := '0';
signal TL_CI_CA_LineValid_test		: std_logic := '0';

signal end_sim	: boolean := false;

constant HalfPeriod  : TIME := 10 ns;  -- clk_FPGA = 50 MHz -> T_FPGA = 20ns -> T/2 = 10 ns
constant HalfPeriod_cam  : TIME := 53.4 ns;  -- clk_CAM = 18.73 MHz -> T_CAM = 53.4 ns -> T/2 = 26.7 ns
	
BEGIN 
DUT : Top_Camera_Controller	-- Component to test as Device Under Test       
	Port MAP(	-- from component => signal in the architecture
		TL_nReset 				=> TL_nReset_test,
		TL_MainClk 				=> TL_MainClk_test,
		TL_PixClk 				=> TL_PixClk_test,

		TL_AS_AB_Address 		=> TL_AS_AB_Address_test,
		TL_AS_AB_ReadEnable 	=> TL_AS_AB_ReadEnable_test,
		TL_AS_AB_WriteEnable 	=> TL_AS_AB_WriteEnable_test,
		TL_AS_AB_ReadData 		=> TL_AS_AB_ReadData_test,
		TL_AS_AB_WriteData 		=> TL_AS_AB_WriteData_test,

		TL_AM_AB_MemoryAddress 	=> TL_AM_AB_MemoryAddress_test,
		TL_AM_AB_MemoryData 	=> TL_AM_AB_MemoryData_test,
		TL_AM_AB_WriteAccess 	=> TL_AM_AB_WriteAccess_test,
		TL_AM_AB_BurstCount 	=> TL_AM_AB_BurstCount_test,
		TL_AM_AB_WaitRequest 	=> TL_AM_AB_WaitRequest_test,

		TL_CI_CA_Data 			=> TL_CI_CA_Data_test,
		TL_CI_CA_FrameValid 	=> TL_CI_CA_FrameValid_test,
		TL_CI_CA_LineValid 		=> TL_CI_CA_LineValid_test
	);

-- Process to generate the clock during the whole simulation
MainClk_process :
Process
Begin
	if not end_sim then	-- generate the clocc while simulation is running
		TL_MainClk_test <= '0';
		wait for HalfPeriod;
		TL_MainClk_test <= '1';
		wait for HalfPeriod;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process MainClk_process;

-- Process to generate the clock during the whole simulation
PixClk_process :
Process
Begin
	if not end_sim then	-- generate the clock while simulation is running
		TL_PixClk_test <= '0';
		wait for HalfPeriod_cam;
		TL_PixClk_test <= '1';
		wait for HalfPeriod_cam;
	else	-- when the simulation is ended, just wait
		wait;
	end if;
end process PixClk_process;

CamData :
Process

	variable G1 : std_logic_vector (11 DOWNTO 0) := "110000000000";
	variable R : std_logic_vector (11 DOWNTO 0) := "100000000000";
	variable B : std_logic_vector (11 DOWNTO 0) := "010000000000";
	variable G2 : std_logic_vector (11 DOWNTO 0) := "000000000000";
	
	variable inc1 : std_logic_vector (11 DOWNTO 0) := "000000000000";
	variable inc2 : std_logic_vector (11 DOWNTO 0) := "000000000000";

Begin
	loop_img: FOR img IN 1 TO 4 LOOP
		loop_r: FOR row IN 1 TO 240 LOOP
			wait until rising_edge(TL_PixClk_test);
			TL_CI_CA_FrameValid_test <= '1';
			TL_CI_CA_LineValid_test <= '1';
		
			loop_row_1: FOR c1 IN 1 TO 320 LOOP	
				-- First pixel
				TL_CI_CA_Data_test <= std_logic_vector(unsigned(G1) + unsigned(inc1) + unsigned(inc2));
				wait until rising_edge(TL_PixClk_test);
			
				-- Second pixel
				TL_CI_CA_Data_test <= std_logic_vector(unsigned(R) + unsigned(inc1) + unsigned(inc2));
				wait until rising_edge(TL_PixClk_test);
				
				if c1 = 320 then
					inc1 := "000000000000";
					TL_CI_CA_LineValid_test <= '0';
				else
					inc1 := std_logic_vector(unsigned(inc1) + 1);
				end if;
			END LOOP loop_row_1;
			
			wait until rising_edge(TL_PixClk_test);
			TL_CI_CA_LineValid_test <= '1';
			
			loop_row_2: FOR c2 IN 1 TO 320 LOOP
				-- First pixel
				TL_CI_CA_Data_test <= std_logic_vector(unsigned(B) + unsigned(inc1) + unsigned(inc2));
				wait until rising_edge(TL_PixClk_test);
			
				-- Second pixel
				TL_CI_CA_Data_test <= std_logic_vector(unsigned(G2) + unsigned(inc1) + unsigned(inc2));
				wait until rising_edge(TL_PixClk_test);
				
				if c2 = 320 then
					inc1 := "000000000000";
					TL_CI_CA_LineValid_test <= '0';
				else
					inc1 := std_logic_vector(unsigned(inc1) + 1);
				end if;
			END LOOP loop_row_2;
			
			-- wait until rising_edge(TL_PixClk_test);
			TL_CI_CA_LineValid_test <= '0';
			
			if row = 240 then
				inc2 := "000000000000";
				inc1 := "000000000000";
				TL_CI_CA_FrameValid_test <= '0';
			else
				inc2 := std_logic_vector(unsigned(inc2) + 1);
			end if;
		END LOOP loop_r;
	END LOOP loop_img;
	
	-- Set end_sim to "true", so the clock generation stops
	end_sim <= true;
	wait;
end process CamData;

--	Process to test the component
test :
Process

	-- Procedure to toggle the reset
	Procedure toggle_reset is
	Begin
		wait until rising_edge(TL_MainClk_test);
		TL_nReset_test <= '0';
		
		wait until rising_edge(TL_MainClk_test);
		TL_nReset_test <= '1';
	end procedure toggle_reset;
	
	-- Procedure to write a register, inputs are (address, data_to_write)
	Procedure write_register(addr_write: std_logic_vector; data: std_logic_vector) is
	Begin
		wait until rising_edge(TL_MainClk_test);	-- write between two consecutive rising edges of the clock
		TL_AS_AB_WriteEnable_test <= '1';
		TL_AS_AB_Address_test <= addr_write;
		TL_AS_AB_WriteData_test <= data;
		
		wait until rising_edge(TL_MainClk_test);	-- then reset everything
		TL_AS_AB_WriteEnable_test <= '0';
		TL_AS_AB_Address_test <= X"0";
		TL_AS_AB_WriteData_test <= X"00000000";
	end procedure write_register;

	-- Procedure to read a register, input is (address)
	Procedure read_register(addr_read: std_logic_vector) is
	Begin
		wait until rising_edge(TL_MainClk_test);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		TL_AS_AB_ReadEnable_test <= '1';
		TL_AS_AB_Address_test <= addr_read;
		
		wait until rising_edge(TL_MainClk_test);
		wait until rising_edge(TL_MainClk_test);	-- then reset everything
		TL_AS_AB_ReadEnable_test <= '0';
		TL_AS_AB_Address_test <= X"0";
	end procedure read_register;
	
Begin
	-- Toggling the reset
	toggle_reset;
	
	-- Writing AS_AMCI_Start information = 0
	write_register(X"0", X"00000000");
	
	-- Writing start_adress = 0x00100000
	write_register(X"2", X"00100000");
	
	-- Writing AS_AM_Length = 320*240*2 = 0x00025800
	write_register(X"3", X"00025800");
	
	-- Writing AS_AMCI_Start information = 1
	write_register(X"0", X"00000001");
	
	-- Let's try to write the Length and the Start address, but should not work
	write_register(X"2", X"0000ffff");
	write_register(X"3", X"0000ffff");
	
	-- Reading the registers
	read_register(X"0");
	read_register(X"1");
	read_register(X"2");
	read_register(X"3");
	
	wait for 620000*HalfPeriod_cam;
	wait until rising_edge(TL_PixClk_test);
	write_register(X"0", X"00000000");
	
	wait for 50*HalfPeriod_cam;
	wait until rising_edge(TL_PixClk_test);
	write_register(X"0", X"00000001");
	
	wait for 620000*HalfPeriod_cam;
	wait until rising_edge(TL_PixClk_test);
	read_register(X"1");
	
	wait for 100*HalfPeriod;
	TL_AM_AB_WaitRequest_test <= '1';
	wait for 200*HalfPeriod;
	TL_AM_AB_WaitRequest_test <= '0';
	
	wait for 620000*HalfPeriod_cam;
	wait until rising_edge(TL_PixClk_test);
	read_register(X"1");
	
	wait;
end process test;

-- ReadStatus:
-- Process

	-- -- Procedure to read a register, input is (address)
	-- Procedure read_register(addr_read: std_logic_vector) is
	-- Begin
		-- wait until rising_edge(TL_MainClk_test);	-- set the read access, so the internal phantom read register will be set to 1 on the next rising edge of the clock
		-- TL_AS_AB_ReadEnable_test <= '1';
		-- TL_AS_AB_Address_test <= addr_read;
		
		-- wait until rising_edge(TL_MainClk_test);	-- then reset everything
		-- TL_AS_AB_ReadEnable_test <= '0';
		-- TL_AS_AB_Address_test <= X"0";
	-- end procedure read_register;

-- Begin
	-- if not end_sim then
		-- wait for 100000*HalfPeriod_cam;
		-- wait until rising_edge(TL_PixClk_test);
		-- read_register(X"1");
	-- else
		-- wait;
	-- end if;
-- end process ReadStatus;

END bhv;