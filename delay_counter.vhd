library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_counter is
	generic (
			g_delay_cycles : natural :=10**4;
			g_is_init_delay : std_ulogic := '1');
	port (
			i_clk : in  std_ulogic;
			i_arst : in std_ulogic;
			o_delay_done : out std_ulogic);
end delay_counter;

architecture rtl of delay_counter is 
	signal w_cnt : unsigned(15 downto 0);
begin
	init_delay : if g_is_init_delay = '1' generate
		delay_cnt : process(i_clk,i_arst) is
		begin
			if(i_arst = '1') then
				w_cnt <= (others => '0');
				o_delay_done <= '0';
			elsif (rising_edge(i_clk)) then
				if(w_cnt < g_delay_cycles-1) then
					w_cnt <= w_cnt + 1;
				else
					o_delay_done <= '1';
				end if;
			end if; 
		end process; -- delay_cnt
	end generate;

	repetitive_delay : if g_is_init_delay = '0' generate
		delay_cnt : process(i_clk,i_arst) is
		begin
			if(i_arst = '1') then
				w_cnt <= (others => '0');
				o_delay_done <= '0';
			elsif (rising_edge(i_clk)) then
				o_delay_done <= '0';
				if(w_cnt < g_delay_cycles-1) then
					w_cnt <= w_cnt + 1;
				else
					w_cnt <= (others => '0');
					o_delay_done <= '1';
				end if;
			end if; 
		end process; -- delay_cnt
	end generate;
end rtl;