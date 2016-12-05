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
	type state_type is (IDLE, READ, RECEIVING);
	signal state, next_state             	: state_type;
	signal addr_reg	    					: std_logic_vector(31 downto 0);
	
	signal burst_counter 					: integer;
	signal word_counter						: integer;
	
	--  TOTAL_LENGTH		 (320/2)*240 = 38400
	constant BURST_LENGTH					: integer := 160;	      --constant = 160
	constant BURST_COUNT					: integer := 240;	      --constant = TOTAL_LENGTH / BURST_LENGTH
	
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
	state_machine_process : process(clk, state)
	
		case state is		
			when IDLE =>
				
			when READ=>
			
				
			when RECEIVING =>
			
		end case;	
	end process state_machine_process;
end architecture RTL;

	