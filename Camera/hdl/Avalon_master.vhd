-- Design of a camera management device
-- Avalon master unit
-- 
-- Authors : Nicolas Berling & Quentin François
-- Date : ??.11.2016
--
-- Avalon master for the camera management device
--
-- ADRESSES
-- nothing
-- 
-- INPUTS
-- nReset <= extern
-- Clock <= extern
--
-- AS_Start <= Slave
-- AS_Start_Address <= Slave
-- AS_Length <= Slave
-- 
-- FIFO_number_words <= FIFO
-- FIFO_data <= FIFO
-- 
-- AM_WaitRequest <= Avalon Bus
-- 
-- OUTPUTS
-- FIFO_Read_Access => FIFO
--
-- AM_Addr => Avalon Bus
-- AM_Data => Avalon Bus
-- AM_Write => Avalon Bus
-- AM_BurstCount => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_master IS
	PORT(
		nReset				: IN std_logic;								-- nReset input
		Clk					: IN std_logic;								-- clock input
		
		AS_Start			: IN std_logic;								-- Start command
		AS_Start_Address	: IN std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AS_Length			: IN std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		
		FIFO_number_words	: IN std_logic_vector (7 DOWNTO 0);		-- number of 32 bits words
		FIFO_Read_Access	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		FIFO_Data			: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
		AM_Addr				: OUT std_logic_vector (31 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_Data				: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_Write			: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_WaitRequest		: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	signal		iRegAlmostEmpty				: std_logic;						-- internal phantom register which says if there is at least a burst in the FIFO
	signal		iRegCounterAddress			: std_logic_vector (31 DOWNTO 0);	-- internal phantom register which points on the current adress in the memory
	signal		iRegData					: std_logic_vector (31 DOWNTO 0);	-- internal register in order to save the data given by the FIFO (increase the transfer frequency)
	TYPE		SM 	IS (WaitData, PickData, Transfer, Burst);
	Signal		SM_State					: SM;

BEGIN
	
-- Process to update the iRegAlmostEmpty register
UpdateAlmostEmpty:
Process(nReset, Clk)
Begin
	if nReset = '0' then
		iRegAlmostEmpty <= '0';
	elsif rising_edge(Clk) then
		if unsigned(FIFO_number_words) > 3 then
			iRegAlmostEmpty <= '1';
		else
			iRegAlmostEmpty <= '0';
		end if;
	end if;
end process UpdateAlmostEmpty;
	

--  Process to take the datas in the FIFO and send it in the memory
TransferDatas:
Process(nReset, Clk)
Variable Indice : Integer Range 0 to 3;
Variable WaitState : Integer Range 0 to 1;
Begin
	if nReset = '0' then
		iRegCounterAddress	<= (others => '0');
		iRegData		  			<= (others => '0');
		FIFO_Read_Access  	<= '0';
		AM_Addr			  		<= (others => '0');
		AM_Data			  		<= (others => '0');
		AM_Write		  			<= '0';
		AM_BurstCount	  		<= (others => '0');
		SM_State		  			<= WaitData;
		Indice := 0;
		WaitState := 0 ;
	elsif rising_edge(Clk) then
		case SM_State is
			when WaitData =>
				if iRegAlmostEmpty = '1' AND AS_Start = '1' then -- at least one burst in the FIFO and the Start at 1 for begin a burst
					FIFO_Read_Access <= '1'; -- ask an info
					SM_State <= PickData;
				end if;
			when PickData =>
				FIFO_Read_Access <= '1'; -- ask the 2nd info
				SM_State <= Transfer;
			when Transfer =>
				AM_Write <= '1'; -- say to the bus that he is waited
				AM_Data <= FIFO_Data; -- data on the data bus
				AM_Addr <= std_logic_vector(unsigned(AS_Start_Address) + unsigned(iRegCounterAddress)); -- Start adress + current adress on the adress bus
				AM_BurstCount <= X"04";
				SM_State <= Burst;
			when Burst =>
				if AM_WaitRequest = '0' then --wait that the bus has transferred the data
					if Indice = 3 then -- end of the burst, let the bus, reset the register and go to waitdata state
						Indice := 0;
						AM_Write <= '0';
						AM_Data <= (others => '0');
						AM_Addr <= (others => '0');
						AM_BurstCount <= (others => '0');
						iRegCounterAddress <= std_logic_vector (unsigned (iRegCounterAddress) + 4); -- increase the iRegCounterAdress register
						if iRegCounterAddress >= AS_Length then -- when the iRegCounterAddress is equal to the data length (at the end of the 3 buffers), reset the counter to 0 to restart
							iRegCounterAddress <= (others => '0');
						end if;
						SM_State <= WaitData;
					else
						-- burst not ended -> transfer of next datas
						AM_Data <= FIFO_Data; -- FIFO data in the internal register
						FIFO_Read_Access <= '1'; -- ask the next info
						Indice := Indice + 1;
					end if;
				else --the bus has not taken the request
					FIFO_Read_Access <= '0';
				end if;
			when others => null;
		end case;
	end if;
end process TransferDatas;

END bhv;