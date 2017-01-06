-- Design of a camera management device
-- Avalon master/slave unit
-- 
-- Authors : Nicolas Berling & Quentin Fran�ois
-- Date : ??.11.2016
--
-- Top level for the camera management device

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Top_Camera_Controller IS
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
END Top_Camera_Controller;

ARCHITECTURE bhv OF Top_Camera_Controller IS
	
	COMPONENT Avalon_Slave
        PORT(
			AS_nReset			: IN std_logic;							-- nReset input
			AS_Clk				: IN std_logic;							-- clock input
		
			AS_AB_Address		: IN std_logic_vector (3 DOWNTO 0);		-- address bus
			AS_AB_ReadEnable	: IN std_logic;							-- read enabler
			AS_AB_WriteEnable	: IN std_logic;							-- write enabler
			AS_AB_ReadData		: OUT std_logic_vector (31 DOWNTO 0);	-- data bus (read)
			AS_AB_WriteData		: IN std_logic_vector (31 DOWNTO 0);	-- data bus (write)
		
			AS_ALL_Start		: OUT std_logic;						-- Start information
			
			AS_AM_StartAddress	: OUT std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
			AS_AM_Length		: OUT std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
			AS_AM_Status		: IN std_logic;							-- 1 when the image has been written to the memory
			
			AS_CI_Pending		: IN std_logic							-- Pending information
		);
	END COMPONENT;
	
	COMPONENT Avalon_Master
        PORT(
			AM_nReset			: IN std_logic;							-- nReset input
			AM_Clk				: IN std_logic;							-- clock input
			
			AM_AB_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Address sent on the Avalon bus
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
	END COMPONENT;
	
	COMPONENT Camera_Interface
        PORT(
			CI_nReset			: IN std_logic;							-- nReset input
			CI_Clk				: IN std_logic;							-- clock input
		
			CI_CA_PixClk		: IN std_logic;							-- pixel clock received from the camera
			CI_CA_Data			: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
			CI_CA_FrameValid	: IN std_logic;							-- 1 if the frame is valid
			CI_CA_LineValid		: IN std_logic;							-- 1 if the line is valid
			
			CI_AS_Start			: IN std_logic;							-- Start information
			CI_AS_Pending		: OUT std_logic;						-- Pending information
			
			CI_FIFO_WriteEnable	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
			CI_FIFO_WriteData	: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
			CI_FIFO_UsedWords	: IN std_logic_vector (9 DOWNTO 0)		-- 16 bits used words in the FIFO
		);
	END COMPONENT;
	
	COMPONENT FIFO
		PORT(
			FIFO_Reset			: IN std_logic;
		
			FIFO_WriteClk		: IN STD_LOGIC ;
			FIFO_CI_WriteData	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			FIFO_CI_WriteEnable	: IN STD_LOGIC ;
			FIFO_CI_UsedWords	: OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
			
			FIFO_ReadClk		: IN STD_LOGIC ;
			FIFO_AM_ReadData	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
			FIFO_AM_ReadCheck	: IN STD_LOGIC ;
			FIFO_AM_UsedWords	: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
		);
	END COMPONENT;

signal Sig_Reset		: std_logic;
signal Sig_Start		: std_logic;

signal Sig_StartAddress	: std_logic_vector (31 DOWNTO 0);
signal Sig_Length		: std_logic_vector (31 DOWNTO 0);
signal Sig_Status		: std_logic;

signal Sig_ReadCheck	: std_logic;
signal Sig_ReadData		: std_logic_vector	(31 DOWNTO 0);
signal Sig_AM_UsedWords	: std_logic_vector (8 DOWNTO 0);

signal Sig_WriteEnable	: std_logic;
signal Sig_WriteData	: std_logic_vector	(15 DOWNTO 0);
signal Sig_CI_UsedWords	: std_logic_vector (9 DOWNTO 0);
signal Sig_Pending		: std_logic;

BEGIN

	low_Avalon_Slave : Avalon_slave
		PORT MAP (
			AS_nReset			=> TL_nReset,
			AS_Clk 				=> TL_MainClk,
			
			AS_AB_Address		=> TL_AS_AB_Address,
			AS_AB_ReadEnable	=> TL_AS_AB_ReadEnable,
			AS_AB_WriteEnable	=> TL_AS_AB_WriteEnable,
			AS_AB_ReadData		=> TL_AS_AB_ReadData,
			AS_AB_WriteData		=> TL_AS_AB_WriteData,
			
			AS_ALL_Start 		=> Sig_Start,
			
			AS_AM_StartAddress	=> Sig_StartAddress,
			AS_AM_Length 		=> Sig_Length,
			AS_AM_Status		=> Sig_Status,
			
			AS_CI_Pending		=> Sig_Pending
		);
		
	low_Avalon_Master : Avalon_master
		PORT MAP (
			AM_nReset 			=> TL_nReset,
			AM_Clk 				=> TL_MainClk,
			
			AM_AB_MemoryAddress	=> TL_AM_AB_MemoryAddress,
			AM_AB_MemoryData	=> TL_AM_AB_MemoryData,
			AM_AB_WriteAccess	=> TL_AM_AB_WriteAccess,
			AM_AB_BurstCount	=> TL_AM_AB_BurstCount,
			AM_AB_WaitRequest	=> TL_AM_AB_WaitRequest,
			
			AM_AS_Start			=> Sig_Start,
			AM_AS_StartAddress	=> Sig_StartAddress,
			AM_AS_Length		=> Sig_Length,
			AM_AS_Status		=> Sig_Status,
			
			AM_FIFO_ReadCheck	=> Sig_ReadCheck,
			AM_FIFO_ReadData 	=> Sig_ReadData,
			AM_FIFO_UsedWords 	=> Sig_AM_UsedWords
		);
		
	low_Camera_Interface : Camera_Interface
		PORT MAP (
			CI_nReset			=> TL_nReset,
			CI_Clk				=> TL_MainClk,
		
			CI_CA_PixClk		=> TL_PixClk,
			CI_CA_Data			=> TL_CI_CA_Data,
			CI_CA_FrameValid	=> TL_CI_CA_FrameValid,
			CI_CA_LineValid		=> TL_CI_CA_LineValid,
			
			CI_AS_Start			=> Sig_Start,
			CI_AS_Pending		=> Sig_Pending,
		
			CI_FIFO_WriteEnable	=> Sig_WriteEnable,
			CI_FIFO_WriteData	=> Sig_WriteData,
			CI_FIFO_UsedWords	=> Sig_CI_UsedWords
		);

ResetFIFO:
Process(TL_nReset, Sig_Start)
Begin
	Sig_Reset <= not(TL_nReset AND Sig_Start);
end process ResetFIFO;
	
	low_FIFO : FIFO
		PORT MAP (
			FIFO_Reset			=> Sig_Reset,
		
			FIFO_WriteClk		=> TL_PixClk,
			FIFO_CI_WriteData	=> Sig_WriteData,
			FIFO_CI_WriteEnable	=> Sig_WriteEnable,
			FIFO_CI_UsedWords	=> Sig_CI_UsedWords,
			
			FIFO_ReadClk		=> TL_MainClk,
			FIFO_AM_ReadData	=> Sig_ReadData,
			FIFO_AM_ReadCheck	=> Sig_ReadCheck,
			FIFO_AM_UsedWords	=> Sig_AM_UsedWords
	);

END bhv;