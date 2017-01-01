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
-- AM_nReset <= extern
-- Clock <= extern
--
-- AM_AS_Start <= Slave
-- AM_AS_StartAddress <= Slave
-- AM_AS_Length <= Slave
-- 
-- AM_FIFO_UsedWords <= FIFO
-- FIFO_data <= FIFO
-- 
-- AM_AB_WaitRequest <= Avalon Bus
-- 
-- OUTPUTS
-- AM_FIFO_ReadCheck => FIFO
--
-- AM_AB_MemoryAddress => Avalon Bus
-- AM_AB_MemoryData => Avalon Bus
-- AM_AB_WriteAccess => Avalon Bus
-- AM_AB_BurstCount => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_master IS
	PORT(
		AM_nReset			: IN std_logic;							-- AM_nReset input
		AM_Clk				: IN std_logic;							-- clock input
		
		AM_AB_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_AB_MemoryData	: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_AB_WriteAccess	: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_AB_BurstCount	: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_AB_WaitRequest	: IN std_logic;							-- Pin waitrequest which is 0 when the bus is available
		
		AM_AS_Start			: IN std_logic;							-- Start command
		AM_AS_StartAddress	: IN std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AM_AS_Length		: IN std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		AM_AS_Status		: OUT std_logic;						-- 1 when the image has been written to the memory
		
		AM_FIFO_ReadCheck	: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		AM_FIFO_ReadData	: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		AM_FIFO_UsedWords	: IN std_logic_vector (8 DOWNTO 0)		-- number of 32 bits words
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	constant	BURSTCOUNT_LENGTH 	: unsigned (7 DOWNTO 0) := X"10";
	constant	ADDR_INCREMENT 		: unsigned (7 DOWNTO 0) := X"40";							--(AM_AB_MemoryData'length / 8) * BURSTCOUNT_LENGTH;
	
	signal		iRegAlmostEmpty								: std_logic;						-- internal phantom register which says if there is at least a burst in the FIFO
	signal		iRegCounterAddress, next_iRegCounterAddress	: std_logic_vector (31 DOWNTO 0);	-- internal phantom register which points on the current adress in the memory
	signal 		iRegBurstCount, next_iRegBurstCount 		: unsigned (7 DOWNTO 0);
	
	TYPE		SM 	IS (WAITDATA, BURST, BURSTCOUNT);
	signal		iRegStateSM, next_iRegStateSM				: SM;

BEGIN

process(AM_nReset, AM_Clk)
begin
	if AM_nReset = '0' then
		iRegStateSM <= WAITDATA;
		iRegCounterAddress <= (others => '0');
		iRegBurstCount <= X"00";
		
	elsif rising_edge(AM_Clk) then
		iRegStateSM <= next_iRegStateSM;
		iRegCounterAddress <= next_iRegCounterAddress;
		iRegBurstCount <= next_iRegBurstCount;
	end if;
end process;

process(iRegCounterAddress, iRegStateSM, iRegBurstCount, AM_FIFO_UsedWords, iRegAlmostEmpty, AM_AS_Start, AM_FIFO_ReadData, AM_AS_StartAddress, AM_AB_WaitRequest, AM_AS_Length)
begin
	next_iRegCounterAddress <= iRegCounterAddress;
	next_iRegStateSM <= iRegStateSM;
	next_iRegBurstCount <= iRegBurstCount;
	
	AM_FIFO_ReadCheck <= '0';
	AM_AB_WriteAccess <= '0';
	AM_AB_MemoryAddress <= (others => 'Z');
	AM_AB_MemoryData <= (others => 'Z');
	AM_AB_BurstCount <= (others => 'Z');
	AM_AS_Status <= '0';
	
	if unsigned(AM_FIFO_UsedWords) < BURSTCOUNT_LENGTH then
		iRegAlmostEmpty <= '1';
	else
		iRegAlmostEmpty <= '0';
	end if;
	
	case iRegStateSM is
	
		when WAITDATA =>
			if iRegAlmostEmpty = '0' AND AM_AS_Start = '1' then
				next_iRegStateSM <= BURSTCOUNT;
			end if;
			
		when BURSTCOUNT =>
			AM_AB_BurstCount <= std_logic_vector(BURSTCOUNT_LENGTH);
			AM_AB_MemoryAddress <= std_logic_vector(unsigned(AM_AS_StartAddress) + unsigned(iRegCounterAddress));
			AM_AB_MemoryData <= AM_FIFO_ReadData;
			AM_AB_WriteAccess <= '1';
			
			if AM_AB_WaitRequest = '0' then
				AM_FIFO_ReadCheck <= '1';
				next_iRegStateSM <= BURST;
			end if;
			
		when BURST =>
			AM_AB_MemoryAddress <= std_logic_vector(unsigned(AM_AS_StartAddress) + unsigned(iRegCounterAddress));
			AM_AB_MemoryData <= AM_FIFO_ReadData;
			AM_AB_WriteAccess <= '1';
			
			if AM_AB_WaitRequest = '0' then
			
				AM_FIFO_ReadCheck <= '1';
				next_iRegBurstCount <= iRegBurstCount + 1;
				
				if iRegBurstCount = BURSTCOUNT_LENGTH - 2 then
				
					next_iRegStateSM <= WAITDATA;
					next_iRegBurstCount <= X"00";
					next_iRegCounterAddress <= std_logic_vector(unsigned(iRegCounterAddress) + ADDR_INCREMENT); -- increase the iRegCounterAdress register
					
					if unsigned(iRegCounterAddress) = unsigned(AM_AS_Length) - ADDR_INCREMENT then
						next_iRegCounterAddress <= (others => '0');
						AM_AS_Status <= '1'; --tell to the slave that the image is finished
					end if;
					
				end if;
				
			end if;
		
	end case;
end process;

END bhv;