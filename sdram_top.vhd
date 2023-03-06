library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_controller_pkg.all;

entity sdram_top is
	port (
		--system interface to controller
 		i_clk : in std_ulogic;
 		i_arst : in std_ulogic;
 		i_W_n : in std_ulogic;
 		i_ads_n : in std_ulogic;
 		i_addr : in std_ulogic_vector(SYS_ADDR_WIDTH -1 downto 0);
  		io_data : inout std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
  		o_init_done : out std_ulogic;
  		o_data_valid : out std_ulogic;

 		--interface between controller and sdram
 		io_DQ : inout std_ulogic_vector(SDRAM_DATA_WIDTH -1 downto 0);
 		o_DQM : out std_ulogic;
 		o_CSn : out std_ulogic;
 		o_RASn : out std_ulogic;
 		o_CASn : out std_ulogic;
 		o_WEn : out std_ulogic;
 		o_CKE : out std_ulogic;
 		o_BA : out std_ulogic_vector(1 downto 0);
 		o_ADDR : out std_ulogic_vector(SDRAM_ADDR_WIDTH -1 downto 0)); 
end sdram_top;

architecture rtl of sdram_top is
	signal w_init_state : t_init_states; 
	signal w_command_state : t_command_states;

	signal w_cnt : unsigned(15 downto 0);
	signal w_delay_done : std_ulogic;
	signal w_cnt_refresh : unsigned(15 downto 0);
	signal w_delay_done_refresh : std_ulogic;

	signal w_delay_cycles : natural range 0 to 2**16-1;
begin
	o_DQM <= '0';

init_and_other_delays : entity work.delay_counter(rtl)
	port map (
			i_clk =>i_clk,
			i_arst =>i_arst,
			i_delay_cycles =>w_delay_cycles,
			o_cnt =>w_cnt,
			o_delay_done =>w_delay_done);

refresh_delay : entity work.delay_counter(rtl)
	port map (
			i_clk =>i_clk,
			i_arst =>i_arst,
			i_delay_cycles =>AUTO_REFRESH_CYCLES,
			o_cnt =>w_cnt_refresh,
			o_delay_done =>w_delay_done_refresh);


sdram_control_bus  : entity work.sdram_control_bus(rtl)
	port map(
			--system interface to controller
	 		i_clk =>i_clk,
	 		i_arst =>i_arst,
	 		i_addr =>i_addr,

	 		--internal (hierarchy) controller signals
	 		i_init_state =>w_init_state, 
	 		i_command_state =>w_command_state,

	 		--interface between controller and sdram
	 		o_CSn =>o_CSn,
	 		o_RASn =>o_RASn,
	 		o_CASn =>o_CASn,
	 		o_WEn =>o_WEn,
	 		o_CKE =>o_CKE,
	 		o_BA =>o_BA,
	 		o_ADDR =>o_ADDR); 

sdram_data_bus : entity work.sdram_data_bus(rtl)
	port map(
		--system interface to controller
 		i_clk =>i_clk,
 		i_arst =>i_arst,
 		io_data =>io_data,
 		o_data_valid =>o_data_valid,

 		--internal (hierarchy) controller signals
 		i_command_state =>w_command_state,
 		i_cnt =>w_cnt,

 		--interface between controller and sdram
 		io_DQ =>io_DQ);

sdram_FSM : entity work.sdram_FSM(rtl)
	port map(
		--system interface to controller
 		i_clk =>i_clk,
 		i_arst =>i_arst,
 		i_W_n =>i_W_n,
 		i_ads_n =>i_ads_n,

 		--internal (hierarchy) controller signals
 		i_ar_req =>w_delay_done_refresh,
 		i_delay_100us_done =>w_delay_done,
 		i_cnt =>w_cnt,
 		o_delay_cycles => w_delay_cycles,


 		--interface between controller and sdram
 		o_init_state =>w_init_state, 
 		o_command_state =>w_command_state,
 		o_init_done =>o_init_done);

end rtl;