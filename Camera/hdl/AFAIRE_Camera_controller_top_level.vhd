-- Design of a camera management device
-- Avalon master/slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Top level for the camera management device

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Top IS
	PORT(
		TL_nReset			: IN std_logic;							-- nReset input
		TL_Clk				: IN std_logic;							-- clock input
		
		TL_Address			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
		TL_ReadEnable		: IN std_logic;							-- read enabler
		TL_WriteEnable		: IN std_logic;							-- write enabler
		TL_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		TL_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		TL_WaitRequest		: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
		TL_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);			-- Number of datas in one burst
		
		TL_XClk				: OUT std_logic;						-- clock sent to the camera
		TL_PixClk			: IN std_logic;							-- pixel clock received from the camera
		TL_Data				: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		TL_Frame_Valid		: IN std_logic;							-- 1 if the frame is valid
		TL_Line_Valid		: IN std_logic;							-- 1 if the line is valid
	);
END Top;

ARCHITECTURE bhv OF Top IS
	
	COMPONENT Avalon_Slave
        PORT(
			AS_nReset			: IN std_logic;							-- nReset input
			AS_Clk				: IN std_logic;							-- clock input
		
			AS_Address			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
			AS_ReadEnable		: IN std_logic;							-- read enabler
			AS_WriteEnable		: IN std_logic;							-- write enabler
			AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
			AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
			AS_Start			: OUT std_logic_vector					-- Start information
			AS_StartAddress		: OUT std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
			AS_Length			: OUT std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		);
	END COMPONENT;
	
	COMPONENT Avalon_Master
        PORT(
			AM_nReset		: IN std_logic;							-- nReset input
			AM_Clk			: IN std_logic;							-- clock input
		
			AM_Start		: IN std_logic;							-- Start command
			AM_StartAddress	: IN std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
			AM_Length		: IN std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		
			AM_AlmostEmpty	: IN std_logic;							-- 1 when FIFO contains at least the burst length, 0 otherwise
			AM_ReadAccess	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
			AM_FIFOData		: IN std_logic_vector (15 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
			AM_Address		: OUT std_logic_vector (15 DOWNTO 0);	-- Address sent on the Avalon bus
			AM_AvalonData	: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
			AM_WriteRequest	: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
			AM_BurstCount	: OUT std_logic (7 DOWNTO 0);			-- Number of datas in one burst
			AM_WaitRequest	: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
		);
	END COMPONENT;
	
	COMPONENT Camera_Interface
        PORT(
			CI_nReset		: IN std_logic;							-- nReset input
			CI_Clk			: IN std_logic;							-- clock input
		
			CI_WriteData	: IN std_logic_vector (7 DOWNTO 0);		-- write data bus
			CI_ReadData		: OUT std_logic_vector (7 DOWNTO 0);	-- read data bus
			CI_WriteEnable	: IN std_logic;							-- write enable
			CI_ReadEnable	: IN std_logic;							-- read enable
			CI_Address		: IN std_logic_vector (1 DOWNTO 0);		-- address bus
		
			CI_nReset		: OUT std_logic;						-- nReset sent to the camera
			CI_XClk			: OUT std_logic;						-- clock sent to the camera
			CI_PixClk		: IN std_logic;							-- pixel clock received from the camera
			CI_CAMData		: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
			CI_Frame_Valid	: IN std_logic;							-- 1 if the frame is valid
			CI_Line_Valid	: IN std_logic;							-- 1 if the line is valid
		
			CI_WriteAccess	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
			CI_FIFOData		: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
			CI_Almost_Full	: IN std_logic							-- 1 = FIFO has less than four words free, 0 = everything is okay
		);
	END COMPONENT;
	
	COMPONENT FIFO
		PORT(
			FIFO_nReset			: IN STD_LOGIC;
			FIFO_Clk			: IN STD_LOGIC;
			
			FIFO_CIData			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			FIFO_ReadAccess		: IN STD_LOGIC;
			FIFO_WriteAccess	: IN STD_LOGIC;
			FIFO_AlmostEmpty	: OUT STD_LOGIC;
			FIFO_AlmostFull		: OUT STD_LOGIC;
			FIFO_AMData			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	END COMPONENT;

signal Start				: std_logic_vector;					-- Start information	
signal StartAddress			: std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
signal Length				: std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas

signal Clk					: STD_LOGIC;
signal ReadAccess			: std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
			
signal WriteAccess			: std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
signal CIData				: std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller

signal AlmostEmpty			: std_logic;						-- 1 when FIFO contains at least the burst length, 0 otherwise
signal AlmostFull			: std_logic;						-- 1 = FIFO has less than four words free, 0 = everything is okay
signal AMData				: std_logic_vector (15 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller

BEGIN

	low_Avalon_Slave : Avalon_Slave
		PORT MAP (
			AS_nReset			=> TL_nReset,
			AS_Clk 				=> TL_Clk,
			
			AS_Address			=> TL_Address,
			AS_ReadEnable		=> TL_ReadEnable,
			AS_WriteEnable		=> TL_WriteEnable,
			AS_ReaData			=> TL_ReadData,
			AS_WriteData		=> TL_WriteData,
			
			AS_Start 			=> Start,
			AS_StartAddress		=> StartAddress,
			AS_Length 			=> Length
		);
		
	low_Avalon_Master : Avalon_Master
		PORT MAP (
			AM_nReset 			=> TL_nReset,
			AM_Clk 				=> TL_Clk,
			
			AM_AlmostEmpty 		=> AlmostEmpty,
			AM_ReadAccess		=> ReadAccess,
			AM_FIFOData 		=> AMData,
			
			AM_Start			=> Start,
			AM_Start_Address	=> StartAddress,
			AM_Length			=> Length,
			
			AM_Address			=> TL_Address,
			AM_AvalonData		=> TL_WriteData,
			AM_WriteRequest		=> TL_WaitRequest,
			AM_BurstCount		=> TL_BurstCount,
			AM_WaitRequest		=> TL_WaitRequest
		);
		
	low_Camera_Interface : Camera_Interface
		PORT MAP (
			CI_nReset		=> TL_nReset,
			CI_Clk			=> TL_Clk,
		
			CI_WriteData	=> TL_WriteData,
			CI_ReadData		=> TL_ReadData,
			CI_WriteEnable	=> TL_WriteEnable,
			CI_ReadEnable	=> TL_ReadEnable,
			CI_Address		=> TL_Address,
		
			CI_XClk			=> TL_XClk,
			CI_PixClk		=> TL_PixClk,
			CI_CAMData		=> TL_Data,
			CI_Frame_Valid	=> TL_Frame_Valid,
			CI_Line_Valid	=> TL_Line_Valid,
		
			CI_WriteAccess	=> WriteAccess,
			CI_FIFOData		=> CIData,
			CI_Almost_Full	=> AlmostFull
		);
		
	low_FIFO : FIFO
		PORT MAP (
			FIFO_nReset			=> TL_nReset,
			FIFO_Clk			=> TL_Clk,
			
			FIFO_CIData			=> CIData,
			FIFO_ReadAccess		=> ReadAccess,
			FIFO_WriteAccess	=> WriteAccess,
			FIFO_AlmostEmpty	=> AlmostEmpty,
			FIFO_AlmostFull		=> AlmostFull,
			FIFO_AMData			=> AMData
	);

END bhv;