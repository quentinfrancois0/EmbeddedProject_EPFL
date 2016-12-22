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

ENTITY Top_Camera_Controller IS
	PORT(
		TL_nReset			: IN std_logic;							-- nReset input
		TL_Clk				: IN std_logic;							-- clock input
		
		TL_Address			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
		TL_ReadEnable		: IN std_logic;							-- read enabler
		TL_WriteEnable		: IN std_logic;							-- write enabler
		TL_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		TL_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		TL_MemoryAddress	: OUT std_logic_vector (15 DOWNTO 0);	-- Address sent on the Avalon bus
		TL_AvalonData		: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
		TL_WriteRequest		: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		TL_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		TL_WaitRequest		: IN std_logic;							-- Pin waitrequest which is 0 when the bus is available
		
		TL_XClkIn			: OUT std_logic;						-- clock sent to the camera
		TL_PixClk			: IN std_logic;							-- pixel clock received from the camera
		TL_Data				: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		TL_FrameValid		: IN std_logic;							-- 1 if the frame is valid
		TL_LineValid		: IN std_logic							-- 1 if the line is valid
	);
END Top_Camera_Controller;

ARCHITECTURE bhv OF Top_Camera_Controller IS
	
	COMPONENT Avalon_Slave
        PORT(
			AS_nReset			: IN std_logic;							-- nReset input
			AS_Clk				: IN std_logic;							-- clock input
		
			AS_Address			: IN std_logic_vector (2 DOWNTO 0);		-- address bus
			AS_ReadEnable		: IN std_logic;							-- read enabler
			AS_WriteEnable		: IN std_logic;							-- write enabler
			AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
			AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
			AS_Start			: OUT std_logic;						-- Start information
			AS_StartAddress		: OUT std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
			AS_Length			: OUT std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
			AS_Status			: IN std_logic							-- 1 when the image has been written to the memory
		);
	END COMPONENT;
	
	COMPONENT Avalon_Master
        PORT(
			AM_nReset		: IN std_logic;							-- nReset input
			AM_Clk			: IN std_logic;							-- clock input
		
			AM_Start		: IN std_logic;							-- Start command
			AM_StartAddress	: IN std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
			AM_Length		: IN std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
			AM_Status		: OUT std_logic;						-- 1 when the image has been written to the memory
		
			AM_FIFOClk		: OUT std_logic;
			AM_ReadAccess	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
			AM_FIFOData		: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
			AM_UsedWords	: IN std_logic_vector (8 DOWNTO 0);		-- 1 when FIFO contains at least the burst length, 0 otherwise
		
			AM_MemoryAddress: OUT std_logic_vector (15 DOWNTO 0);	-- Address sent on the Avalon bus
			AM_AvalonData	: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
			AM_WriteRequest	: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
			AM_BurstCount	: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
			AM_WaitRequest	: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
		);
	END COMPONENT;
	
	COMPONENT Camera_Interface
        PORT(
			CI_nReset		: IN std_logic;							-- nReset input
			CI_Clk			: IN std_logic;							-- clock input
			
			CI_Start		: IN std_logic;							-- Start information
			
			CI_XClkIn		: OUT std_logic;						-- clock sent to the camera
			CI_PixClk		: IN std_logic;							-- pixel clock received from the camera
			CI_CAMData		: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
			CI_FrameValid	: IN std_logic;							-- 1 if the frame is valid
			CI_LineValid	: IN std_logic;							-- 1 if the line is valid
			
			CI_FIFOClk		: OUT std_logic;						-- FIFO clock = PixClk
			CI_WriteAccess	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
			CI_FIFOData		: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
			CI_UsedWords	: IN std_logic_vector (9 DOWNTO 0)		-- 16 bits used words in the FIFO
		);
	END COMPONENT;
	
	COMPONENT FIFO
		PORT(
			FIFO_Reset			: IN STD_LOGIC ;
		
			FIFO_CIClk			: IN STD_LOGIC ;
			FIFO_CIData			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			FIFO_WriteAccess	: IN STD_LOGIC ;
			FIFO_CIUsedWords	: OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
			
			FIFO_AMClk			: IN STD_LOGIC ;
			FIFO_AMData			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
			FIFO_ReadAccess		: IN STD_LOGIC ;
			FIFO_AMUsedWords	: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
		);
	END COMPONENT;

