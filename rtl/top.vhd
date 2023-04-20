library ieee;
use ieee.std_logic_1164.all;
use work.sdram_controller_pkg.all;

entity top is
	port (
			i_clk : in std_ulogic;
			i_arst : in std_ulogic;

			--wishbone b4 (slave) interface
			i_we  : in std_ulogic;
			i_stb : in std_ulogic;
			i_addr : in std_ulogic_vector(1 downto 0);
			i_data : in std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
			o_ack : out std_ulogic;
			o_stall : out std_ulogic; 
			o_data : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

			--interrupts
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

	signal w_tx_reg : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
	signal w_addr_reg : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
	signal w_sdram_rd_data : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

begin

	o_stall <= o_tip;


	manage_ack : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			o_ack <= '0';
		elsif (rising_edge(i_clk)) then
			o_ack <= i_stb and o_stall;
		end if;
	end process; -- manage_ack

	wb_regs : entity work.wb_regs(rtl)
	port map(
		i_clk => i_clk,
		i_arst =>i_arst,

		i_we => i_we,
		i_stb => i_stb,
		i_addr => i_addr,
		i_data => i_data,
		o_data => o_data,

		i_sdram_rd_data => w_sdram_rd_data,

		o_addr_reg =>w_addr_reg,
		o_tx_reg => w_tx_reg
	);

	sdram_top  : entity work.sdram_top(rtl)
	port map(

		i_clk => i_clk,
		i_arst =>i_arst,

		i_addr => w_addr_reg,
		i_data => w_tx_reg,
		o_data => w_sdram_rd_data,

		o_init_done => o_init_done,
		o_tip	=> 	o_tip,
		o_wr_burst_done => o_wr_burst_done,
		o_rd_burst_done => o_rd_burst_done,
		o_data_valid => o_data_valid,


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