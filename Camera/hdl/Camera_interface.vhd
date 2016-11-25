-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Camera interface for the camera management device

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Camera_Interface IS
	PORT(
		nReset				: IN std_logic;							-- nReset input
		Clk					: IN std_logic;							-- clock input
		
		Cam_nReset			: OUT std_logic;						-- nReset sent to the camera
		Cam_XClk			: OUT std_logic;						-- clock sent to the camera
		Cam_PixClk			: IN std_logic;							-- pixel clock received from the camera
		Cam_Data				: IN std_logic_vector (11 DOWNTO 0);	-- pixel sent by the camera
		Cam_Frame_Valid		: IN std_logic;							-- 1 if the frame is valid
		Cam_Line_Valid		: IN std_logic;							-- 1 if the line is valid
		
		FIFO_Clk			: OUT std_logic;						-- clock sent to the FIFO = FPGA clock
		FIFO_Write_Access	: OUT std_logic;						-- 1 = information asked to the FIFO, 0 = no demand
		FIFO_Almost_Full	: IN std_logic;					-- 1 when the FIFO can receive only one more burst length, 0 otherwise
		FIFO_Data			: OUT std_logic_vector (15 DOWNTO 0);	-- 1 pixel stored in the FIFO by the camera controller
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	signal		iRegRed				: std_logic_vector (11 DOWNTO 0); -- internal register fot the binning of the actual pixel red color
	signal		iRegGreen			: std_logic_vector (11 DOWNTO 0); -- internal register fot the binning of the actual pixel green color
	signal		iRegBlue			: std_logic_vector (11 DOWNTO 0); -- internal register fot the binning of the actual pixel blue color
	signal		iRegRGB				: std_logic_vector (15 DOWNTO 0); -- internal register for the actual computed pixel with 5*6*5 RGB format
	
	signal		iRegRow_w			: unsigned;
	signal		iRegColumn_w		: unsigned;
	signal		iRegCountRow_w		: unsigned;
	signal		iRegCountColumn_w	: unsigned;
	
	signal		iRegRow_r			: unsigned;
	signal		iRegColumn_r		: unsigned;
	signal		iRegCountRow_r		: unsigned;
	signal		iRegCountColumn_r	: unsigned;
	
	signal		iRegColumn_f		: unsigned;
	
	signal		Data_Written		: std_logic;
	signal		Write_Burst			: unsigned;
	
	TYPE memory1 is array (479 DOWNTO 0) of std_logic_vector (11 DOWNTO 0);
	signal		iRegRow15			: memory1; -- internal memory register for the first and fifth lines read
	signal		iRegRow26			: memory1; -- internal memory register for the second and sixth lines read
	
	TYPE memory2 is array (359 DOWNTO 0) of std_logic_vector (11 DOWNTO 0);
	signal		iRegRow12			: memory2; -- internal memory register for the average pixels of the two first lines
	signal		iRegRow56			: memory2; -- internal memory register for the average pixels of the two second lines

BEGIN

-- Process to send the nReset to the camera
CameranReset:
Process(nReset)
Begin
	Cam_nReset <= nReset;
end process CameranReset;

-- Process to send the clock to the camera
CameraClk:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		Cam_XClk <= '0';
	else
		Cam_XClk <= Clk;
	end if;
end process CameraClk;

-- Process to write internal first memory registers with the camera data
-- Synchronous access on rising edge of the camera clock
WriteMemories1:
Process(nReset, Cam_PixClk)
Begin
	if nReset = '0' then	-- reset the writable registers when pushing the reset key
		iRegRow15	<= (others => '0');
		iRegRow26	<= (others => '0');
		iRegRow_w		<= '0';
		iRegColumn_w	<= '0';
		iRegCountRow_w	<= '0';
		iRegCountColumn_w	<= '0';
	elsif rising_edge(Cam_PixClk) then	-- read the pixel on the rising edge of the Cam_PixClk (better to do it on the falling edge ?)
		if (Cam_Frame_Valid = '1') AND (Cam_Line_Valid = '1') then
			if iRegCountRow_w = "00" then	-- if we are on the first or fifth row
				if iRegCountColumn_w = "00" then	-- if we are on the first or fifth column
					iRegRow15(iRegColumn_w) <= Cam_Data;
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif iRegCountColumn_w = "01" then	-- if we are on the second or sixth column
					iRegRow15(iRegColumn_w) <= Cam_Data;
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif iRegCountColumn_w = "10" then	-- if we are on the third or seventh column
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif iRegCountColumn_w = "11" then	-- if we are on the fourth or eighth column
					iRegCountColumn_w <= '0'
					iRegColumn_w <= iRegColumn_w + '1';
					if iRegColumn_w = X"1DF" then
						iRegColumn_w <= '0';
					end if;
				end if;
				iRegCountRow_w <= iRegCountRow_w + '1';
				iRegRow_w <= iRegRow_w + '1';
			elsif iRegCountRow_w = "01" then	-- if we are on the second or sixth row
				if iRegCountColumn_w = "00" then	-- if we are on the first or fifth column
					iRegRow26(iRegColumn_w) <= Cam_Data;
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif iRegCountColumn_w = "01" then	-- if we are on the second or sixth column
					iRegRow26(iRegColumn_w) <= Cam_Data;
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif iRegCountColumn_w = "10" then -- if we are on the third or seventh column
					iRegCountColumn_w <= iRegCountColumn_w + '1';
					iRegColumn_w <= iRegColumn_w + '1';
				elsif (iRegStatus AND "00000011" = "11") then -- if we are on the fourth or eighth column
					iRegCountColumn_w <= '0';
					iRegColumn_w <= iRegColumn_w + '1';
					if iRegColumn_w = X"1DF" then
						iRegColumn_w <= '0';
					end if;
				end if;
				iRegCountRow_w <= iRegCountRow_w + '1';
				iRegRow_w <= iRegRow_w + '1';
			elsif iRegCountRow_w = "10" then	-- if we are on the third or seventh row
				iRegCountRow_w <= iRegCountRow_w + '1';
				iRegRow_w <= iRegRow_w + '1';
			elsif iRegCountRow_w = "11" then	-- if we are on the fourth or eighth row
				iRegCountRow_w <= '0';
				iRegRow_w <= iRegRow_w + '1';
				if iRegRow_w = X"27f" then
					iRegRow_w <= '0';
				end if;
			end if;
		end if;
	end if;
end process WriteMemories1;

-- Process to write internal second memory registers with the average value of the first memories
-- Synchronous access on rising edge of the FPGA clock
Memories1to2:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		iRegRow12	<= (others => '0');
		iRegRow56	<= (others => '0');
		iRegRow_r		<= '0';
		iRegColumn_r	<= '0';
		iRegCountRow_r	<= '0';
		iRegCountColumn_r	<= '0';
	elsif rising_edge(Clk) then
		if (iRegCountRow_r = "00") OR (iRegCountRow_r = "10") then
			if (iRegCountColumn_r = "00") OR (iRegCountColumn_r = "10") then
				iRegRow12(iRegColumn_r + '1') <= iRegRow12(iRegColumn_r + '1') OR iRegRow15(iRegColumn_r);
				iRegRow12(iRegColumn_r + '2') <= iRegRow12(iRegColumn_r + '2') OR iRegRow26(iRegColumn_r);
				iRegCountColumn_r 	<= iRegCountColumn_r + '1';
				iRegColumn_r		<= iRegColumn_r + '3';
			elsif (iRegCountColumn_r = "01") OR (iRegCountColumn_r = "11") then
				iRegRow12(iRegColumn_r - '1')	<= iRegRow12(iRegColumn_r - '1') OR iRegRow15(iRegColumn_r);
				iRegRow12(iRegColumn_r)			<= iRegRow12(iRegColumn_r) OR iRegRow26(iRegColumn_r);
				if (iRegCountColumn_r = "01") then
					iRegCountColumn_r <= iRegCountColumn_r + '1';
				else
					iRegCountColumn_r <= '0';
				end if;
				iRegColumn_r <= iRegColumn_r + '3';
				if iRegColumn_r = X"EF" then
					iRegColumn_r <= '0';
				end if;
			end if;
			iRegCountRow_r <= iRegCountRow_r + '1';
			iRegRow_r <= iRegRow_r + '1';
		elsif (iRegCountRow_r = "01") OR (iRegCountRow_r = "11") then
			if (iRegCountRow_r = "00") OR (iRegCountRow_r = "10") then
				iRegRow56(iRegColumn_r + '1') <= iRegRow56(iRegColumn_r + '1') OR iRegRow15(iRegColumn_r);
				iRegRow56(iRegColumn_r + '2') <= iRegRow56(iRegColumn_r + '2') OR iRegRow26(iRegColumn_r);
				iRegCountColumn_r 	<= iRegCountColumn_r + '1';
				iRegColumn_r		<= iRegColumn_r + '3';
			elsif (iRegCountColumn_r = "01") OR (iRegCountColumn_r = "11") then
				iRegRow56(iRegColumn_r - '1')	<= iRegRow56(iRegColumn_r - '1') OR iRegRow15(iRegColumn_r);
				iRegRow56(iRegColumn_r)			<= iRegRow56(iRegColumn_r) OR iRegRow26(iRegColumn_r);
				if (iRegCountColumn_r = "01") then
					iRegCountColumn_r <= iRegCountColumn_r + '1';
				else
					iRegCountColumn_r <= '0';
				end if;
				iRegColumn_r <= iRegColumn_r + '3';
				if iRegColumn_r = X"EF" then
					iRegColumn_r <= '0';
				end if;
				if (iRegCountRow_r = "01") then
					iRegCountRow_r <= iRegCountRow_r + '1';
				else
					iRegCountRow_r <= '0';
				end if;
			end if;
			iRegRow_r <= iRegRow_r + '1';
			if iRegRow_r = X"13F" then
				iRegRow_r <= '0';
			end if;
		end if;
	end if;
end process Memories1to2;

-- Process to compute the 5*6*5 RGB format
-- Synchronous access on rising edge of the FPGA clock
ReadMemories2:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		iRegRed		<= (others => '0');
		iRegGreen	<= (others => '0');
		iRegBlue	<= (others => '0');
		iRegRGB		<= (others => '0');
		iRegColumn_f <= '0';
	elsif rising_edge(Clk) then
		if Data_Written = '1' then
			iRegRed <= iRegRow12(iRegColumn_f) OR iRegRow56(iRegColumn_f);
			iRegGreen <= iRegRow12(iRegColumn_f + '1') OR iRegRow56(iRegColumn_f + '1');
			iRegBlue <= iRegRow12(iRegColumn_f + '1') OR iRegRow56(iRegColumn_f + '1');
			iRegRGB (15 DOWNTO 11) <= iRegRed (11 DOWNTO 7);
			iRegRGB (10 DOWNTO 5) <= iRegGreen (11 DOWNTO 6);
			iRegRGB (4 DOWNTO 0) <= iRegBlue (11 DOWNTO 7);
			iRegColumn_f <= iRegColumn_f + '1';
			if iRegColumn_f = X"EF" then
				iRegColumn_f <= '0';
			end if;
		end if;
	end if;
end process ReadMemories2;

-- Process to send the clock to the FIFO
FIFOClk:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		FIFO_Clk <= '0';
	else
		FIFO_Clk <= Clk;
	end if;
end process FIFOClk;

-- Process to put the datas in the FIFO
TransferData:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		Data_Written <= '0';
		FIFO_Write_Access <= '0';
		FIFO_Data <= (others => 0);
		Write_Burst <= '###BURST###';
	elsif rising_edge(Clk) then
		if FIFO_Almost_Full = '1' then
			
		elsif Data_Written = '1' then
			Data_Written <= '0';
			FIFO_Write_Access <= '0';
		else
			FIFO_Write_Access <= '1';
			FIFO_Data <= iRegRGB;
			Data_Written <= '1';
		end if;
	end if;
end process TransferData;

END bhv;