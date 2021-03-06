-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Camera interface for the camera management device
--
-- 3 address:
--   0: status register
--   1: current RGB pixel register (7->0)
--   2: current RGB pixel register (12->8)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Camera_Interface IS
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
END Camera_Interface;

ARCHITECTURE bhv OF Camera_Interface IS
	signal	iRegStart			: std_logic;						-- internal register for the start information
	signal	iRegPending			: std_logic;						-- internal register for the pending information
	signal	iRegNewFrame		: std_logic;						-- internal register to know if a new frame is avalaible
	signal	iRegRow				: std_logic;						-- internal register to know on which row we are
	signal	iRegColumn			: std_logic;						-- internal register to know on which column we are
	signal	iRegFIFOWrite		: std_logic;						-- internal register to tell when CI_FIFO_WriteEnable is 1
	signal	iRegColumnCounter	: std_logic_vector (11 DOWNTO 0);	-- phantom counter from 0 to 3 to know if we are reading a valid column and not a skipped one
	
	TYPE Memory is array (639 DOWNTO 0) of std_logic_vector (11 DOWNTO 0);
	signal	iRegMemory			: Memory; 							-- internal memory register for the even read rows
	
	signal	iRegBlue			: std_logic_vector (11 DOWNTO 0); 	-- internal register fot the binning of the actual pixel blue color
	signal	iRegRGB				: std_logic_vector (15 DOWNTO 0); 	-- internal register for the actual computed pixel with 5*6*5 RGB format

BEGIN

-- Process to set the pending flag
Acquisition:
Process(CI_nReset, CI_Clk)
Begin
	if CI_nReset = '0' then
		iRegStart <= '0';
		iRegPending <= '0';
	elsif rising_edge(CI_Clk) then
		iRegStart <= CI_AS_Start;
		if CI_FIFO_UsedWords > "1111110000" then
			iRegPending <= '1';
		else
			iRegPending <= '0';
		end if;
	end if;
end process Acquisition;

-- Process to know when a new frame will be outputed
NewFrame:
Process(CI_nReset, CI_Clk)
Begin
	if CI_nReset = '0' then
		iRegNewFrame <= '0';
	elsif rising_edge(CI_Clk) then
		if iRegStart = '0' OR iRegPending = '1' then
			iRegNewFrame <= '0';
		elsif CI_CA_FrameValid = '0' AND CI_CA_LineValid = '0' then
			iRegNewFrame <= '1';
		end if;
	end if;
end process NewFrame;

-- Process to know the column number and the row parity
CountColumns:
Process(CI_nReset, CI_CA_PixClk)
Begin
	if CI_nReset = '0' then
		iRegColumnCounter <= (others => '0');
		iRegRow <= '0';
		iRegColumn <= '0';
	elsif rising_edge(CI_CA_PixClk) then	-- read the pixel on the falling edge of the CI_CA_PixClk
		if CI_CA_FrameValid = '1' AND CI_CA_LineValid = '1' AND iRegStart = '1' AND iRegPending = '0' AND iRegNewFrame = '1' then
			if iRegRow = '0' then	-- if we are on an even row
				if (iRegColumnCounter = X"27F") then	-- if iRegColumnCounter = 639, reset it
					iRegColumnCounter <= "000000000000";
					iRegRow <= '1';	-- switch to the odd row
				else
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				end if;
			else	-- if we are on an odd row
				if iRegColumn = '0' then	-- if we are on an even column (blue pixel)
					iRegColumn <= '1';	-- now switch to the odd column
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				else	-- if we are on an odd column (green G2 pixel)
					iRegColumn <= '0';	-- and switch to the next even column
					if iRegColumnCounter = X"27F" then	-- if iRegColumnCounter = 639, reset it
						iRegColumnCounter <= "000000000000";
						iRegRow <= '0';	-- switch to the even row
					else
						iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
					end if;
				end if;
			end if;
		elsif iRegStart = '0' OR iRegPending = '1' then
			iRegColumnCounter <= "000000000000";
			iRegRow <= '0';
			iRegColumn <= '0';
		end if;
	end if;
end process CountColumns;

-- Process to read the pixels and to compute evertything
MainProcess:
Process(CI_nReset, CI_CA_PixClk)

variable iRegColumnCounter_unsign : unsigned (11 DOWNTO 0);
variable iRegMemoryG1_unsign_12 : unsigned (11 DOWNTO 0);
variable CamDataG2_unsign_12 : unsigned (11 DOWNTO 0);
variable sumG_unsign_12 : unsigned (11 DOWNTO 0);
variable iRegMemoryG1_unsign_13 : unsigned (12 DOWNTO 0);
variable CamDataG2_unsign_13 : unsigned (12 DOWNTO 0);
variable sumG_unsign_13 : unsigned (12 DOWNTO 0);
variable sumG_std_12 : std_logic_vector (11 DOWNTO 0);

