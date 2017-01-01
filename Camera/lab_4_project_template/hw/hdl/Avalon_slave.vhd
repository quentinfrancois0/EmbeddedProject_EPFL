-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- ADRESSES
--  0x00: AS_AMCI_Start information
--  ---- ---X : X = AS_AMCI_Start information, 1 = ON, 0 = OFF
-- 	0x01: AS_AMCI_Start address of the stored datas in the memory
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
-- AS_AMCI_Start information => Master, Camera Controller
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
		AS_AB_ReadData		: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		AS_AB_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		AS_AMCI_Start		: OUT std_logic;						-- Start information
		AS_AM_StartAddress	: OUT std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AS_AM_Length		: OUT std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		AS_AM_Status		: IN std_logic							-- 1 when the image has been written to the memory
	);
END Avalon_slave;

ARCHITECTURE bhv OF Avalon_slave IS	
	constant	BURST_LENGTH		: unsigned (31 DOWNTO 0) := X"00025800";

	signal		iFlagSettings		: std_logic_vector (7 DOWNTO 0);	-- internal phantom flag in order to avoid seetings modification after configuration
	signal		iRegStartAddress	: std_logic_vector (31 DOWNTO 0);	-- internal register for the memory Start adress
	signal		iRegBufferAddress	: std_logic_vector (31 DOWNTO 0);	-- internal register for the buffer address
	signal		iRegLength			: std_logic_vector (31 DOWNTO 0);	-- internal register for the data stored Length
	signal		iRegStatus			: std_logic_vector (7 DOWNTO 0);	-- internal register for the status of each buffer
	signal		prevStatus			: std_logic;						-- previous state of AS_AM_Status
	signal		nextBuffer			: std_logic_vector (1 DOWNTO 0);	-- next buffer to write

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStartAddress	<= (others => '0');
		iRegBufferAddress	<= (others => '0');
		iRegLength			<= (others => '0');
		iFlagSettings		<= (others => '0');
		iRegStatus			<= (others => '0');
		prevStatus 			<= '0';
		nextBuffer 			<= "00";
	elsif rising_edge(AS_Clk) then
		if AS_AB_WriteEnable = '1' then
			case AS_AB_Address is
				when X"0" => iRegStatus	<= AS_AB_WriteData;
				when X"1" => 
					if iFlagSettings(0) = '0' then
						iRegStartAddress (7 DOWNTO 0)	<= AS_AB_WriteData;
						iRegBufferAddress (7 DOWNTO 0)	<= AS_AB_WriteData;
						iFlagSettings(0) <= '1';
					end if;
				when X"2" => 
					if iFlagSettings(1) = '0' then
						iRegStartAddress (15 DOWNTO 8)	<= AS_AB_WriteData;
						iRegBufferAddress (15 DOWNTO 8)	<= AS_AB_WriteData;
						iFlagSettings(1) <= '1';
					end if;
				when X"3" => 
					if iFlagSettings(2) = '0' then
						iRegStartAddress (23 DOWNTO 16)	<= AS_AB_WriteData;
						iRegBufferAddress (23 DOWNTO 16)<= AS_AB_WriteData;
						iFlagSettings(2) <= '1';
					end if;
				when X"4" => 
					if iFlagSettings(3) = '0' then
						iRegStartAddress (31 DOWNTO 24)	<= AS_AB_WriteData;
						iRegBufferAddress (31 DOWNTO 24)<= AS_AB_WriteData;
						iFlagSettings(3) <= '1';
					end if;
				when X"5" => 
					if iFlagSettings(4) = '0' then
						iRegLength (7 DOWNTO 0)			<= AS_AB_WriteData;
						iFlagSettings(4) <= '1';
					end if;
				when X"6" => 
					if iFlagSettings(5) = '0' then
						iRegLength (15 DOWNTO 8)		<= AS_AB_WriteData;
						iFlagSettings(5) <= '1';
					end if;
				when X"7" => 
					if iFlagSettings(6) = '0' then
						iRegLength (23 DOWNTO 16)		<= AS_AB_WriteData;
						iFlagSettings(6) <= '1';
					end if;
				when X"8" => 
					if iFlagSettings(7) = '0' then
						iRegLength (31 DOWNTO 24)		<= AS_AB_WriteData;
						iFlagSettings(7) <= '1';
					end if;
				when others => null;
			end case;
		end if;
		if AS_AM_Status = '1' AND prevStatus = '0' then
			prevStatus <= '1';
			if iRegStatus (1) = '0' AND nextBuffer = "00" then
				iRegStatus (1) <= '1';
				iRegBufferAddress <= std_logic_vector(unsigned(iRegStartAddress) + BURST_LENGTH);
				nextBuffer <= "01";
			elsif iRegStatus (2) = '0' AND nextBuffer = "01" then
				iRegStatus (2) <= '1';
				iRegBufferAddress <= std_logic_vector(unsigned(iRegStartAddress) + BURST_LENGTH + BURST_LENGTH);
				nextBuffer <= "10";
			elsif iRegStatus (3) = '0' AND nextBuffer = "10" then
				iRegStatus (3) <= '1';
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
Process(AS_AB_ReadEnable, AS_AB_Address, iRegStartAddress, iRegLength, iRegStatus)
Begin
	AS_AB_ReadData <= (others => 'Z');	-- reset the data bus (read) when not used
	if AS_AB_ReadEnable = '1' then
		case AS_AB_Address is
			when X"0" => AS_AB_ReadData 	<= iRegStatus;
			when X"1" => AS_AB_ReadData 	<= iRegStartAddress (7 DOWNTO 0);
			when X"2" => AS_AB_ReadData 	<= iRegStartAddress (15 DOWNTO 8);
			when X"3" => AS_AB_ReadData 	<= iRegStartAddress (23 DOWNTO 16);
			when X"4" => AS_AB_ReadData 	<= iRegStartAddress (31 DOWNTO 24);
			when X"5" => AS_AB_ReadData 	<= iRegLength (7 DOWNTO 0);
			when X"6" => AS_AB_ReadData 	<= iRegLength (15 DOWNTO 8);
			when X"7" => AS_AB_ReadData 	<= iRegLength (23 DOWNTO 16);
			when X"8" => AS_AB_ReadData 	<= iRegLength (31 DOWNTO 24);
			when others => null;
		end case;
	end if;
end process ReadProcess;

-- Process to update the output towards the master and the camera controller
UpdateOutput:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then
		AS_AM_StartAddress <= (others => '0');
		AS_AM_Length <= (others => '0');
		AS_AMCI_Start	<= '0';
	elsif rising_edge(AS_Clk) then
		AS_AM_StartAddress <= iRegBufferAddress;
		AS_AM_Length <= iRegLength;
		AS_AMCI_Start <= iRegStatus(0);
	end if;
end process UpdateOutput;

END bhv;