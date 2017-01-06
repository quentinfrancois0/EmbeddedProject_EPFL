-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- ADRESSES
--  0x00: AS_ALL_Start information
--  ---- ---X : X = AS_ALL_Start information, 1 = ON, 0 = OFF
-- 	0x01: AS_ALL_Start address of the stored datas in the memory
-- 	0x05: AS_AM_Length of the stored data in the memory
-- 
-- INPUTS
-- AS_nReset <= extern
-- Clock <= extern
--
-- AS_AB_Address <= Avalon Bus
-- AS_AB_ReadEnable <= Avalon Bus
-- AS_AB_WriteEnable <= Avalon Bus
-- AS_AB_WriteData <= Avalon Bus
-- 
-- OUTPUTS
-- AS_AM_StartAddress => Master
-- AS_AM_Length => Master
-- AS_ALL_Start information => Master, Camera Controller
--
-- AS_AB_ReadData => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_slave IS
	PORT(
		AS_nReset			: IN std_logic;							-- AS_nReset input
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
END Avalon_slave;

ARCHITECTURE bhv OF Avalon_slave IS	
	constant	BURST_LENGTH		: unsigned (31 DOWNTO 0) := X"00025800";

	signal		iRegStart			: std_logic_vector (7 DOWNTO 0);	-- internal register for the start information
	signal		iRegStartAddress	: std_logic_vector (31 DOWNTO 0);	-- internal register for the memory Start adress
	signal		iRegBufferAddress	: std_logic_vector (31 DOWNTO 0);	-- internal register for the buffer address
	signal		iRegLength			: std_logic_vector (31 DOWNTO 0);	-- internal register for the data stored Length
	signal		iRegStatus			: std_logic_vector (7 DOWNTO 0);	-- internal register for the status of each buffer
	signal		prevStatus			: std_logic;						-- previous state of AS_AM_Status
	signal		nextBuffer			: std_logic_vector (1 DOWNTO 0);	-- next buffer to write
	signal		iRegRead			: std_logic;						-- 1 wait for read

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStart			<= (others => '0');
		iRegStartAddress	<= (others => '0');
		iRegBufferAddress	<= (others => '0');
		iRegLength			<= (others => '0');
		iRegStatus			<= (others => '0');
		prevStatus 			<= '0';
		nextBuffer 			<= "00";
	elsif rising_edge(AS_Clk) then
		if AS_AB_WriteEnable = '1' then
			case AS_AB_Address is
				when X"0" =>
					iRegStart	<= AS_AB_WriteData (7 DOWNTO 0);
				when X"1" =>
					iRegStatus	<= AS_AB_WriteData (7 DOWNTO 0);
				when X"2" =>
					if iRegStart(0) = '0' then
						iRegStartAddress 	<= AS_AB_WriteData;
						iRegBufferAddress	<= AS_AB_WriteData;
					end if;
				when X"3" =>
					if iRegStart(0) = '0' then
						iRegLength <= AS_AB_WriteData;
					end if;
				when others => null;
			end case;
		elsif AS_AM_Status = '1' AND prevStatus = '0' then
			prevStatus <= '1';
			if iRegStatus (0) = '0' AND nextBuffer = "00" then
				iRegStatus (0) <= '1';
				iRegBufferAddress <= std_logic_vector(unsigned(iRegStartAddress) + BURST_LENGTH);
				nextBuffer <= "01";
			elsif iRegStatus (1) = '0' AND nextBuffer = "01" then
				iRegStatus (1) <= '1';
				iRegBufferAddress <= std_logic_vector(unsigned(iRegStartAddress) + BURST_LENGTH + BURST_LENGTH);
				nextBuffer <= "10";
			elsif iRegStatus (2) = '0' AND nextBuffer = "10" then
				iRegStatus (2) <= '1';
				iRegBufferAddress <= iRegStartAddress;
				nextBuffer <= "00";
			end if;
		elsif AS_AM_Status = '0' AND prevStatus = '1' then
			prevStatus <= '0';
		end if;
	end if;
end process WriteProcess;

-- Process to read internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock with 1 wait
ReadProcess:
Process(AS_nReset, AS_Clk, AS_AB_ReadEnable, AS_AB_Address, iRegStart, iRegStartAddress, iRegLength, iRegStatus)
Begin
	if AS_nReset = '0' then
		AS_AB_ReadData <= (others => '0');
		iRegRead <= '1';
	elsif rising_edge(AS_Clk) then
		if  AS_AB_ReadEnable = '1' AND iRegRead = '1' then
			iRegRead <= '0';
			case AS_AB_Address is
				when X"0" =>
					AS_AB_ReadData (7 DOWNTO 0)		<= iRegStart;
					AS_AB_ReadData (31 DOWNTO 8)	<= X"000000";
				when X"1" =>
					AS_AB_ReadData (7 DOWNTO 0)		<= iRegStatus;
					AS_AB_ReadData (31 DOWNTO 8)	<= X"000000";
				when X"2" =>
					AS_AB_ReadData 	<= iRegStartAddress;
				when X"3" =>
					AS_AB_ReadData 	<= iRegLength;
				when others => null;
			end case;
		else
			AS_AB_ReadData <= (others => '0');
			iRegRead <= '1';
		end if;
	end if;
end process ReadProcess;

-- Process to update the output towards the master and the camera controller
UpdateOutput:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then
		AS_AM_StartAddress <= (others => '0');
		AS_AM_Length <= (others => '0');
		AS_ALL_Start <= '0';
	elsif rising_edge(AS_Clk) then
		AS_AM_StartAddress <= iRegBufferAddress;
		AS_AM_Length <= iRegLength;
		AS_ALL_Start <= (iRegStart (0)) AND (not AS_CI_Pending);
	end if;
end process UpdateOutput;

END bhv;