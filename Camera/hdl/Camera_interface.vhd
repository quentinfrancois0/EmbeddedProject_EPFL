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
		CI_nReset		: IN std_logic;							-- nReset input
		CI_Clk			: IN std_logic;							-- clock input
		
		CI_WriteData	: IN std_logic_vector (7 DOWNTO 0);		-- write data bus
		CI_ReadData		: OUT std_logic_vector (7 DOWNTO 0);	-- read data bus
		CI_WriteEnable	: IN std_logic;							-- write enable
		CI_ReadEnable	: IN std_logic;							-- read enable
		CI_Address		: IN std_logic_vector (1 DOWNTO 0);		-- address bus
		
		CI_XClk			: OUT std_logic;						-- clock sent to the camera
		CI_PixClk		: IN std_logic;							-- pixel clock received from the camera
		CI_CAMData		: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		CI_FrameValid	: IN std_logic;							-- 1 if the frame is valid
		CI_LineValid	: IN std_logic;							-- 1 if the line is valid
		
		CI_WriteAccess	: OUT std_logic;						-- 1 = write asked to the FIFO, 0 = no demand
		CI_FIFOData		: OUT std_logic_vector (15 DOWNTO 0);	-- 16 bits pixel stored in the FIFO by the camera controller
		CI_AlmostFull	: IN std_logic							-- 1 = FIFO has less than four words free, 0 = everything is okay
	);
END Camera_Interface;

ARCHITECTURE bhv OF Camera_Interface IS
	signal		iRegStatus			: std_logic_vector (7 DOWNTO 0);	-- internal register for an overall status of the acquisition
	signal		iRegRGB				: std_logic_vector (15 DOWNTO 0); 	-- internal register for the actual computed pixel with 5*6*5 RGB format
	
	TYPE Memory is array (639 DOWNTO 0) of std_logic_vector (11 DOWNTO 0);
	signal		iRegMemory			: Memory; 							-- internal phantom memory register for the even read rows
	
	signal		iRegCountEnable		: std_logic;						-- internal phantom register to divide the FPGA clock
	signal		iRegRead			: std_logic;						-- internal phantom register to wait 1 rising edge before read
	signal		iregFIFOWrite		: std_logic;						-- internal phantom register to tell when CI_WriteAccess is 1
	signal		iRegColumnCounter	: std_logic_vector (11 DOWNTO 0);	-- phantom counter from 0 to 3 to know if we are reading a valid column and not a skipped one
	signal		iRegBlue			: std_logic_vector (11 DOWNTO 0); 	-- internal phantom register fot the binning of the actual pixel blue color

BEGIN

-- Process to divide the clock
ClkDivider:
Process(CI_nReset, CI_Clk)
Begin
	if CI_nReset = '0' then	-- reset the internal phantom counter enabler register when pushing the reset key
		iRegCountEnable	<= '0';
	elsif rising_edge(CI_Clk) then -- toggle the iRegCountEnable in order to divide the in clock by 2, FPGA clock = 50 MHz, CI_XClk = 25 MHz
		iRegCountEnable <= NOT iRegCountEnable;
	end if;
end process ClkDivider;

-- Process to send the clock to the camera
CameraClk:
Process(iRegStatus, iRegCountEnable)
Begin
	if iRegStatus (0) = '1' then
		CI_XClk <= iRegCountEnable;
	else
		CI_XClk <= '0';
	end if;
end process CameraClk;

-- Process to write the internal registers
-- Process to write the internal memory register with the even rows
MainProcess:
Process(CI_nReset, CI_Clk, CI_PixClk)

variable iRegColumnCounter_unsign : unsigned (11 DOWNTO 0);
variable iRegMemory_unsign : unsigned (11 DOWNTO 0);
variable CAM_Data_unsign : unsigned (11 DOWNTO 0);
variable sum_unsign_13 : unsigned (12 DOWNTO 0);
variable sum_std_12 : std_logic_vector (11 DOWNTO 0);

