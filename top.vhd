library ieee;
use ieee.std_logic_1164.all;
use work.sdram_controller_pkg.all;

entity top is
	port (
			i_clk : in std_ulogic;
			i_arst : in std_ulogic;

			i_W_n : in std_ulogic;
			i_ads_n : in std_ulogic;
			i_addr : in std_ulogic_vector(SYS_ADDR_WIDTH -1 downto 0);
			--io_data : inout std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
			i_data : in std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
			o_data : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

			o_init_done : out std_ulogic;
			o_tip : out std_ulogic;
			o_wr_burst_done : out std_ulogic;
			o_rd_burst_done : out std_ulogic;
			o_data_valid : out std_ulogic);
end top;

architecture rtl of top is
    signal w_DQ_ctrl, w_DQ_sdram : std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
	signal w_DQM : std_ulogic;
	signal w_CSn : std_ulogic;
	signal w_RASn : std_ulogic;
	signal w_CASn : std_ulogic;
	signal w_WEn : std_ulogic;
	signal w_CKE : std_ulogic;
	signal w_BA : std_ulogic_vector(BA_WIDTH-1 downto 0);
	signal w_ADDR : std_ulogic_vector(SDRAM_ADDR_WIDTH-1 downto 0);

begin

	sdram_top  : entity work.sdram_top(rtl)
	port map(
		--system interface to controller
		i_clk => i_clk,
		i_arst =>i_arst ,
		i_W_n => i_W_n,
		i_ads_n => i_ads_n,
		i_addr => i_addr,
		--io_data => io_data,
		i_data => i_data,
		o_data => o_data,
		o_init_done => o_init_done,
		o_tip	=> 	o_tip,
		o_wr_burst_done => o_wr_burst_done,
		o_rd_burst_done => o_rd_burst_done,
		o_data_valid => o_data_valid,

		--interface between controller and sdram
		--io_DQ => w_DQ,
		i_DQ =>w_DQ_sdram,
		o_DQ =>w_DQ_ctrl,
		o_DQM => w_DQM,
		o_CSn => w_CSn,
		o_RASn => w_RASn,
		o_CASn => w_CASn,
		o_WEn => w_WEn,
		o_CKE => w_CKE,
		o_BA => w_BA,
		o_ADDR => w_ADDR  
	);

	mt48lc64m4a2 : entity work.mt48lc64m4a2(rtl)
	port map(
		i_DQ =>w_DQ_ctrl, 
		o_DQ =>w_DQ_sdram,
		--Dq=> w_DQ,
		Addr=> w_ADDR,
		Ba=> w_BA,
		i_clk=> i_clk,
		Cs_n=> w_CSn,
		Ras_n=> w_RASn,
		Cas_n=> w_CASn,
		We_n=> w_WEn,
		Dqm=> w_DQM 
		);


end rtl;