signal Sig_Reset			: std_logic;

signal Sig_Start			: std_logic;					-- Start information	
signal Sig_StartAddress		: std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
signal Sig_Length			: std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas

signal Sig_AMClk			: STD_LOGIC;
signal Sig_ReadAccess		: std_logic; -- 1 = information asked to the Fifo, 0 = no demand
signal Sig_AMData			: std_logic_vector	(31 DOWNTO 0);
signal Sig_AMUsedWords		: std_logic_vector (8 DOWNTO 0);
			
signal Sig_CIClk			: STD_LOGIC;
signal Sig_WriteAccess		: std_logic;
signal Sig_CIData			: std_logic_vector	(15 DOWNTO 0);
signal Sig_CIUsedWords		: std_logic_vector (9 DOWNTO 0);

BEGIN

	low_Avalon_Slave : Avalon_Slave
		PORT MAP (
			AS_nReset			=> TL_nReset,
			AS_Clk 				=> TL_Clk,
			
			AS_Address			=> TL_Address,
			AS_ReadEnable		=> TL_ReadEnable,
			AS_WriteEnable		=> TL_WriteEnable,
			AS_ReadData			=> TL_ReadData,
			AS_WriteData		=> TL_WriteData,
			
			AS_Start 			=> Sig_Start,
			AS_StartAddress		=> Sig_StartAddress,
			AS_Length 			=> Sig_Length
		);
		
	low_Avalon_Master : Avalon_Master
		PORT MAP (
			AM_nReset 			=> TL_nReset,
			AM_Clk 				=> TL_Clk,
			
			AM_Start			=> Sig_Start,
			AM_StartAddress		=> Sig_StartAddress,
			AM_Length			=> Sig_Length,
			
			AM_FIFOClk			=> Sig_AMClk,
			AM_ReadAccess		=> Sig_ReadAccess,
			AM_FIFOData 		=> Sig_AMData,
			AM_UsedWords 		=> Sig_AMUsedWords,
			
			AM_MemoryAddress	=> TL_MemoryAddress,
			AM_AvalonData		=> TL_AvalonData,
			AM_WriteRequest		=> TL_WriteRequest,
			AM_BurstCount		=> TL_BurstCount,
			AM_WaitRequest		=> TL_WaitRequest
		);
		
	low_Camera_Interface : Camera_Interface
		PORT MAP (
			CI_nReset		=> TL_nReset,
			CI_Clk			=> TL_Clk,
			
			CI_Start		=> Sig_Start,
		
			CI_XClkIn		=> TL_XClkIn,
			CI_PixClk		=> TL_PixClk,
			CI_CAMData		=> TL_Data,
			CI_FrameValid	=> TL_FrameValid,
			CI_LineValid	=> TL_LineValid,
		
			CI_FIFOClk		=> Sig_CIClk,
			CI_WriteAccess	=> Sig_WriteAccess,
			CI_FIFOData		=> Sig_CIData,
			CI_UsedWords	=> Sig_CIUsedWords
		);
		
ResetFIFO:
Process(TL_nReset)
Begin
	Sig_Reset <= not TL_nReset;
end process ResetFIFO;	
	
	low_FIFO : FIFO
		PORT MAP (
			FIFO_Reset			=> Sig_Reset,
		
			FIFO_CIClk			=> Sig_CIClk,
			FIFO_CIData			=> Sig_CIData,
			FIFO_WriteAccess	=> Sig_WriteAccess,
			FIFO_CIUsedWords	=> Sig_CIUsedWords,
			
			FIFO_AMClk			=> Sig_AMClk,
			FIFO_AMData			=> Sig_AMData,
			FIFO_ReadAccess		=> Sig_ReadAccess,
			FIFO_AMUsedWords	=> Sig_AMUsedWords
	);

END bhv;