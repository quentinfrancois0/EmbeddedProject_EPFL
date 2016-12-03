library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_Master is
	port(	
		clk                : in  std_logic;
		Rst                : in  std_logic;
		
		-- Avalon bus signals
		AM_Address         : out std_logic_vector(31 downto 0);
		AM_ByteEnable 	   : out std_logic_vector(3 downto 0);		
		AM_Rd              : out std_logic;
		AM_RdDataValid     : in  std_logic;
		AM_Burstcount      : out std_logic_vector(7 downto 0);	
		AM_RdData          : in  std_logic_vector(31 downto 0);	
		AM_WaitRequest     : in  std_logic;
		
		-- Slave signals
		MS_Address         : in  std_logic_vector(31 downto 0);
		MS_StartDMA        : in  std_logic;
		
		-- LCD Controller signals
		ML_Busy            : out std_logic;
		
		-- FIFO signals
		FIFO_Full          : in  std_logic;
		FIFO_Wr            : out std_logic;
		FIFO_WrData        : out std_logic_vector(31 downto 0);
		FIFO_Almost_Full   : in  std_logic		
	);
end entity LCD_Master;

architecture RTL of LCD_Master is
	type state_type is (IDLE, READING, RECEIVING);
	signal state, next_state             	: state_type;
	signal addr_reg	    					: std_logic_vector(31 downto 0);
	
	signal burst_counter 					: integer;
	signal word_counter						: integer;
	
	--  TOTAL_LENGTH		 (320/2)*240 = 38400
	constant BURST_LENGTH					: integer := 16;	      --constant = 16
	constant BURST_COUNT					: integer := 2400;	      --constant = TOTAL_LENGTH / BURST_LENGTH
	
begin
	--Handle reset procedure and state changes
	run_process : process(clk, Rst) is
	begin
		if Rst = '1' then
			state           <= IDLE;
			next_state      <= IDLE;
			addr_reg        <= (others => '0');
			ML_Busy         <= '0';
		elsif rising_edge(clk) then
			state           <= next_state;
		end if;
	end process run_process;
	
	--??? rising_edge to make it syncronous ???
	state_machine_process : process(clk, state, MS_StartDMA)
	
		case state is		
			when IDLE =>
				ML_Busy <= '0';
				if (MS_Start_DMA == '1') then
					addr_reg <= MS_Address;
					burst_counter <= 0;
					next_state <= READING;				
				end if;	
				
			when READING =>
				ML_Busy <= '1';
				if (burst_counter == BURST_COUNT) then				
					next_state <= IDLE;					
				elsif (FIFO_Almost_Full == '0') then
					word_counter <= 0;
					AM_Address <= addr_reg;
					AM_Burstcount <= std_logic_vector(to_unsigned(BURST_LENGTH,8));
					AM_Rd <= '1';					
					if (AM_WaitRequest == '0') then
						next_state <= RECEIVING;	
					end if;
				end if;	
				
			when RECEIVING =>
				if (word_counter == BURST_LENGTH) then
					burst_counter <= burst_counter + 1;
					addr_reg <= std_logic_vector(to_unsigned(to_integer(unsigned(addr_reg)) + BURST_LENGTH));
					next_state <= READING;
				else
					FIFO_Wr <= AM_RdDataValid
					FIFO_WrData <= AM_RdData
					if (AM_RdDataValid == '1') then
						burst_counter <= burst_counter + 1;
					end if;
				end if;				
		end case;	
	end process state_machine_process;
end architecture RTL;

	
--	address <= std_logic_vector(address_dma_reg);
--	address_master_debug <= std_logic_vector(address_dma_reg);
--	write_data <= write_data_reg;
	
	
	-- state_machine_process : process(state_reg, address_dma, len_dma, start_dma, fifo_full, len_dma_reg, read_data, wait_request, address_dma_reg) is
	-- begin
		-- state_next       <= state_reg;
		-- running          <= '1';
		-- read             <= '0';
		-- read_debug       <= '0';
		
		-- write_fifo       <= '0';
		-- write_data_next  <= write_data_reg;
		-- address_dma_next <= address_dma_reg;
		-- len_dma_next     <= len_dma_reg;
		-- case state_reg is
			-- when IDLE =>
				-- running <= '0';
				-- if (start_dma = '1') then
					-- running          <= '1';
					-- address_dma_next <= unsigned(address_dma);
					-- len_dma_next     <= unsigned(len_dma);
					-- state_next       <= READ_REQUEST;
				-- end if;
			-- when READ_REQUEST =>
				-- read <= '1';
				-- read_debug <= '1';
				-- if (wait_request = '0') then
					-- state_next <= READ_AVAILABLE;
				-- end if;
				-- write_data_next       <=  read_data;
			
			-- when READ_AVAILABLE =>
			-- if(fifo_full = '0') then
				-- write_fifo <= '1';
				-- state_next <= READ_REQUEST;
				-- if (len_dma_reg = X"00000001") then
					-- state_next <= IDLE;
				-- end if;
				-- len_dma_next <= len_dma_reg - 1;
				-- address_dma_next <= address_dma_reg + 4;
			-- end if;
		-- end case;
		
		
	-- end process state_machine_process;

	-- rst_process : process(clk, Rst) is
	-- begin
		-- if reset_n = '0' then
			-- state_reg       <= IDLE;
			-- address_dma_reg <= (others => '0');
			-- write_data_reg <= (others => '0');
			-- len_dma_reg     <= (others => '0');
		-- elsif rising_edge(clk) then
			-- state_reg       <= state_next;
			-- address_dma_reg <= address_dma_next;
			-- len_dma_reg     <= len_dma_next;
			-- write_data_reg <= write_data_next;
		-- end if;
	-- end process rst_process;
