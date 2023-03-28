--controller for the Winbond W9212G6JH-75 sdram
--2M words x 4 banks x 16 bits
--Supported CAS latency : 2 and 3
--Supported burst length : 1, 2, 4 ,8 , row
--Burst read, Single Writes mode

--In this implementation a row is always subsequenetly closed
--or precharged in sdram parlance, after a read or write operation/
--Another possibility is to leave a row open, until a refresh is required.

--Worst cases performance (single accesses to different rows or banks):
--Read/Write : 70 ns, i.e 7 cycles with a 100MHz clock.
--This corresponds to the Trc delay, or else the activate to activate delay.


--SDRAM-side ports explanation (suffix _n -> active low):
--o_sd_cke : 
	--controls clock activation and deactivation
--o_sd_cs_n : 
	--disable/enable the sdram's command decoder. disabled -> new commands ignored
--o_sd_bs_n : 
	--select bank to activate (open row) during row adress latch time, 
	--or bank to rd/wr during adress latch time
--o_sd_cas_n :
	--when sampled at rising edge of the clock, o_ras_n, o_cas_n, o_we_n
	--define the operation to be executed
--o_sd_ras_n :
	--refer to o_cas_n
--o_sd_we_n :
	--refer t o_cas_n
--o_sd_addr :
	--multiplexed pins for row and column address.
	--row addr. A0-A12 , column addr A0-A8
	--NOTE : A10 : during precharge (close row) : 0 -> single bank , 1 -> all banks
				 --during rw/wr : 0 -> disable auto-precharge , 1-> enable auto-precharge 
--io_sd_data :
	--multiplexed pins for data input/output 
--o_sd_dqmh :
	--input/output mask. When '1' in case of write operation,
	--the write will be blocked with 0 latency. In case of read,
	--output buffer is placed at high-Z.
--o_sd_dqml : 

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

entity sdram_controller is
	generic(
		g_sys_clock : natural := 100;			--system clock freq. in MHz
		g_host_row_addr_width : natural := 13;
		g_host_col_addr_width : natural := 9;
		g_bank_addr_width : natural :=2 ;
		g_host_addr_width : natural := 24;
		g_sd_addr_width : natural :=13;
		g_data_width : natural :=16);
	port(
		--HOST INTERFACE
		i_clk : in std_ulogic;			--system clock, 100MHz 
		i_rst : in std_ulogic;			--reset, active high
		i_refresh : in std_ulogic;		--refresh sdram
		i_rw : in std_ulogic;			--initiate read/write operation
		i_we_n : in std_ulogic;			--write enable
		i_ub : in std_ulogic;			--mask upper byte
		i_lb : in std_ulogic;			--mask lower byte
		i_addr : in std_ulogic_vector(g_host_addr_width -1 downto 0);   --address to memory
		i_data : in std_ulogic_vector(g_data_width -1 downto 0);		--data to memory
		o_ready : out std_ulogic; 		--'1' when memory is ready for transaction
		o_done : out std_ulogic;		--'1' when read/write/refresh operation is done
		o_data : out std_ulogic_vector(g_data_width -1 downto 0);	--data from memory
		--SDRAM INTERFACE
		o_sd_cke   : out std_ulogic;	
		o_sd_cs_n  : out std_ulogic;	
		o_sd_bs_n  : out std_ulogic_vector(g_bank_addr_width -1 downto 0); 
		o_sd_cas_n : out std_ulogic;
		o_sd_ras_n : out std_ulogic;
		o_sd_we_n  : out std_ulogic;
		o_sd_addr  : out std_ulogic_vector(g_sd_addr_width -1 downto 0);
		io_sd_data : inout std_ulogic_vector(g_data_width -1 downto 0);
		o_sd_dqmh  : out std_ulogic;
		o_sd_dqml  : out std_ulogic);
end sdram_controller;

