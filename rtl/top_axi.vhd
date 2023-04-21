library ieee;
use ieee.std_logic_1164.all;
use work.sdram_controller_pkg.all;

entity top_axi is
	generic (
			C_S_AXI_DATA_WIDTH : natural := 32;
			C_S_AXI_ADDR_WIDTH : natural :=4);
	port (
			--AXI4-Lite interface
			S_AXI_ACLK : in std_ulogic;
			S_AXI_ARESETN : in std_ulogic;
			--
			S_AXI_AWVALID : in std_ulogic;
			S_AXI_AWREADY : out std_ulogic;
			S_AXI_AWADDR : in std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto 0);
			S_AXI_AWPROT : in std_ulogic_vector(2 downto 0);
			--
			S_AXI_WVALID : in std_ulogic;
			S_AXI_WREADY : out std_ulogic;
			S_AXI_WDATA : in std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
			S_AXI_WSTRB : in std_ulogic_vector(C_S_AXI_DATA_WIDTH/8 -1 downto 0);
			--
			S_AXI_BVALID : out std_ulogic;
			S_AXI_BREADY : in std_ulogic;
			S_AXI_BRESP : out std_ulogic_vector(1 downto 0);
			--
			S_AXI_ARVALID : in std_ulogic;
			S_AXI_ARREADY : out std_ulogic;
			S_AXI_ARADDR : in std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto 0);
			S_AXI_ARPROT : in std_ulogic_vector(2 downto 0);
			--
			S_AXI_RVALID : out std_ulogic;
			S_AXI_RREADY : in std_ulogic;
			S_AXI_RDATA : out std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
			S_AXI_RRESP : out std_ulogic_vector(1 downto 0);

			o_data : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

			--interrupts
			o_init_done : out std_ulogic;
			o_tip : out std_ulogic;
			o_wr_burst_done : out std_ulogic;
			o_rd_burst_done : out std_ulogic;
			o_data_valid : out std_ulogic);
end top_axi;

architecture rtl of top_axi is
	signal i_arst : std_ulogic;
	alias i_clk  : std_ulogic is S_AXI_ACLK;

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
	i_arst <= not S_AXI_ARESETN;

	axil_regs : entity work.axil_regs(rtl)
	generic map(
			C_S_AXI_DATA_WIDTH  =>  32,
			C_S_AXI_ADDR_WIDTH  => 4
	)
	port map(

			--AXI4-Lite interface
			i_clk => i_clk,
			i_arst => i_arst,
			--
			S_AXI_AWVALID => S_AXI_AWVALID,
			S_AXI_AWREADY => S_AXI_AWREADY,
			S_AXI_AWADDR => S_AXI_AWADDR,
			S_AXI_AWPROT => S_AXI_AWPROT,
			--
			S_AXI_WVALID => S_AXI_WVALID,
			S_AXI_WREADY => S_AXI_WREADY,
			S_AXI_WDATA => S_AXI_WDATA,
			S_AXI_WSTRB => S_AXI_WSTRB,
			--
			S_AXI_BVALID => S_AXI_BVALID,
			S_AXI_BREADY => S_AXI_BREADY,
			S_AXI_BRESP => S_AXI_BRESP,
			--
			S_AXI_ARVALID => S_AXI_ARVALID,
			S_AXI_ARREADY => S_AXI_ARREADY,
			S_AXI_ARADDR => S_AXI_ARADDR,
			S_AXI_ARPROT => S_AXI_ARPROT,
			--
			S_AXI_RVALID => S_AXI_RVALID,
			S_AXI_RREADY => S_AXI_RREADY,
			S_AXI_RDATA => o_data,
			S_AXI_RRESP => S_AXI_RRESP,

			--data read from sdram
			i_sdram_rd_data => w_sdram_rd_data,

			--ports for write regs to hierarchy
			o_addr_reg  =>w_addr_reg,
			o_tx_reg =>w_tx_reg
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