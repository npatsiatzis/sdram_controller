library ieee;
use ieee.std_logic_1164.all;

--parameters used in the controller of MT48LC64M4A2 SDRAM 

package sdram_controller_pkg is
	-- mode register definition (page 13 of datasheet)

	-- '0' : Programmed Burst Length
	-- '1' : Single Location Access
	constant WRITE_BURST_MODE : std_ulogic := '0'; 	

	--"00" : Standard Operation (Default)
	constant OPERATING_MODE : std_ulogic_vector := "00";

	-- "010" : 2
	-- "011" : 3 
	constant CAS_LATENCY : std_ulogic_vector(2 downto 0) := "010"; 

	-- '0' : Sequential
	-- '1' : Interleaved
	constant BURST_TYPE : std_ulogic := '0';

	-- "000" : 1
	-- "001" : 2
	-- "010" : 4
	-- "011" : 8
	-- "111" : full page
	constant BURST_LENGTH : std_ulogic_vector(2 downto 0) := "011";

	-- bus related parameters (page 1 of datasheet)
	-- 256 MB (4 banks, 8K rows/bank, 2K columns/row, 4bits/column)
	-- Row Addressing (A0-A12)
	-- Column Addresing (A0-A9, A11)
	-- Bank Addressing (BA0,BA1)

	constant RA_WIDTH : natural := 13;
	constant CA_WIDTH : natural := 11;
	constant BA_WIDTH : natural := 2;

	constant SYS_ADDR_WIDTH : natural := RA_WIDTH + CA_WIDTH + BA_WIDTH;
	constant SYS_DATA_WIDTH : natural := 32; --based on burst_length and sdram data width

	constant CA_LSB : natural := 0;	
	constant CA_MSB : natural := CA_WIDTH -1;
	constant BA_LSB : natural := CA_WIDTH;
	constant BA_MSB : natural := CA_WIDTH + BA_WIDTH -1;
	constant RA_LSB : natural := CA_WIDTH + BA_WIDTH;
	constant RA_MSB : natural := SYS_ADDR_WIDTH -1;

	constant SDRAM_ADDR_WIDTH : natural := 13; 		--max(RA_WIDTH,CA_WIDTH)
	constant SDRAM_DATA_WIDTH : natural := 4; 

	--sdram AC timing @100 MHz	(pages 37-38 of datasheet)

	--clock cycle time 
	constant tCK : natural := 10;

	--load mode register to active or refresh commands
	--vhdl integers round down, use thir or ceil from math_real
	constant tMRD : natural := 2*tCK;		

	--precharge command period
	constant tRP : natural := (15 + tCK -1)/ tCK;	

	--auto-refresh period
	constant tRFC : natural := (66 + tCK -1)/ tCK;	

	--active to read or write delay
	constant tRCD : natural := (15 + tCK -1)/ tCK;	

	--write recovery time
	constant tWR : natural := (tCK + 7 + tCK -1)/ tCK;	

	--data-in to active command
	constant tDAL : natural := tRP + tWR;

	constant CL : natural := 2;				-- CAS latency delay
	constant READ_CYCLES : natural :=8;		-- based on burst_length
	constant WRITE_CYCLES : natural :=8;	-- based on burst_length

	--sdram commands (CS# RAS# CAS# WE#)  (page 15 of datasheet)
	constant INHIBIT : std_ulogic_vector(3 downto 0) := "1111";   --(actually it's "1XXX")
	constant NOP : std_ulogic_vector(3 downto 0) := "0111";
	constant ACTIVE : std_ulogic_vector(3 downto 0) := "0011";
	constant READ_cmd : std_ulogic_vector(3 downto 0) := "0101";
	constant WRITE_cmd : std_ulogic_vector(3 downto 0) := "0100";
	constant BUST_TERMINATE : std_ulogic_vector(3 downto 0) := "0110";
	constant PRECHARGE : std_ulogic_vector(3 downto 0) := "0010";
	constant AUTO_REFRESH : std_ulogic_vector(3 downto 0) := "0001";   
	constant LOAD_MODE_REGISTER : std_ulogic_vector(3 downto 0) := "0000";

	--regarding AUTO-REFRESH (page 17 of datasheet)
	--there are two options to ensure that rows are refreshed sufficiently frequently
	--1)providing distributed AUTO-REFRESH commands every 7.81 us will meet refresh requirement
	--2)issue 8192 AUTO-REFRESH commands in a burst with minimum cycles rate of tRFC once every 64ms
	--Here we prefer option 1
	-- 7.81 us ~= 750 cycles of 10ns

	constant AUTO_REFRESH_CYCLES : natural := 75;
	--constant AUTO_REFRESH_CYCLES : natural := 750;

	--regarding INITIALIZATION (page 12 of datasheet)
	--100 us must elapse with only INHIBIT and NOP commands before the initialization cycle
	--can start (prechage, 2 auto-refresh commands and then a load mode register)

	constant INITIALIZATION_DELAY_CYCLES : natural := 10**2;
	--constant INITIALIZATION_DELAY_CYCLES : natural := 10**4;	


	--the controller consists of two main phase of operation, each of which is described by an FSM
	--1) initialization phase
	--2) command (operations) phase

	--these FSMs are designed in a way that each state represents either a sdram command that is issued
	--in said state, or a delay that is to be awaited before moving to a following state 

	--init phase FSM states
	type t_init_states is (i_NOP,i_PRE,i_RP,i_AR_1,i_RFC_1,i_AR_2,i_RFC_2,i_LMR,i_MRD,i_READY);
	--command phase FSM states
	type t_command_states is (c_IDLE,c_AR,c_RFC,c_ACTIVE,c_RCD,c_WRITE,c_WAIT_WR_END_BURST,c_DAL,c_READ,c_WAIT_CL,c_WAIT_RD_END_BURST);

end sdram_controller_pkg;