-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- ADRESSES
-- 	0x00: Start adress memory
-- 	0x02: Length of the stored data in the memory
-- 
-- INPUTS
-- Clk <= FPGA Clock 50 MHz
-- 
-- OUTPUTS
-- Clkout => Camera Clock 25 MHz
-- Start_Adress => Master, start_adress
-- Length => Master, length

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_slave IS
	PORT(
		nReset			: IN std_logic;							-- nReset input
		Clk				: IN std_logic;							-- clock input
		Addr			: IN std_logic_vector (1 DOWNTO 0);		-- address bus
		R				: IN std_logic;							-- read enabler
		W				: IN std_logic;							-- write enabler
		RData			: OUT std_logic_vector (7 DOWNTO 0);	-- data bus (read)
		WData			: IN std_logic_vector (7 DOWNTO 0);		-- data bus (write)
		Clkout			: OUT std_logic;						-- Clock output
		Start_Adress	: OUT std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
		Length			: OUT std_logic_vector (15 DOWNTO 0)	-- Length of the stored datas
	);
END Avalon_slave;

ARCHITECTURE bhv OF Avalon_slave IS
	signal		iRegCountEnable		: std_logic_vector;					-- internal phantom counter enabler register
	signal		iRegOut				: std_logic;						-- internal phantom out register
	signal		iRegRead			: std_logic;						-- internal phantom read register
	signal		iRegStart_Adress	: std_logic_vector (15 DOWNTO 0);	-- internal register for the memory start adress
	signal		iRegLength			: std_logic_vector (15 DOWNTO 0);	-- internal register for the data stored length

BEGIN

-- Process to write internal registers through Avalon bus interface
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(nReset, Clk)
Begin
	if nReset = '0' then	-- reset the four writable registers when pushing the reset key
		iRegStart_Adress	<= (others => '0');
		iRegLength			<= (others => '0');
	elsif rising_edge(Clk) then
		if W = '1' then
			case Addr is
				when "00" => iRegStart_Adress (7 DOWNTO 0)		<= WData;
				when "01" => iRegStart_Adress (15 DOWNTO 8)		<= WData;
				when "10" => iRegLength (7 DOWNTO 0)			<= WData;
				when "11" => iRegLength (15 DOWNTO 8)			<= WData;
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
Process(iRegRead, Addr, iRegStart_Adress, iRegLength)
Begin
	RData <= (others => '0');	-- reset the data bus (read) when not used
	if iRegRead = '1' then
		case Addr is
			when "00" => RData <= iRegStart_Adress (7 DOWNTO 0);
			when "01" => RData <= iRegStart_Adress (15 DOWNTO 8);
			when "10" => RData <= iRegLength (7 DOWNTO 0);
			when "11" => RData <= iRegLength (15 DOWNTO 8);
			when others => null;
		end case;
	end if;
end process ReadProcess;

-- Process to divide the clock and to increment the internal counter register
ClkDivider:
Process(nReset, Clk)
Begin
	if nReset = '0' then	-- reset the internal phantom counter enabler register when pushing the reset key
		iRegCountEnable	<= (others => '0');
	elsif rising_edge(clk) then -- toggle the iRegCountEnable in order to divide the in clock by 2, FPGA clock = 50 MHz, Camera clock = 25 MHz
		if iRegCountEnable ='0' then
			iRegCountEnable <= '1';
		else
			iRegCountEnable <= '0';
		end if;
	end if;
end process ClkDivider;

ClkOutUpdate:
Process(iRegCountEnable, nReset)
Begin
	if nReset = '0' then -- reset the output when pushing the reset key
		Clkout <= '0';
	elsif iRegCountEnable = '1' then
		Clkout <= '1';
	else
		CLkout <= '0';
	end if;
end process ClkOutUpdate;

END bhv;