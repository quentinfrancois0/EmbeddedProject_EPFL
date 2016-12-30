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
	constant    BURSTCOUNT_LENGTH : positive := 16;
	constant    ADDR_INCREMENT : natural := (AM_AB_MemoryData'length / 8) * BURSTCOUNT_LENGTH;
	
	signal		iRegAlmostEmpty				: std_logic;						-- internal phantom register which says if there is at least a burst in the FIFO
	signal		iRegCounterAddress, next_iRegCounterAddress			: std_logic_vector (31 DOWNTO 0);	-- internal phantom register which points on the current adress in the memory
	TYPE		SM 	IS (WaitData, Burst, STATE_BURSTCOUNT);
	Signal		reg_SM_State, next_reg_SM_state					: SM;
	
	signal reg_burstcount, next_reg_burstcount : natural;

BEGIN

process(AM_nReset, AM_Clk)
begin
	if AM_nReset = '0' then
		reg_SM_state <= WaitData;
		iRegCounterAddress <= (others => '0');
		reg_burstcount <= 0;
		
	elsif rising_edge(AM_Clk) then
		reg_SM_state <= next_reg_SM_state;
		iRegCounterAddress <= next_iRegCounterAddress;
		reg_burstcount <= next_reg_burstcount;
	end if;
end process;

process(iRegCounterAddress, reg_SM_state, AM_FIFO_UsedWords, iRegAlmostEmpty, AM_AS_Start, AM_FIFO_ReadData, AM_AS_StartAddress, AM_AB_WaitRequest, AM_AS_Length, reg_burstcount)
begin
	next_iRegCounterAddress <= iRegCounterAddress;
	next_reg_SM_state <= reg_SM_state;
	next_reg_burstcount <= reg_burstcount;
	
	AM_AB_MemoryAddress <= (others => 'Z');
	AM_AB_WriteAccess <= '0';
	AM_AB_MemoryData <= (others => 'Z');
	AM_AB_BurstCount <= (others => 'Z');
	AM_FIFO_ReadCheck <= '0';
	AM_AS_Status <= '0';
	
	if unsigned(AM_FIFO_UsedWords) > 3 then
		iRegAlmostEmpty <= '1';
	else
		iRegAlmostEmpty <= '0';
	end if;

	case reg_SM_state is
		when WaitData =>
			if iRegAlmostEmpty = '1' AND AM_AS_Start = '1' then
				next_reg_SM_state <= STATE_BURSTCOUNT;
			end if;
			
		when STATE_BURSTCOUNT =>
			AM_AB_BurstCount <= std_logic_vector(to_unsigned(BURSTCOUNT_LENGTH, AM_AB_BurstCount'length));
			AM_AB_MemoryData <= AM_FIFO_ReadData;
			AM_AB_MemoryAddress <= std_logic_vector(unsigned(AM_AS_StartAddress) + unsigned(iRegCounterAddress));
			AM_AB_WriteAccess <= '1';
			
			if AM_AB_WaitRequest = '0' then
				AM_FIFO_ReadCheck <= '1';
				next_reg_SM_state <= Burst;
			end if;
			
		when Burst =>
		AM_AB_WriteAccess <= '1';
		AM_AB_MemoryAddress <= std_logic_vector(unsigned(AM_AS_StartAddress) + unsigned(iRegCounterAddress));
		AM_AB_MemoryData <= AM_FIFO_ReadData;
		
		if AM_AB_WaitRequest = '0' then
			AM_FIFO_ReadCheck <= '1';
			next_reg_burstcount <= reg_burstcount + 1;
			
			if reg_burstcount = BURSTCOUNT_LENGTH - 1 then
				next_reg_SM_state <= WaitData;

				next_iRegCounterAddress <= std_logic_vector (unsigned (iRegCounterAddress) + ADDR_INCREMENT); -- increase the iRegCounterAdress register
				if iRegCounterAddress = AM_AS_Length then -- when the iRegCounterAddress is equal to the data length (at the end of the 3 buffers), reset the counter to 0 to restart
					next_iRegCounterAddress <= (others => '0');
					AM_AS_Status <= '1'; --tell to the slave that the image is finished
				end if;
			end if;
		end if;
	end case;
end process;

END bhv;