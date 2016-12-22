-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- ADRESSES
--  0x00: AS_Start information
--  ---- ---X : X = AS_Start information, 1 = ON, 0 = OFF
-- 	0x01: AS_Start address of the stored datas in the memory
-- 	0x05: AS_Length of the stored data in the memory
-- 
-- INPUTS
-- AS_nReset <= extern
-- Clock <= extern
--
-- AS_Address <= Avalon Bus
-- AS_ReadEnable <= Avalon Bus
-- AS_WriteEnable <= Avalon Bus
-- AS_WriteData <= Avalon Bus
-- 
-- OUTPUTS
-- AS_StartAddress => Master
-- AS_Length => Master
-- AS_Start information => Master, Camera Controller
--
-- AS_ReadData => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_slave IS
	PORT(
		AS_nReset			: IN std_logic;							-- AS_nReset input
		AS_Clk				: IN std_logic;							-- clock input
		
		AS_Address			: IN std_logic_vector (3 DOWNTO 0);		-- address bus
		AS_ReadEnable		: IN std_logic;							-- read enabler
		AS_WriteEnable		: IN std_logic;							-- write enabler
		AS_ReadData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		AS_WriteData		: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		AS_StartAddress		: OUT std_logic_vector (31 DOWNTO 0); 	-- AS_Start Adress in the memory
		AS_Length			: OUT std_logic_vector (31 DOWNTO 0);	-- AS_Length of the stored datas
		AS_Start			: OUT std_logic;						-- AS_Start information
		AS_Status			: IN std_logic;							-- 1 when the image has been written to the memory
	);
END Avalon_slave;

ARCHITECTURE bhv OF Avalon_slave IS	
	signal		iFlagSettings		: std_logic_vector (7 DOWNTO 0);	-- internal phantom flag in order to avoid seetings modification after configuration
	signal		iRegStart			: std_logic;						-- internal register for the AS_Start information
	signal		iRegStart_Address	: std_logic_vector (31 DOWNTO 0);	-- internal register for the memory AS_Start adress
	signal		iRegLength			: std_logic_vector (31 DOWNTO 0);	-- internal register for the data stored AS_Length
	signal		iRegStatus			: std_logic_vector (2 DOWNTO 0);	-- internal register for the status of each buffer
	signal		iRegNBuffer			: std_logic_vector (1 DOWNTO 0);	-- internal register to know the current buffer

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStart			<= '0';
		iRegStart_Address	<= (others => '0');
		iRegLength			<= (others => '0');
		iFlagSettings		<= (others => '0');
		iRegStatus			<= (others => '0');
	elsif rising_edge(AS_Clk) then
		if AS_WriteEnable = '1' then
			case AS_Address is
				when X"0" => iRegStart	<= AS_WriteData(0);
				when X"1" => 
					if iFlagSettings(0) = '0' then
						iRegStart_Address (7 DOWNTO 0)	<= AS_WriteData;
						iFlagSettings(0) <= '1';
					end if;
				when X"2" => 
					if iFlagSettings(1) = '0' then
						iRegStart_Address (15 DOWNTO 8)	<= AS_WriteData;
						iFlagSettings(1) <= '1';
					end if;
				when X"3" => 
					if iFlagSettings(2) = '0' then
						iRegStart_Address (23 DOWNTO 16)	<= AS_WriteData;
						iFlagSettings(2) <= '1';
					end if;
				when X"4" => 
					if iFlagSettings(3) = '0' then
						iRegStart_Address (31 DOWNTO 24)	<= AS_WriteData;
						iFlagSettings(3) <= '1';
					end if;
				when X"5" => 
					if iFlagSettings(4) = '0' then
						iRegLength (7 DOWNTO 0)			<= AS_WriteData;
						iFlagSettings(4) <= '1';
					end if;
				when X"6" => 
					if iFlagSettings(5) = '0' then
						iRegLength (15 DOWNTO 8)		<= AS_WriteData;
						iFlagSettings(5) <= '1';
					end if;
				when X"7" => 
					if iFlagSettings(6) = '0' then
						iRegLength (23 DOWNTO 16)		<= AS_WriteData;
						iFlagSettings(6) <= '1';
					end if;
				when X"8" => 
					if iFlagSettings(7) = '0' then
						iRegLength (31 DOWNTO 24)		<= AS_WriteData;
						iFlagSettings(7) <= '1';
					end if;
				when X"9" => iRegStatus <= AS_WriteData (2 DOWNTO 0);
				when others => null;
			end case;
		end if;
	end if;
end process WriteProcess;

-- Process to read internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock with 1 wait
ReadProcess:
Process(AS_ReadEnable, AS_Address, iRegStart_Address, iRegLength)
Begin
	AS_ReadData <= (others => '0');	-- reset the data bus (read) when not used
	if AS_ReadEnable = '1' then
		case AS_Address is
			when X"0" => AS_ReadData(0) 				<= iRegStart;
			when X"1" => AS_ReadData 					<= iRegStart_Address (7 DOWNTO 0);
			when X"2" => AS_ReadData 					<= iRegStart_Address (15 DOWNTO 8);
			when X"3" => AS_ReadData 					<= iRegStart_Address (23 DOWNTO 16);
			when X"4" => AS_ReadData 					<= iRegStart_Address (31 DOWNTO 24);
			when X"5" => AS_ReadData 					<= iRegLength (7 DOWNTO 0);
			when X"6" => AS_ReadData 					<= iRegLength (15 DOWNTO 8);
			when X"7" => AS_ReadData 					<= iRegLength (23 DOWNTO 16);
			when X"8" => AS_ReadData 					<= iRegLength (31 DOWNTO 24);
			when X"9" => AS_ReadData (2 DOWNTO 0)		<= iRegStatus;
			when others => null;
		end case;
	end if;
end process ReadProcess;

-- Process to know the current buffer
NBuffer:
Process(AS_nReset, AS_Status)
Begin
	if AS_nReset = '0' then
		iRegNBuffer <= (others => '0');
	elsif rising_edge(AS_Status) then
		iRegNBuffer <= std_logic_vector(unsigned(iRegNBuffer) + '1');
		if iRegNBuffer = "00" then
			iRegStatus <= "000";
		elsif iRegNBuffer = "01" then
			iRegStatus <= "001";
		elsif iRegNBuffer = "10" then
			iRegStatus <= "010";
		elsif iRegNBuffer = "11" then
			iRegStatus <= "100";
			iRegNBuffer <= "00";
		end if;
	end if;
end process NBuffer;

-- Process to update the output towards the master and the camera controller
UpdateOutput:
Process(AS_nReset, AS_Clk)
Begin
	if AS_nReset = '0' then
		AS_StartAddress <= (others => '0');
		AS_Length <= (others => '0');
		AS_Start	<= '0';
	elsif rising_edge(AS_Clk) then
		AS_StartAddress <= iRegStart_Address;
		AS_Length <= iRegLength;
		AS_Start <= iRegStart;
	end if;
end process UpdateOutput;

END bhv;