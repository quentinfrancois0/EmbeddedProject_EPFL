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
		AM_New_Data			: OUT std_logic;						-- Put at 1 when the master wants to send datas on the bus
		AM_Data_Ack			: IN std_logic							-- Receive 1 when the data transfer succeeds
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	signal		iRegStart_Adress	: std_logic_vector (15 DOWNTO 0);	-- internal register for the memory start adress
	signal		iRegLength			: std_logic_vector (15 DOWNTO 0);	-- internal register for the data stored length
	signal		iRegStart			: std_logic;						-- internal register for the start command
	signal		iRegData			: std_logic_vector (15 DOWNTO 0);	-- internal register for the data received from the FIFO
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
		iRegData 		  <= (others => '0');
		FIFO_Read_Access  <= '0';
		AM_Addr			  <= (others => '0');
		AM_New_Data		  <= '0';
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
					iRegData <= FIFO_Data;
					FIFO_Read_Access <= '0';
					SM_State <= WaitBus;
				end if;
			when WaitBus =>
				if AM_New_Data = '0' then
					AM_New_Data <= '1';
				else
					-- questionner le bus pour voir si il est prêt
				end if;
			when Transfer =>
				-- tester si le transfert est terminé, 
				
				--si non, mettre les infos sur les pins
				
				--si oui
				--AM_New_Data <= '0';
			when EndOfBurst =>
				Indice := Indice + 1;
				if Indice = 3 then -- end of the burst, let the bus and go to waitdata state
					-- let the bus (A AJOUTER)
					SM_State <= WaitData;
				else
					-- burst not ended -> transfer of next datas
					FIFO_Read_Access <= '1';
					SM_State <= PickData;
				end if;
			when others => null;
		end case;
	end if;
end process TransferDatas;



END bhv;