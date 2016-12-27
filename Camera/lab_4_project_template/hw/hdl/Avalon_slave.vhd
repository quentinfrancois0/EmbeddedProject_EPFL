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
	signal		iFlagSettings		: std_logic_vector (7 DOWNTO 0);	-- internal phantom flag in order to avoid seetings modification after configuration
	signal		iRegStart			: std_logic;						-- internal register for the Start information
	signal		iRegStart_Address	: std_logic_vector (31 DOWNTO 0);	-- internal register for the memory Start adress
	signal		iRegLength			: std_logic_vector (31 DOWNTO 0);	-- internal register for the data stored Length
	signal		iRegStatus			: std_logic_vector (2 DOWNTO 0);	-- internal register for the status of each buffer
	signal		iRegNBuffer			: std_logic_vector (2 DOWNTO 0);	-- internal register to know the current buffer

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(AS_nReset, AS_Clk, AS_AM_Status)
Begin
	if AS_nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStart			<= '0';
		iRegStart_Address	<= (others => '0');
		iRegLength			<= (others => '0');
		iFlagSettings		<= (others => '0');
		iRegStatus			<= (others => '0');
	elsif rising_edge(AS_Clk) then
		if AS_AB_WriteEnable = '1' then
			case AS_AB_Address is
				when X"0" => iRegStart	<= AS_AB_WriteData(0);
				when X"1" => 
					if iFlagSettings(0) = '0' then
						iRegStart_Address (7 DOWNTO 0)	<= AS_AB_WriteData;
						iFlagSettings(0) <= '1';
					end if;
				when X"2" => 
					if iFlagSettings(1) = '0' then
						iRegStart_Address (15 DOWNTO 8)	<= AS_AB_WriteData;
						iFlagSettings(1) <= '1';
					end if;
				when X"3" => 
					if iFlagSettings(2) = '0' then
						iRegStart_Address (23 DOWNTO 16)	<= AS_AB_WriteData;
						iFlagSettings(2) <= '1';
					end if;
				when X"4" => 
					if iFlagSettings(3) = '0' then
						iRegStart_Address (31 DOWNTO 24)	<= AS_AB_WriteData;
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
				when X"9" => iRegStatus <= AS_AB_WriteData (2 DOWNTO 0);
				when others => null;
			end case;
		end if;
		if iRegNBuffer = "000" then
			iRegStatus <= "000";
		elsif iRegNBuffer = "001" then
			iRegStatus <= "001";
		elsif iRegNBuffer = "010" then
			iRegStatus <= "010";
		elsif iRegNBuffer = "011" then
			iRegStatus <= "100";
		end if;
	end if;
end process WriteProcess;

-- Process to read internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock with 1 wait
ReadProcess:
Process(AS_AB_ReadEnable, AS_AB_Address, iRegStart, iRegStart_Address, iRegLength, iRegStatus)
Begin
	AS_AB_ReadData <= (others => '0');	-- reset the data bus (read) when not used
	if AS_AB_ReadEnable = '1' then
		case AS_AB_Address is
			when X"0" => AS_AB_ReadData(0) 				<= iRegStart;
			when X"1" => AS_AB_ReadData 					<= iRegStart_Address (7 DOWNTO 0);
			when X"2" => AS_AB_ReadData 					<= iRegStart_Address (15 DOWNTO 8);
			when X"3" => AS_AB_ReadData 					<= iRegStart_Address (23 DOWNTO 16);
			when X"4" => AS_AB_ReadData 					<= iRegStart_Address (31 DOWNTO 24);
			when X"5" => AS_AB_ReadData 					<= iRegLength (7 DOWNTO 0);
			when X"6" => AS_AB_ReadData 					<= iRegLength (15 DOWNTO 8);
			when X"7" => AS_AB_ReadData 					<= iRegLength (23 DOWNTO 16);
			when X"8" => AS_AB_ReadData 					<= iRegLength (31 DOWNTO 24);
			when X"9" => AS_AB_ReadData (2 DOWNTO 0)		<= iRegStatus;
			when others => null;
		end case;
	end if;
end process ReadProcess;

NBuffer:
Process(AS_nReset, AS_AM_Status)
Begin
	if AS_nReset = '0' then
		iRegNBuffer <= (others => '0');
	elsif rising_edge(AS_AM_Status) then
		iRegNBuffer <= std_logic_vector(unsigned(iRegNBuffer) + 1);
		if iRegNBuffer = "011" then
			iRegNBuffer <= "001";
		end if;
	end if;
end process NBuffer;

-- Process to update the output towards the master and the camera controller
UpdateOutput:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then
		AS_AM_StartAddress <= (others => '0');
		AS_AM_Length <= (others => '0');
		AS_AMCI_Start	<= '0';
	elsif rising_edge(AS_Clk) then
		AS_AM_StartAddress <= iRegStart_Address;
		AS_AM_Length <= iRegLength;
		AS_AMCI_Start <= iRegStart;
	end if;
end process UpdateOutput;

END bhv;