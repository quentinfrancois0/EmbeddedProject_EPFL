-- Design of a camera management device
-- Avalon slave unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon slave for the camera management device
--
-- 6 address :
-- 	0x00: clock divider register
-- 	0x02: settings register | XXXXXXXM
							-- M : mode, 1 = snapshot and 0 = continuous
-- 	0x03: Start adress memory
-- 	0x05: Length of the stored data in the memory

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_master IS
	PORT(
		nReset				: IN std_logic;							-- nReset input
		Clk					: IN std_logic;							-- clock input
		
		AS_Start			: IN std_logic;							-- Start command
		AS_Start_Adress		: IN std_logic_vector (15 DOWNTO 0); 	-- Start Adress in the memory
		AS_Length			: IN std_logic_vector (15 DOWNTO 0);	-- Length of the stored datas
		
		FIFO_almost_empty	: IN std_logic;							-- 1 when FIFO contains the burst length, 0 otherwise
		FIFO_clk			: OUT std_logic;						-- clock sent to the FIFO = FPGA clock
		FIFO_Read_Access	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		FIFO_Data			: IN std_logic_vector (15 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
		AM_Addr				: OUT std_logic_vector (15 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_Data				: OUT std_logic_vector (15 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_Write			: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_WaitRequest		: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	signal		iRegStart_Adress	: std_logic_vector (15 DOWNTO 0);	-- internal register for the memory start adress
	signal		iRegLength			: std_logic_vector (15 DOWNTO 0);	-- internal register for the data stored length
	signal		iRegStart			: std_logic;						-- internal register for the start command
	signal		iRegCounterAdress	: std_logic_vector (31 DOWNTO 0);	-- internal phantom register which points on the current adress in the memory
	TYPE		SM 	IS (WaitData, PickData, WaitBus, Transfer, EndOfBurst);
	Signal		SM_State			: SM;

BEGIN

-- Process to write internal registers with the avalon slave
-- Synchronous access on rising edge of the FPGA's clock
WriteProcess:
Process(nReset, Clk)
Begin
	if nReset = '0' then	-- reset the writable registers when pushing the reset key
		iRegStart			<= '0';
		iRegStart_Adress	<= (others => '0');
		iRegLength			<= (others => '0');
	elsif rising_edge(Clk) then
		if AS_Start = '1' then
			iRegStart <= '1';
			iRegStart_Adress <= AS_Start_Adress;
			iRegLength <= AS_Length;
		end if;
	end if;
end process WriteProcess;

-- Process to send the clock to the FIFO
FIFOClk:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		FIFO_clk <= '0';
	elsif rising_edge(Clk) then
		FIFO_clk <= Clk;
	end if;
end process FIFOClk;

--  Process to take the datas in the FIFO and send it in the memory
TransferDatas:
Process(nReset, Clk)
Variable Indice : Integer Range 0 to 3;
Begin
	if nReset = '0' then
		iRegCounterAdress <= iRegStart_Adress;
		FIFO_Read_Access  <= '0';
		AM_Addr			  <= (others => '0');
		AM_Data			  <= (others => '0');
		SM_State		  <= Waitdata;
		Indice := 0;
	elsif rising_edge(Clk) then
		case SM_State is
			when Waitdata =>
				if FIFO_almost_empty = '0' then
					FIFO_Read_Access <= '1';
					SM_State <= PickData;
				end if;
			when PickData =>
				if FIFO_Read_Access = '1' then
					FIFO_Read_Access <= '0';
					SM_State <= WaitBus;
				end if;
			when WaitBus =>
				if AM_Write = '0' then
					AM_Write <= '1';
				elsif AM_WaitRequest = '0' then --bus available
					SM_State <= Transfer;
				end if;
			when Transfer =>
				AM_Data <= FIFO_Data;
				AM_Addr <= iRegStart_Adress;
			when EndOfBurst =>
				if Indice = 3 then -- end of the burst, let the bus and go to waitdata state
					Indice := 0;
					AM_Write <= '0';
					AM_Data <= (others => '0');
					AM_Addr <= (others => '0');
					SM_State <= WaitData;
				else
					-- burst not ended -> transfer of next datas
					Indice := Indice + 1;
					FIFO_Read_Access <= '1';
					SM_State <= PickData;
				end if;
			when others => null;
		end case;
	end if;
end process TransferDatas;



END bhv;