architecture arch of sdram_controller is
	--there are states related to intialization after power up (prefixed with INIT_)
	--and there are states concering the normal operation after initialization.
	--the latter ones are named based on the delays and sequence of events tracing
	--one memory access, from activation (open row) to precharge (close row). 

	--The delays of normal operation are:
	--Trcd : activate to read/write delay, 20 ns
	--Tcas : read/write to data out delay, 2 clk
	--Tras : activate to precharge delay, 50 ns
	--Trp  : precharge to activate delay, 20 ns
	--Trc  : activate to activate delay (access time for single access), 70 ns
	type t_state_sdram is (TO_ACTIVATE,INIT_PAUSE,INIT_MODE_REGISTER,INIT_PRECHARGE,INIT_REFRESH_PRE,
		INIT_REFRESH_POST,REFRESH,ACTIVATE,TO_RW,RW,TO_OUT1,TO_OUT2,PRECHARGE);
	signal r_state : t_state_sdram;

	
	--clock frequency given in MHz
	--delays in various states given in us
	constant INIT_PAUSE_DELAY : natural := 2; --init pause delay in us
	--constant INIT_PAUSE_DELAY : natural := 200; --init pause delay in us
	constant PRECHARGE_PAUSE_DELAY : real := 0.02; -- 20 ns -> 0.02 us
	constant SET_MODE_PAUSE_DELAY : real := 0.02;	 -- 20 ns -> 0.02 us
	constant REFRESH_PAUSE_DELAY : real := 0.07;   -- 70ns -> 0.07us

	--translate delays to clock cycles
	constant PAUSE_CYCLES : natural := natural(ceil(real(g_sys_clock * INIT_PAUSE_DELAY)));
	constant PRECHARGE_CYCLES : natural := natural(ceil(real(real(g_sys_clock) * PRECHARGE_PAUSE_DELAY)));
	constant SET_MODE_CYCLES : natural := natural(ceil(real(real(g_sys_clock) * SET_MODE_PAUSE_DELAY)));
	constant REFRESH_CYCLES : natural := natural(ceil(real(real(g_sys_clock) * REFRESH_PAUSE_DELAY)));

	signal count_cycles : integer range 0 to PAUSE_CYCLES;


	--signals to/from host
	signal r_done : std_ulogic;
	signal r_ready : std_ulogic;
	signal r_buff_out : std_ulogic_vector(g_data_width -1 downto 0);

	signal w_row_addr : std_ulogic_vector(g_host_row_addr_width -1 downto 0);
	signal w_col_addr : std_ulogic_vector(g_host_col_addr_width -1 downto 0);
	signal w_bank_addr : std_ulogic_vector(g_bank_addr_width -1 downto 0);


	--A12-A10|    A9   |A8-A7|A6-A4 |  A3	   |A2-A0
	-- 	     |w/r burst|	 |cas l.|addr. mode|burst. len.
	--Select CAS latency = 2 -> A6-A4 = 010
	--Select no burst -> A9 = 0
	--A10 can be turned to '1' during precharge to precharge all banks.
	constant mode_register : std_ulogic_vector(g_sd_addr_width -1 downto 0):=("000" & "0" & "00" & "010" & "0" & "000");

	--Encode main sdram commands, as defined by ras_n,cas_n
	--we_n. Also cs_n must be low to enable the command decoder.
	subtype slvu_4 is std_ulogic_vector(3 downto 0);

	constant c_ACTIVATE	: slvu_4 	:= "0011";
	constant c_PRECHARGE: slvu_4	:= "0010";
	constant c_WRITE	: slvu_4 	:= "0100";
	constant c_READ		: slvu_4 	:= "0101";
	constant c_SET_MODE : slvu_4 	:= "0000";
	constant c_NOP 	    : slvu_4 	:= "0111";
	constant c_REFRESH  : slvu_4 	:= "0001";


	--to SDRAM
	signal r_cmd : slvu_4;
	signal r_sd_bus_dir : std_ulogic; --dir. of sd data bus
	signal r_sd_dqmh : std_ulogic;
	signal r_sd_dqml : std_ulogic;
	signal r_sd_cke : std_ulogic;
	signal r_sd_addr : std_ulogic_vector(g_sd_addr_width -1 downto 0);
	signal r_sd_bs_n : std_ulogic_vector(g_bank_addr_width -1 downto 0);
	signal r_sd_data : std_ulogic_vector(g_data_width -1 downto 0);
