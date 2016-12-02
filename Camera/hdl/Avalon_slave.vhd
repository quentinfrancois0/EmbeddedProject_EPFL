-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- ADRESSES
--  0x00: Start information
--  ---- ---X : X = Start information, 1 = ON, 0 = OFF
-- 	0x01: Start address of the stored datas in the memory
-- 	0x03: Length of the stored data in the memory
-- 
-- INPUTS
-- nReset <= extern
-- Clock <= extern
--
-- Addr <= Avalon Bus
-- R <= Avalon Bus
-- W <= Avalon Bus
-- WData <= Avalon Bus
-- 
-- OUTPUTS
-- Start_Address => Master
-- Length => Master
-- Start information => Master, Camera Controller
--
-- RData => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_slave IS
	PORT(
		nReset			: IN std_logic;							-- nReset input
		Clk				: IN std_logic;							-- clock input
		
		Addr				: IN std_logic_vector (2 DOWNTO 0);		-- address bus
		R					: IN std_logic;							-- read enabler
		W					: IN std_logic;							-- write enabler
		RData				: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		WData				: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		
		Start_Address	: OUT std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
		Length			: OUT std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		Start				: OUT std_logic					-- Start information
	);
END Avalon_slave;

ARCHITECTURE bhv OF Avalon_slave IS	
	signal		iRegRead				: std_logic;								-- internal phantom read register
	signal		iFlagSettings		: std_logic_vector (3 DOWNTO 0);		-- internal phantom flag in order to avoid seetings modification after configuration
	signal		iRegStart			: std_logic;								-- internal register for the start information
	signal		iRegStart_Address	: std_logic_vector (15 DOWNTO 0);	-- internal register for the memory start adress
	signal		iRegLength			: std_logic_vector (15 DOWNTO 0);	-- internal register for the data stored length

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(nReset, Clk)
Begin
	if nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStart			<= '0';
		iRegStart_Address	<= (others => '0');
		iRegLength			<= (others => '0');
		iFlagSettings		<= (others => '0');
	elsif rising_edge(Clk) then
		if W = '1' then
			case Addr is
				when "000" => iRegStart	<= WData(0);
				when "001" => 
					if iFlagSettings(0) = '0' then
						iRegStart_Address (7 DOWNTO 0)	<= WData;
						iFlagSettings(0) <= '1';
					end if;
				when "010" => 
					if iFlagSettings(1) = '0' then
						iRegStart_Address (15 DOWNTO 8)	<= WData;
						iFlagSettings(1) <= '1';
					end if;
				when "011" => 
					if iFlagSettings(2) = '0' then
						iRegLength (7 DOWNTO 0)			<= WData;
						iFlagSettings(2) <= '1';
					end if;
				when "100" => 
					if iFlagSettings(3) = '0' then
						iRegLength (15 DOWNTO 8)		<= WData;
						iFlagSettings(3) <= '1';
					end if;
				when others => null;
			end case;
		end if;
	end if;
end process WriteProcess;

-- Process to wait one rising edge before reading the internal registers
WaitRead:
Process(nReset, Clk)
Begin
	if nReset = '0' then	-- reset the internal phantom read register when pushing the reset key
		iRegRead <= '0';
	elsif rising_edge(Clk) then
		iRegRead <= R;
	end if;
end process WaitRead;

-- Process to read internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock with 1 wait
ReadProcess:
Process(iRegRead, Addr, iRegStart_Address, iRegLength)
Begin
	RData <= (others => '0');	-- reset the data bus (read) when not used
	if iRegRead = '1' then
		case Addr is
			when "000" => RData(0) 	<= iRegStart;
			when "001" => RData 		<= iRegStart_Address (7 DOWNTO 0);
			when "010" => RData 		<= iRegStart_Address (15 DOWNTO 8);
			when "011" => RData 		<= iRegLength (7 DOWNTO 0);
			when "100" => RData 		<= iRegLength (15 DOWNTO 8);
			when others => null;
		end case;
	end if;
end process ReadProcess;

-- Process to update the output towards the master and the camera controller
UpdateOutput:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		Start_Address <= (others => '0');
		Length <= (others => '0');
		Start	<= '0';
	elsif rising_edge(Clk) then
		Start_Address <= iRegStart_Address;
		Length <= iRegLength;
		Start <= iRegStart;
	end if;
end process UpdateOutput;

END bhv;