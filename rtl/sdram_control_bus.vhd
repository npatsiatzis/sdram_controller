--one of the two parts of the backend of the sdram controller
--namely, the control/command bus between the controller and the sdram

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_controller_pkg.all;

entity sdram_control_bus is
	port (
			--system interface to controller
	 		i_clk : in std_ulogic;
	 		i_arst : in std_ulogic;
	 		i_addr : in std_ulogic_vector(SYS_ADDR_WIDTH -1 downto 0);

	 		--internal (hierarchy) controller signals
	 		i_init_state : in t_init_states; 
	 		i_command_state : in t_command_states;

	 		--interface between controller and sdram
	 		o_CSn : out std_ulogic;
	 		o_RASn : out std_ulogic;
	 		o_CASn : out std_ulogic;
	 		o_WEn : out std_ulogic;
	 		o_CKE : out std_ulogic;
	 		o_BA : out std_ulogic_vector(1 downto 0);
	 		o_ADDR : out std_ulogic_vector(SDRAM_ADDR_WIDTH -1 downto 0)); 
end sdram_control_bus;

architecture rtl of sdram_control_bus is
begin
	control_bus_FSM : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			--datasheet page 15
	 		(o_CSn,o_RASn,o_CASn,o_WEn) <= INHIBIT;
	 		o_CKE <= '0';
	 		o_BA <= (others => '1');
	 		o_ADDR <= (others => '1');		
		elsif (rising_edge(i_clk)) then
			case i_init_state is 
				--wait states after issuing a command and waiting for delay to elapse
				when i_NOP | i_RP | i_RFC_1 | i_RFC_2 | i_MRD =>
					(o_CSn,o_RASn,o_CASn,o_WEn) <= NOP;
			 		o_CKE <= '1';
	 				o_BA <= (others => '1');
			 		o_ADDR <= (others => '1');	
			 	--state that issues precharge command
				when i_PRE =>
					(o_CSn,o_RASn,o_CASn,o_WEn) <= PRECHARGE;
			 		o_CKE <= '1';
			 		o_BA <= (others => '1');
			 		o_ADDR <= (others => '1');			--A10 high, thus precharge ALL banks
			 	--states that issue issue the 2 auto-refresh commands  
				when i_AR_1 | i_AR_2 =>
					(o_CSn,o_RASn,o_CASn,o_WEn) <= AUTO_REFRESH;
			 		o_CKE <= '1';
			 		o_BA <= (others => '1');
			 		o_ADDR <= (others => '1');	
			 	--state that issues the load mode register command
			 	--mode register is loaded via inputs A0-A11 (A12 should be driven low)
			 	--should progr. A12-10 to '0'for compatibility with future devices (datasheet page 13)
			 	when i_LMR	 =>
					(o_CSn,o_RASn,o_CASn,o_WEn) <= LOAD_MODE_REGISTER;
			 		o_CKE <= '1';
			 		o_BA <= (others => '1');
			 		o_ADDR <= "000" & WRITE_BURST_MODE & OPERATING_MODE &  CAS_LATENCY &  BURST_TYPE & BURST_LENGTH;	
				when i_READY =>
					case i_command_state is 
						--states that either wait for event(idle) or delay to elapse(rest)
						when c_IDLE | c_RFC | c_RCD | c_WAIT_WR_END_BURST | c_DAL | c_WAIT_CL | c_WAIT_RD_END_BURST =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= NOP;
					 		o_CKE <= '1';
					 		o_BA <= (others => '1');
					 		o_ADDR <= (others => '1');	
						when c_AR =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= AUTO_REFRESH;
					 		o_CKE <= '1';
					 		o_BA <= (others => '1');
					 		o_ADDR <= (others => '1');	
						when c_ACTIVE =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= ACTIVE;
					 		o_CKE <= '1';
					 		o_BA <= i_addr(BA_MSB downto BA_LSB);
					 		o_ADDR <= i_addr(RA_MSB downto RA_LSB);
					 	when c_WRITE =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= WRITE_cmd;
					 		o_CKE <= '1';
					 		o_BA <= i_addr(BA_MSB downto BA_LSB);
					 		--address provided on A0-A9 (for x4) provided the starting column location
					 		--A12 is don't care for x4(datasheeet page 16)
					 		--A10 determines whether auto-precharge is used
					 		o_ADDR <= '1' & i_addr(CA_MSB) & '1' & i_addr(CA_MSB-1 downto 0);
					 	when c_READ =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= READ_cmd;
					 		o_CKE <= '1';
					 		o_BA <= i_addr(BA_MSB downto BA_LSB);
 					 		--address provided on A0-A9 (for x4) provided the starting column location
					 		--A12 is don't care for x4(datasheeet page 16)
					 		--A10 determines whether auto-precharge is used
					 		o_ADDR <= '1' & i_addr(CA_MSB) & '1' & i_addr(CA_MSB-1 downto 0);
						when others =>
							(o_CSn,o_RASn,o_CASn,o_WEn) <= NOP;
					 		o_CKE <= '1';
					 		o_BA <= (others => '1');
					 		o_ADDR <= (others => '1');	
					end case;
				when others =>
					(o_CSn,o_RASn,o_CASn,o_WEn) <= NOP;
			 		o_CKE <= '1';
			 		o_BA <= (others => '1');
			 		o_ADDR <= (others => '1');	
			end case;
		end if;
	end process; -- control_bus_FSM
end rtl;