Begin
	if CI_nReset = '0' then
		iRegRGB <= (others => '0');
		iRegMemory <= (others => "000000000000");
		iRegBlue <= (others => '0');
		iRegFIFOWrite <= '0';
	elsif falling_edge(CI_CA_PixClk) then	-- read the pixel on the falling edge of the CI_CA_PixClk
		iRegFIFOWrite <= '0';
		if CI_CA_FrameValid = '1' AND CI_CA_LineValid = '1' AND iRegStart = '1' AND iRegPending = '0' AND iRegNewFrame = '1' then
			if iRegRow = '0' then	-- if we are on an even row
				iRegRGB <= (others => '0');
				iRegBlue <= (others => '0');
				iRegMemory(to_integer(unsigned(iRegColumnCounter))) <= CI_CA_Data;	-- put the pixel in the internal memory
			else	-- if we are on an odd row
				if iRegColumn = '0' then	-- if we are on an even column (blue pixel)
					iRegBlue <= CI_CA_Data;	-- but we have to store this blue pixel
				else	-- if we are on an odd column (green G2 pixel)
					iRegRGB (15 DOWNTO 11) <= iRegMemory(to_integer(unsigned(iRegColumnCounter))) (11 DOWNTO 7); -- put the red pixel stored in the memory in iRegRGB
					
					iRegColumnCounter_unsign := unsigned(iRegColumnCounter); -- iRegColumnCounter from std_logic_vector to unsigned
					iRegMemoryG1_unsign_12 := unsigned(iRegMemory(to_integer(iRegColumnCounter_unsign - 1))); -- pixel G1 stored in the memory
					CamDataG2_unsign_12 := unsigned(CI_CA_Data); -- pixel G2 from the camera data bus
					if iRegMemoryG1_unsign_12(11) = '1' AND CamDataG2_unsign_12(11) = '1' then
						iRegMemoryG1_unsign_13 := resize(iRegMemoryG1_unsign_12, iRegMemoryG1_unsign_13'length);
						CamDataG2_unsign_13 := resize(CamDataG2_unsign_12, CamDataG2_unsign_13'length);
						sumG_unsign_13 := iRegMemoryG1_unsign_13 + CamDataG2_unsign_13; -- G1 + G2, might be on 13 bits
						sumG_std_12 := std_logic_vector(sumG_unsign_13(12 DOWNTO 1));
					else
						sumG_unsign_12 := iRegMemoryG1_unsign_12 + CamDataG2_unsign_12;
						sumG_unsign_12 := sumG_unsign_12 srl 1;
						sumG_std_12 := std_logic_vector(sumG_unsign_12);
					end if;
					
					iRegRGB (10 DOWNTO 5) <= sumG_std_12 (11 DOWNTO 6); -- compute the averaged green with the current cam data and the green G1 pixel stored in the memory and put it in iRegRGB
					
					iRegRGB (4 DOWNTO 0) <= iRegBlue (11 DOWNTO 7);	-- put the blue pixel stored in iRegBlue in iRegRGB
					
					iRegFIFOWrite <= '1';
					if iRegColumnCounter = X"27F" then	-- if iRegColumnCounter = 639, reset it
						iRegMemory <= (others => "000000000000");
					end if;
				end if;
			end if;
		elsif iRegStart = '0' OR iRegPending = '1' then
			iRegRGB <= (others => '0');
			iRegMemory <= (others => "000000000000");
			iRegBlue <= (others => '0');
			iRegFIFOWrite <= '0';
		end if;
	end if;
end process MainProcess;

-- Process to put the datas in the FIFO
TransferData:
Process(CI_nReset, CI_CA_PixClk)
Begin
	if CI_nReset = '0' then
		CI_FIFO_WriteData <= (others => '0');
		CI_FIFO_WriteEnable <= '0';
		CI_AS_Pending <= '0';
	elsif rising_edge(CI_CA_PixClk) then
		CI_AS_Pending <= iRegPending;
		if iRegPending = '0' AND iRegFIFOWrite = '1' then
			CI_FIFO_WriteData <= iRegRGB;
			CI_FIFO_WriteEnable <= '1';	-- we can write iRegRGB to the FIFO on the next rising edge of CI_CA_PixClk
		else
			CI_FIFO_WriteEnable <= '0';
			CI_FIFO_WriteData <= (others => '0');
		end if;
	end if;
end process TransferData;

END bhv;