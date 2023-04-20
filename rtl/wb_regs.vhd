library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_controller_pkg.all;

entity wb_regs is
	port (
		i_clk : in std_ulogic;
		i_arst : in std_ulogic;

		--wishbone b4 (slave) interface
		i_we  : in std_ulogic;
		i_stb : in std_ulogic;
		i_addr : in std_ulogic_vector(1 downto 0);
		i_data : in std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
		o_data : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

		--data read from sdram
		i_sdram_rd_data : in std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);

		--ports for write regs to hierarchy
		o_addr_reg  : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
		o_tx_reg : out std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0)); 
end wb_regs;

architecture rtl of wb_regs is
	signal f_is_data_to_tx : std_ulogic;
	signal w_tx_reg : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
	signal w_addr_reg : std_ulogic_vector(SYS_DATA_WIDTH -1 downto 0);
begin

	-- 					INTERFACE REGISTER MAP

	-- 			Address 		| 		Functionality
	--			   0 			|	(SYS_DATA_WIDTH -1 downto SYS_DATA_WIDTH-2) => i_w_n, i_ads_n, (SYS_ADDR_WIDTH -1 downto 0) => sdram_address
	--			   1 			|	write data to tx
	--			   2 			|	data received from sdram


	f_is_data_to_tx <= '1' when (i_we = '1' and i_stb = '1' and unsigned(i_addr) = 1) else '0';

	manage_intf_regs : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			w_tx_reg <= (others => '0');
			w_addr_reg <= (others => '1');
		elsif (rising_edge(i_clk)) then
			if(i_we = '1' and i_stb = '1') then
				case i_addr is 
					when "00" =>
						w_addr_reg <= i_data;
					when "01" =>
						w_tx_reg <= i_data;
					when others =>	
						null;
				end case;
			elsif (i_we = '0' and i_stb = '1') then
				if(i_addr = "10") then
					o_data <= i_sdram_rd_data;
				end if;
			end if;
		end if;
	end process; -- manage_intf_regs

	o_addr_reg <= w_addr_reg;
	o_tx_reg <= w_tx_reg;
end rtl;