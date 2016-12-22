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
-- AM_Start <= Slave
-- AS_StartAddress <= Slave
-- AM_Length <= Slave
-- 
-- AM_UsedWords <= FIFO
-- FIFO_data <= FIFO
-- 
-- AM_WaitRequest <= Avalon Bus
-- 
-- OUTPUTS
-- AM_ReadAccess => FIFO
--
-- AM_MemoryAddress => Avalon Bus
-- AM_AvalonData => Avalon Bus
-- AM_WriteRequest => Avalon Bus
-- AM_BurstCount => Avalon Bus

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Avalon_master IS
	PORT(
		AM_nReset			: IN std_logic;							-- AM_nReset input
		AM_Clk				: IN std_logic;							-- clock input
		
		AM_Start			: IN std_logic;							-- Start command
		AS_StartAddress		: IN std_logic_vector (31 DOWNTO 0); 	-- Start Adress in the memory
		AM_Length			: IN std_logic_vector (31 DOWNTO 0);	-- Length of the stored datas
		AM_Status			: OUT std_logic;						-- 1 when the image has been written to the memory
		
		AM_UsedWords		: IN std_logic_vector (8 DOWNTO 0);		-- number of 32 bits words
		AM_ReadAccess		: OUT std_logic;						-- 1 = information asked to the Fifo, 0 = no demand
		AM_FIFOData			: IN std_logic_vector (31 DOWNTO 0);	-- 1 pixel stored in the FIFO by hte camera controller
		
		AM_MemoryAddress	: OUT std_logic_vector (31 DOWNTO 0);	-- Adress sent on the Avalon bus
		AM_AvalonData		: OUT std_logic_vector (31 DOWNTO 0);	-- Datas sent on the Avalon bus
		AM_WriteRequest		: OUT std_logic;						-- Pin write, 1 when the component wants to use the bus
		AM_BurstCount		: OUT std_logic_vector (7 DOWNTO 0);	-- Number of datas in one burst
		AM_WaitRequest		: IN std_logic							-- Pin waitrequest which is 0 when the bus is available
	);
END Avalon_master;

ARCHITECTURE bhv OF Avalon_master IS
	constant    BURSTCOUNT_LENGTH : positive := 16;
	constant    ADDR_INCREMENT : natural := (AM_AvalonData'length / 8) * BURSTCOUNT_LENGTH;
	
	signal		iRegAlmostEmpty				: std_logic;						-- internal phantom register which says if there is at least a burst in the FIFO
	signal		iRegCounterAddress, next_iRegCounterAddress			: std_logic_vector (31 DOWNTO 0);	-- internal phantom register which points on the current adress in the memory
	signal		iRegData					: std_logic_vector (31 DOWNTO 0);	-- internal register in order to save the data given by the FIFO (increase the transfer frequency)
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

process(iRegCounterAddress, reg_SM_state, AM_UsedWords, iRegAlmostEmpty, AM_Start, AM_FIFOData, AS_StartAddress, AM_waitrequest, AM_Length, reg_burstcount)
begin
	next_iRegCounterAddress <= iRegCounterAddress;
	next_reg_SM_state <= reg_SM_state;
	next_reg_burstcount <= reg_burstcount;
	
	AM_MemoryAddress <= (others => '0');
	AM_WriteRequest <= '0';
	AM_AvalonData <= (others => '0');
	AM_burstcount <= (others => '0');
	AM_ReadAccess <= '0';
	AM_Status <= '0';
	
	if unsigned(AM_UsedWords) > 3 then
		iRegAlmostEmpty <= '1';
	else
		iRegAlmostEmpty <= '0';
	end if;

	case reg_SM_state is
		when WaitData =>
			if iRegAlmostEmpty = '1' AND AM_Start = '1' then
				next_reg_SM_state <= STATE_BURSTCOUNT;
			end if;
			
		when STATE_BURSTCOUNT =>
			AM_burstcount <= std_logic_vector(to_unsigned(BURSTCOUNT_LENGTH, AM_burstcount'length));
			AM_AvalonData <= AM_FIFOData;
			AM_MemoryAddress <= std_logic_vector(unsigned(AS_StartAddress) + unsigned(iRegCounterAddress));
			AM_WriteRequest <= '1';
			
			if AM_waitrequest = '0' then
				AM_ReadAccess <= '1';
				next_reg_SM_state <= Burst;
			end if;
			
		when Burst =>
		AM_WriteRequest <= '1';
		AM_MemoryAddress <= std_logic_vector(unsigned(AS_StartAddress) + unsigned(iRegCounterAddress));
		AM_AvalonData <= AM_FIFOData;
		
		if AM_WaitRequest = '0' then
			AM_ReadAccess <= '1';
			next_reg_burstcount <= reg_burstcount + 1;
			
			if reg_burstcount = BURSTCOUNT_LENGTH - 1 then
				next_reg_SM_state <= WaitData;

				next_iRegCounterAddress <= std_logic_vector (unsigned (iRegCounterAddress) + ADDR_INCREMENT); -- increase the iRegCounterAdress register
				if iRegCounterAddress = AM_Length then -- when the iRegCounterAddress is equal to the data length (at the end of the 3 buffers), reset the counter to 0 to restart
					next_iRegCounterAddress <= (others => '0');
					AM_Status <= '1'; --tell to the slave that the image is finished
				end if;
			end if;
		end if;
	end case;
end process;

END bhv;