library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_controller_pkg.all;

entity sdram_FSM is
	port (
		--system interface to controller
 		i_clk : in std_ulogic;
 		i_arst : in std_ulogic;
 		i_W_n : in std_ulogic;
 		i_ads_n : in std_ulogic;

 		--internal (hierarchy) controller signals
 		i_ar_req : in std_ulogic;
 		i_delay_100us_done : in std_ulogic;
 		i_cnt : in unsigned(15 downto 0);
 		o_delay_cycles : out natural range 0 to 2**16-1;

 		--interface between controller and sdram
 		o_init_state : out t_init_states; 
 		o_command_state : out t_command_states;
 		o_init_done : out std_ulogic);
end sdram_FSM;

architecture rtl of sdram_FSM is 
begin
	init_FSM : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			o_init_state <= i_NOP;
			o_init_done <= '0';
		elsif (rising_edge(i_clk)) then
			case o_init_state is 
				when i_NOP =>
					if(i_delay_100us_done = '1') then
						o_init_state <= i_PRE;
					end if;
				when i_PRE =>
					o_init_state <= i_RP;
				when i_RP =>
					if(i_cnt = tRP) then
						o_init_state <= i_AR_1;
					end if;
				when i_AR_1 =>
					o_init_state <= i_RFC_1;
				when i_RFC_1 =>
					if(i_cnt = tRFC) then
						o_init_state <= i_AR_2;
					end if;
				when i_AR_2 =>
					o_init_state <= i_RFC_2;
				when i_RFC_2 =>
					if(i_cnt = tRFC) then
						o_init_state <= i_AR_2;
					end if;
				when i_LMR =>
					o_init_state <= i_MRD;
				when i_MRD =>
					if(i_cnt = tMRD) then
						o_init_state <= i_READY;
					end if;
				when i_READY =>
					o_init_state <= i_READY;
					o_init_done <= '1';
				when others =>
					o_init_state <= i_NOP;
			end case;	
		end if;
	end process; -- init_FSM

	command_FSM : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			o_command_state <= c_IDLE;
		elsif (rising_edge(i_clk)) then
			case o_command_state is 
				when c_IDLE =>
					if(i_ar_req ='1' and o_init_done = '1') then
						o_command_state <= c_AR;
					elsif (i_ads_n = '0' and o_init_done = '1') then
						o_command_state <= c_ACTIVE;
					end if;
				when c_AR =>
					o_command_state <= c_RFC;
				when c_RFC =>
					if(i_cnt = tRFC) then
						o_command_state <= c_IDLE;
					end if;
				when c_ACTIVE =>
					o_command_state <= c_RCD;
				when c_RCD =>
					if(i_cnt = tRCD) then
						if(i_W_n = '1') then
							o_command_state <= c_READ;
						elsif(i_W_n = '0') then
							o_command_state <= c_WRITE;
						end if;
					end if;
				when c_WRITE =>
					o_command_state <= c_WAIT_WR_END_BURST;
				when c_WAIT_WR_END_BURST =>
					if(i_cnt = WRITE_CYCLES) then
						o_command_state <= c_DAL;
					end if;
				when c_DAL =>
					if(i_cnt = tDAL) then
						o_command_state <= c_IDLE;
					end if;
				when c_READ =>
					o_command_state <= c_WAIT_CL;
				when c_WAIT_CL =>
					if(i_cnt = CL) then
						o_command_state <= c_IDLE;
					end if;
				when c_WAIT_RD_END_BURST =>
					if(i_cnt = READ_CYCLES-1) then
						o_command_state <= c_IDLE;
					end if;
				when others =>
					o_command_state <= c_IDLE;
			end case;
		end if;
	end process; -- command_FSM
end rtl;