begin

	o_done <= r_done;
	o_ready <= r_ready;
	o_data <= r_buff_out;

	--manage signls from host side
	w_bank_addr <= i_addr(g_host_addr_width-1 downto g_host_addr_width-2);
	w_row_addr <= i_addr(g_host_addr_width-3 downto g_host_col_addr_width);
	w_col_addr <= i_addr(g_host_col_addr_width-1 downto 0);

	--output signals to sdram side 
	o_sd_addr <= r_sd_addr;
	o_sd_bs_n <= r_sd_bs_n;
	o_sd_cke <= r_sd_cke;
	o_sd_dqmh <= r_sd_dqmh;
	o_sd_dqml <= r_sd_dqml;
	io_sd_data <= r_sd_data when r_sd_bus_dir = '1' else (others => 'Z');
	(o_sd_cs_n,o_sd_ras_n,o_sd_cas_n,o_sd_we_n) <= r_cmd;


	--After power-up initialization procedure:
	--1) wait for 200 us with both dqm at '1' and cmd NOP  (state : INIT_PAUSE)
	--2) precharge all banks	(state : INIT_PRECHARGE)
	--3) 8 refresh cycles pre set mode reg.	(state : INIT_REFRESH_PRE)
	--4) set mode register 	(state : INIT_MODE_REGISTER)
	--5) 8 refresh cycles post set mode reg. 	(state : INIT_REFRESH_POST)

	sdram_FSM : process(i_clk)
	begin
		if(i_rst = '1') then
			r_state <= INIT_PAUSE;
			r_cmd <= c_NOP;
			count_cycles <= 0;
		elsif (rising_edge(i_clk)) then
			r_done <= '0';
			r_ready <= '0';
			r_sd_bs_n <= w_bank_addr;
			r_sd_addr <= "0000" & w_col_addr;
			r_sd_cke <= '1';
			r_sd_dqmh <= '0';
			r_sd_dqml <= '0';
			case(r_state) is
				when INIT_PAUSE=>
					r_sd_dqmh <= '1';
					r_sd_dqml <= '1';
					count_cycles <= PAUSE_CYCLES;
					if(count_cycles /= 0) then
						count_cycles <= count_cycles -1;
					else
						r_state <= INIT_PRECHARGE;
					end if;
				when INIT_PRECHARGE =>
					r_cmd <= c_PRECHARGE;		--cmd, addr(10) should be set last step of prev state
					r_sd_addr(10) <= '1';		--percharge all banks
					r_sd_bs_n <= "00";			--does not matter, must be valid
					count_cycles <= PRECHARGE_CYCLES;		
					if(count_cycles /= 0) then
						count_cycles <= count_cycles-1;
					else
						r_state <= INIT_REFRESH_PRE;
					end if;	
				when INIT_REFRESH_PRE =>
					count_cycles <= 8; 			--8 refresh cycles
					if(count_cycles /= 0) then
						count_cycles <= count_cycles -1;
						r_cmd <= c_REFRESH;
					else
						r_state <= INIT_MODE_REGISTER;	--MAYBE HAVE TO WAIT 70ns more
					end if;
				when INIT_MODE_REGISTER =>
					r_cmd <= c_SET_MODE;
					r_sd_addr <= mode_register;
					r_sd_bs_n <= "00";
					count_cycles <= SET_MODE_CYCLES;
					if(count_cycles /= 0) then
						count_cycles <= count_cycles -1;
					else
						r_state <= INIT_REFRESH_POST;
					end if;
				when INIT_REFRESH_POST =>
					count_cycles <= 8; 			--8 refresh cycles
					if(count_cycles /= 0) then
						count_cycles <= count_cycles -1;
						r_cmd <= c_REFRESH;
					else
						r_state <= TO_ACTIVATE;	--MAYBE HAVE TO WAIT 70ns more
					end if;
				when TO_ACTIVATE =>
					r_ready <= '1';				
					if(i_rw = '1') then
						r_sd_addr <= w_row_addr;
						r_cmd <= c_ACTIVATE;
						r_state <= ACTIVATE;
					elsif (i_refresh = '1') then
						count_cycles <= REFRESH_CYCLES;
						r_cmd <= c_REFRESH;
						if(count_cycles /= 0) then
							count_cycles <= count_cycles -1;
						else
							r_state <= REFRESH;
						end if;
					end if;
				when REFRESH => 
					r_done <= '1';
					r_state <= TO_ACTIVATE;
				when ACTIVATE =>
					r_sd_data <= i_data;
					r_state <= TO_RW;
				when TO_RW =>
					r_state <= RW;
					if(i_we_n = '0') then
						r_cmd <= c_WRITE;
						r_sd_bus_dir <= '1';
						r_sd_dqmh <= i_ub;
						r_sd_dqml <= i_lb;
					else
						r_cmd <= c_READ;
					end if;
				when RW =>
					r_sd_bus_dir <= '0';
					r_state <= TO_OUT1;
				when TO_OUT1 => 
					r_buff_out <= io_sd_data;
					r_state <= TO_OUT2;
				when TO_OUT2 =>
					r_sd_addr(10) <= '1';
					r_cmd <= c_PRECHARGE;
					r_state <= PRECHARGE;
				when PRECHARGE =>
					r_done <= '1';
					count_cycles <=1;
					if(count_cycles /= 0) then
						count_cycles <= count_cycles -1;
					else
						r_state <= TO_ACTIVATE;
					end if;
				when others =>
					r_state <= TO_ACTIVATE;
			end case;

		end if;
	end process; -- sdram_FSM




end arch;