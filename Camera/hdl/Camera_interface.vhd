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
END Camera_Interface;

ARCHITECTURE bhv OF Camera_Interface IS
	signal		iRegStatus			: std_logic_vector (7 DOWNTO 0);	-- internal register for an overall status of the acquisition
	signal		iRegRGB				: std_logic_vector (15 DOWNTO 0); 	-- internal register for the actual computed pixel with 5*6*5 RGB format
	
	TYPE Memory is array (639 DOWNTO 0) of std_logic_vector (11 DOWNTO 0);
	signal		iRegMemory			: Memory; 							-- internal phantom memory register for the even read rows
	
	signal		iRegCountEnable		: std_logic;						-- internal phantom register to divide the FPGA clock
	signal		iRegRead			: std_logic;						-- internal phantom register to wait 1 rising edge before read
	signal		iregFIFOWrite		: std_logic;						-- internal phantom register to tell when FIFO_Write_Access is 1
	signal		iRegColumnCounter	: std_logic_vector (9 DOWNTO 0);	-- phantom counter from 0 to 3 to know if we are reading a valid column and not a skipped one
	signal		iRegBlue			: std_logic_vector (11 DOWNTO 0); 	-- internal phantom register fot the binning of the actual pixel blue color

BEGIN

-- Process to send the nReset to the camera
CameraReset:
Process(CI_nReset)
Begin
	CAM_nReset <= CI_nReset;
end process CameraReset;

-- Process to divide the clock
ClkDivider:
Process(CI_nReset, CI_Clk)
Begin
	if CI_nReset = '0' then	-- reset the internal phantom counter enabler register when pushing the reset key
		iRegCountEnable	<= '0';
	elsif rising_edge(CI_Clk) then -- toggle the iRegCountEnable in order to divide the in clock by 2, FPGA clock = 50 MHz, CAM_XClk = 25 MHz
		iRegCountEnable <= NOT iRegCountEnable;
	end if;
end process ClkDivider;

-- Process to send the clock to the camera
CameraClk:
Process(iRegStatus, iRegCountEnable)
Begin
	if iRegStatus (0) = '1' then
		CAM_XClk <= iRegCountEnable;
	else
		CAM_XClk <= '0';
	end if;
end process CameraClk;

-- Process to write the internal registers
-- Process to write the internal memory register with the even rows
MainProcess:
Process(CI_nReset, CI_Clk, CAM_PixClk)
Begin
	if CI_nReset = '0' then
		iRegStatus <= (others => '0');
		iRegRGB <= (others => '0');
		iRegMemory <= (others => "000000000000");
		iRegBlue <= (others => '0');
		iRegColumnCounter <= "0000000000";
		FIFO_Write_Access <= '0';
		iRegFIFOWrite <= '0';
	elsif rising_edge(CI_Clk) then
		if AS_WriteEnable = '1' then
			case AS_Address is
				when "00" => iRegStatus (0) <= AS_WriteData (0);
				when others => null;
			end case;
		end if;
	elsif falling_edge(CAM_PixClk) then	-- read the pixel on the falling edge of the CAM_PixClk
		FIFO_Write_Access <= '0';	-- we don't want to put the data in the FIFO for the moment
		iRegFIFOWrite <= '0';
		if (CAM_Frame_Valid = '1') AND (CAM_Line_Valid = '1') then
			if iRegStatus (2) = '0' then	-- if we are on an even row
				iRegMemory(to_integer(unsigned(iRegColumnCounter))) <= CAM_Data;	-- put the pixel in the internal memory
				iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				if iRegColumnCounter = X"27F" then	-- if iRegColumnCounter = 639, reset it
					iRegColumnCounter <= "0000000000";
					iRegStatus (2) <= '1';	-- switch to the odd row
				end if;
			else	-- if we are on an odd row
				if iRegStatus (3) = '0' then	-- if we are on an even column (blue pixel)
					iRegBlue <= CAM_Data;	-- but we have to store this blue pixel
					iRegStatus (3) <= '1';	-- now switch to the odd column
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				else	-- if we are on an odd column (green G2 pixel)
					iRegRGB (15 DOWNTO 11) <= iRegMemory(to_integer(unsigned(iRegColumnCounter))) (11 DOWNTO 7); -- put the red pixel stored in the memory in iRegRGB
					iRegRGB (10 DOWNTO 5) <= std_logic_vector(to_unsigned(to_integer((signed(CAM_Data) + signed(iRegMemory(to_integer(unsigned(iRegColumnCounter) - 1))))/to_signed(integer(2), 2)), 4096)) (11 DOWNTO 6); -- compute the averaged green with the current cam data and the green G1 pixel stored in the memory and put it in iRegRGB
					iRegRGB (4 DOWNTO 0) <= iRegBlue (11 DOWNTO 7);	-- put the blue pixel stored in iRegBlue in iRegRGB
					FIFO_Write_Access <= '1';	-- we can write iRegRGB to the FIFO on the next rising edge of CAM_PixClk
					iRegFIFOWrite <= '1';
					iRegStatus (3) <= '0';	-- and switch to the next even column
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
					if iRegColumnCounter = X"27F" then	-- if iRegColumnCounter = 639, reset it
						iRegColumnCounter <= "0000000000";
						iRegStatus (2) <= '0';	-- switch to the even row
					end if;
				end if;
			end if;
		end if;
	end if;
end process MainProcess;

-- Process to put the datas in the FIFO
TransferData:
Process(CI_nReset, CAM_PixClk)
Begin
	if CI_nReset = '0' then
		FIFO_Data <= (others => 'Z');
	elsif rising_edge(CAM_PixClk) then
		if FIFO_Almost_Full = '0' AND iRegFIFOWrite = '1' then
			FIFO_Data <= iRegRGB;
		else
			FIFO_Data <= (others => 'Z');
		end if;
	end if;
end process TransferData;

-- Process to wait one rising edge before read
ActRead:
Process(CI_Clk)
Begin
	if rising_edge(CI_Clk) then
		iRegRead <= AS_ReadEnable;
	end if;
end process ActRead;

-- Process to read the internal registers
ReadProcess:
Process(iRegStatus, iRegRGB)
Begin
	AS_ReadData <= (others => 'Z');
	if iRegRead = '1' then
		case AS_Address is
			when "000" => AS_ReadData <= iRegStatus;
			when "001" => AS_ReadData <= iRegRGB (7 DOWNTO 0);
			when "010" => AS_ReadData <= iRegRGB (12 DOWNTO 8);
			when others => null;
		end case;
	end if;
end process ReadProcess;

END bhv;