Begin
	if CI_nReset = '0' then
		iRegStatus <= (others => '0');
		iRegRGB <= (others => '0');
		iRegMemory <= (others => "000000000000");
		iRegBlue <= (others => '0');
		iRegColumnCounter <= (others => '0');
		CI_WriteAccess <= '0';
		iRegFIFOWrite <= '0';
	elsif rising_edge(CI_Clk) then
		if CI_WriteEnable = '1' then
			case CI_Address is
				when "00" => iRegStatus (0) <= CI_WriteData (0);
				when others => null;
			end case;
		end if;
	elsif falling_edge(CI_PixClk) then	-- read the pixel on the falling edge of the CI_PixClk
		CI_WriteAccess <= '0';	-- we don't want to put the data in the FIFO for the moment
		iRegFIFOWrite <= '0';
		if (CI_FrameValid = '1') AND (CI_LineValid = '1') then
			if iRegStatus (2) = '0' then	-- if we are on an even row
				iRegMemory(to_integer(unsigned(iRegColumnCounter))) <= CI_CAMData;	-- put the pixel in the internal memory
				iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				if (iRegColumnCounter = X"27F") then	-- if iRegColumnCounter = 639, reset it
					iRegColumnCounter <= (others => '0');
					iRegStatus (2) <= '1';	-- switch to the odd row
				end if;
			else	-- if we are on an odd row
				if (iRegStatus (3) = '0') then	-- if we are on an even column (blue pixel)
					iRegBlue <= CI_CAMData;	-- but we have to store this blue pixel
					iRegStatus (3) <= '1';	-- now switch to the odd column
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
				else	-- if we are on an odd column (green G2 pixel)
					iRegRGB (15 DOWNTO 11) <= iRegMemory(to_integer(unsigned(iRegColumnCounter))) (11 DOWNTO 7); -- put the red pixel stored in the memory in iRegRGB
					
					iRegColumnCounter_unsign := unsigned(iRegColumnCounter); -- pixel à l'adresse iRegColumnCounter
					iRegMemory_unsign := unsigned(iRegMemory(to_integer(iRegColumnCounter_unsign - 1))); -- pixel précédent l'adresse iRegColumnCounter
					CAM_Data_unsign := unsigned(CI_CAMData);
					
					sum_unsign_13 := resize(CAM_Data_unsign + iRegMemory_unsign, sum_unsign_13'length);
					
					sum_unsign_13 := sum_unsign_13 srl 1;
					sum_std_12 := std_logic_vector(resize(signed(sum_unsign_13), sum_std_12'length));
					
					iRegRGB (10 DOWNTO 5) <= sum_std_12 (11 DOWNTO 6); -- compute the averaged green with the current cam data and the green G1 pixel stored in the memory and put it in iRegRGB
					
					iRegRGB (4 DOWNTO 0) <= iRegBlue (11 DOWNTO 7);	-- put the blue pixel stored in iRegBlue in iRegRGB
					
					CI_WriteAccess <= '1';	-- we can write iRegRGB to the FIFO on the next rising edge of CI_PixClk
					iRegFIFOWrite <= '1';
					iRegStatus (3) <= '0';	-- and switch to the next even column
					iRegColumnCounter <= std_logic_vector(unsigned(iRegColumnCounter) + 1);	-- increment the column counter
					if iRegColumnCounter = X"27F" then	-- if iRegColumnCounter = 639, reset it
						iRegColumnCounter <= (others => '0');
						iRegStatus (2) <= '0';	-- switch to the even row
					end if;
				end if;
			end if;
		end if;
	end if;
end process MainProcess;

-- Process to put the datas in the FIFO
TransferData:
Process(CI_nReset, CI_PixClk)
Begin
	if CI_nReset = '0' then
		CI_FIFOData <= (others => 'Z');
	elsif rising_edge(CI_PixClk) then
		if CI_AlmostFull = '0' AND iRegFIFOWrite = '1' then
			CI_FIFOData <= iRegRGB;
		else
			CI_FIFOData <= (others => 'Z');
		end if;
	end if;
end process TransferData;

-- Process to wait one rising edge before read
ActRead:
Process(CI_Clk)
Begin
	if rising_edge(CI_Clk) then
		iRegRead <= CI_ReadEnable;
	end if;
end process ActRead;

-- Process to read the internal registers
ReadProcess:
Process(iRegStatus, iRegRGB)
Begin
	CI_ReadData <= (others => 'Z');
	if iRegRead = '1' then
		case CI_Address is
			when "00" => CI_ReadData <= iRegStatus;
			when "01" => CI_ReadData <= iRegRGB (7 DOWNTO 0);
			when "10" => CI_ReadData <= iRegRGB (15 DOWNTO 8);
			when others => null;
		end case;
	end if;
end process ReadProcess;

END bhv;