--module to cnt delays like initialization delay (100us), count up until the
--end of read/write transfer bursts as well as count the time until an auto-refresh is due

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_counter is
	port (
			i_clk : in  std_ulogic;
			i_arst : in std_ulogic;
			i_rst_cnt : in std_ulogic;
			i_delay_cycles : in natural range 0 to 2**16-1;
			o_cnt : out unsigned(15 downto 0);
			o_delay_done : out std_ulogic);
end delay_counter;

architecture rtl of delay_counter is 
	signal w_cnt : unsigned(15 downto 0);
begin
	delay_cnt : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			w_cnt <= (others => '0');
			o_delay_done <= '0';
		elsif (rising_edge(i_clk)) then
			if(i_rst_cnt = '1') then	
				w_cnt <= (others => '0');
				o_delay_done <= '0';
			else
				o_delay_done <= '0';
				if(w_cnt < i_delay_cycles-1) then
					w_cnt <= w_cnt + 1;
				else
					w_cnt <= (others => '0');
					o_delay_done <= '1';
				end if;
			end if;
		end if; 
	end process; -- delay_cnt

	o_cnt <= w_cnt;
end rtl;