--one of the two parts of the backend of the sdram controller
--namely, the data bus between the controller and the sdram

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_controller_pkg.all;

entity sdram_data_bus is
	port (
		--system interface to controller
 		i_clk : in std_ulogic;
 		i_arst : in std_ulogic;
 		io_data : inout std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
 		o_data_valid : out std_ulogic;

 		--internal (hierarchy) controller signals
 		i_command_state : in t_command_states;
 		i_cnt : in unsigned(15 downto 0);

 		--interface between controller and sdram
 		io_DQ : inout std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0));
end sdram_data_bus;

architecture rtl of sdram_data_bus is
	signal w_o_DQ : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_0 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_1 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_2 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_3 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_4 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_5 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_6 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_DQ_7 : std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
	signal w_i_DQ : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
begin

	io_data <= w_i_DQ when(o_data_valid = '1') else (others => 'Z');
	rd_data_valid_gen : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			o_data_valid <= '0';
		elsif (rising_edge(i_clk)) then
			if(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 7) then
				o_data_valid <= '1';
			else
				o_data_valid <= '0';
			end if;
		end if;
	end process; -- rd_data_valid_gen

	w_i_DQ <= w_DQ_7 & w_DQ_6 & w_DQ_5 & w_DQ_4 & w_DQ_3 & w_DQ_2 & w_DQ_1 & w_DQ_0;

	gen_DQ_to_system : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			w_DQ_0 <= (others => '0');
			w_DQ_1 <= (others => '0');
			w_DQ_2 <= (others => '0');
			w_DQ_3 <= (others => '0');
			w_DQ_4 <= (others => '0');
			w_DQ_5 <= (others => '0');
			w_DQ_6 <= (others => '0');
			w_DQ_7 <= (others => '0');	
		elsif(rising_edge(i_clk)) then
			w_DQ_0 <= w_i_DQ(3 downto 0);
			w_DQ_1 <= w_i_DQ(7 downto 4);
			w_DQ_2 <= w_i_DQ(11 downto 8);
			w_DQ_3 <= w_i_DQ(15 downto 12);
			w_DQ_4 <= w_i_DQ(19 downto 16);
			w_DQ_5 <= w_i_DQ(23 downto 20);
			w_DQ_6 <= w_i_DQ(27 downto 24);
			w_DQ_7 <= w_i_DQ(31 downto 28);	
			if(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 0) then
				w_DQ_0 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 1) then
				w_DQ_1 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 2) then
				w_DQ_2 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 3) then
				w_DQ_3 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 4) then
				w_DQ_4 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 5) then
				w_DQ_5 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 6) then
				w_DQ_6 <= io_DQ;
			elsif(i_command_state = c_WAIT_RD_END_BURST and i_cnt = 7) then
				w_DQ_7 <= io_DQ;
			end if;
		end if;
	end process; -- gen_DQ_to_system

	io_DQ <= w_o_DQ when (i_command_state = c_WAIT_WR_END_BURST) else "ZZZZ";

	gen_DQ_to_SDRAM : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			w_o_DQ <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(i_command_state = c_WRITE) then
				w_o_DQ <= io_data(3 downto 0);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 0) then
				w_o_DQ <= io_data(7 downto 4);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 1) then
				w_o_DQ <= io_data(11 downto 8);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 2) then
				w_o_DQ <= io_data(15 downto 12);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 3) then
				w_o_DQ <= io_data(19 downto 16);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 4) then
				w_o_DQ <= io_data(23 downto 20);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 5) then
				w_o_DQ <= io_data(27 downto 24);
			elsif (i_command_state = c_WAIT_WR_END_BURST and i_cnt = 6) then
				w_o_DQ <= io_data(31 downto 28);
			else
				w_o_DQ <= (others => '1');			
			end if;
		end if;
	end process; -- gen_DQ_to_SDRAM
end rtl;