library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mt48lc64m4a2 is
	port (
	 		i_clk : in std_ulogic;
	 		Cs_n : in std_ulogic;
	 		Cas_n : in std_ulogic;
	 		Ras_n : in std_ulogic;
	 		We_n : in std_ulogic;
	 		Dqm : in std_ulogic;
	 		--Dq : inout std_logic_vector(3 downto 0);
	 		i_Dq : in std_logic_vector(3 downto 0);
	 		o_Dq : out std_logic_vector(3 downto 0);
	 		Ba : in std_ulogic_vector(1 downto 0);
	 		Addr : in std_ulogic_vector(12 downto 0)
	 	); 
end mt48lc64m4a2;

architecture rtl of mt48lc64m4a2 is
	constant memsizes : natural :=65536;
	--constant memsizes : natural := 16777215;
	type t_bank is array (0 to memsizes) of std_ulogic_vector(3 downto 0);
	signal Bank0, Bank1, Bank2, Bank3 : t_bank;

	signal row_col_concat : unsigned(23 downto 0);

	--bank address pipeline
	type t_bank_addr_pipe is array (0 to 3) of std_ulogic_vector(1 downto 0);
	signal Bank_addr : t_bank_addr_pipe;
	--col address pipeline
	type t_col_addr_pipe is array(0 to 3) of std_ulogic_vector(10 downto 0);
	signal Col_addr : t_col_addr_pipe;
	--command operation pipeline
	type t_cmd_pipe is array(0 to 3) of std_ulogic_vector(3 downto 0);
	signal Command : t_cmd_pipe;
	--dqm operation pipeline
	signal Dqm_reg0, Dqm_reg1 : std_ulogic;
	signal B0_row_addr, B1_row_addr, B2_row_addr, B3_row_addr : std_ulogic_vector(12 downto 0);

   	signal Mode_reg : std_ulogic_vector(12 downto 0);
    signal Dq_reg, Dq_dqm : std_ulogic_vector(3 downto 0);
    signal Col_temp, Burst_counter : unsigned(10 downto 0);

    signal Act_b0, Act_b1, Act_b2, Act_b3 : std_ulogic := '1';   -- Bank Activate
    signal Pc_b0, Pc_b1, Pc_b2, Pc_b3 : std_ulogic := '0';       -- Bank Precharge

    type t_bank_prechange_pipe is array(0 to 3) of std_ulogic_vector(1 downto 0);
    signal Bank_precharge : t_bank_prechange_pipe;				-- Precharge Command
    type t_A10_pipe is array(0 to 3) of std_ulogic;
    signal A10_precharge : t_A10_pipe;							-- Addr[10] = 1 (All banks)

    type t_pre_pipe is array(0 to 3) of std_ulogic;
    signal Auto_precharge : t_pre_pipe;							-- RW Auto Precharge (Bank)

    type t_read_pre_pipe is array(0 to 3) of std_ulogic;
    signal Read_precharge : t_read_pre_pipe;					-- R  Auto Precharge

    type t_write_pre_pipe is array(0 to 3) of std_ulogic;
    signal Write_precharge : t_write_pre_pipe;					--  W Auto Precharge

    type t_dq_pipe is array(0 to 1) of std_ulogic_vector(3 downto 0);
    signal dq_pipe : t_dq_pipe;
 
    --type t_rw_pre_pipe is array(0 to 3) of std_ulogic;
    --signal RW_interrupt_read : t_rw_pre_pipe;					-- RW Interrupt Read with Auto Precharge

    --type t_rw_inter_write_pipe is array(0 to 3) of std_ulogic;
    --signal RW_interrupt_write : t_rw_inter_write_pipe;			-- RW Interrupt Write with Auto Precharge


    --signal                   [1 : 0] RW_interrupt_bank;                -- RW Interrupt Bank
    --integer                       RW_interrupt_counter [0 : 3];     -- RW Interrupt Counter

    type t_cnt_pre_pipe is array(0 to 3) of integer;
    signal Count_precharge : t_cnt_pre_pipe;						-- RW Auto Precharge Counter	
    signal Data_in_enable : std_ulogic := '0';
    signal Data_out_enable : std_ulogic :='0';

    signal Bank, Prev_bank : std_ulogic_vector(1 downto 0);
    signal Row : std_ulogic_vector(12 downto 0);
    signal Col,Col_brst : std_ulogic_vector(10 downto 0);

    signal Active_enable   : std_ulogic;
    signal Aref_enable     : std_ulogic;
    signal Burst_term      : std_ulogic;
    signal Mode_reg_enable : std_ulogic;
    signal Prech_enable    : std_ulogic;
    signal Read_enable     : std_ulogic;
    signal Write_enable    : std_ulogic;

	signal Burst_length_1 : std_ulogic;
	signal Burst_length_2 : std_ulogic;
	signal Burst_length_4 : std_ulogic;
	signal Burst_length_8 : std_ulogic;
	signal Burst_length_f : std_ulogic;

	signal Cas_latency_2 : std_ulogic;
	signal Cas_latency_3 : std_ulogic;

	signal Write_burst_mode : std_ulogic;

    -- Commands Operation
    constant   cmd_ACT   : natural     := 0;
    constant   cmd_NOP   : natural     := 1;
    constant   cmd_READ   : natural    := 2;
    constant   cmd_WRITE   : natural   := 3;
    constant   cmd_PRECH   : natural   := 4;
    constant   cmd_A_REF   : natural   := 5;
    constant   cmd_BST   : natural     := 6;
    constant   cmd_LMR   : natural     := 7;

    --Timing Parameters for -7E PC133 CL2
    constant tAC  : time :=   5.4 ns;
    constant tHZ  : time :=   5.4 ns;
    constant tOH  : time :=   3.0 ns;
    constant tMRD : time :=   20.0 ns;     --2 Clk Cycles
    constant tRAS : time :=  37.0 ns;
    constant tRC  : time :=  60.0 ns;
    constant tRCD : time :=  15.0 ns;
    constant tRFC : time :=  66.0 ns;
    constant tRP  : time :=  15.0 ns;
    constant tRRD : time :=  14.0 ns;
    constant tWRa : time :=   7.0 ns;     --A2 Version - Auto precharge mode (1 Clk + 7 ns)
    constant tWRm : time :=  14.0 ns;     --A2 Version - Manual precharge mode (14 ns)
begin
	row_col_concat <= unsigned(Row) & unsigned(Col);

	o_Dq <= Dq_reg;
	--Dq <= Dq_reg;

    -- Commands Decode
    Active_enable    <= not(Cs_n) and  not(Ras_n) and  Cas_n 	  and  We_n;
    Aref_enable      <= not(Cs_n) and  not(Ras_n) and  not(Cas_n) and  We_n;
    Burst_term       <= not(Cs_n) and  Ras_n      and  Cas_n 	  and not(We_n);
    Mode_reg_enable  <= not(Cs_n) and  not(Ras_n) and  not(Cas_n) and not(We_n);
    Prech_enable     <= not(Cs_n) and  not(Ras_n) and  Cas_n 	  and not(We_n);
    Read_enable      <= not(Cs_n) and  Ras_n      and  not(Cas_n) and  We_n;
    Write_enable     <= not(Cs_n) and  Ras_n      and  not(Cas_n) and not(We_n);

    -- Burst Length Decode
    Burst_length_1   <= not(Mode_reg(2)) and not(Mode_reg(1)) and not(Mode_reg(0));
    Burst_length_2   <= not(Mode_reg(2)) and not(Mode_reg(1)) and  Mode_reg(0);
    Burst_length_4   <= not(Mode_reg(2)) and  Mode_reg(1) 	  and not(Mode_reg(0));
    Burst_length_8   <= not(Mode_reg(2)) and  Mode_reg(1) 	  and  Mode_reg(0);
    Burst_length_f   <= Mode_reg(2) 	 and  Mode_reg(1) 	  and  Mode_reg(0);

    -- CAS Latency Decode
    Cas_latency_2    <= not(Mode_reg(6)) and  Mode_reg(5) and not(Mode_reg(4));
    Cas_latency_3    <= not(Mode_reg(6)) and  Mode_reg(5) and  Mode_reg(4);

    -- Write Burst Mode
    Write_burst_mode <= Mode_reg(9);
 

	process(i_clk) is
    begin
    	if(rising_edge(i_clk)) then
    		dq_pipe(0) <= dq_pipe(1);
    		dq_pipe(1) <= i_Dq;

	        -- Internal Commamd Pipelined
	        Command(0) <= Command(1);
	        Command(1) <= Command(2);
	        Command(2) <= Command(3);
	        Command(3) <= std_ulogic_vector(to_unsigned(cmd_NOP,4));	--??????????????

	        Col_addr(0) <= Col_addr(1);
	        Col_addr(1) <= Col_addr(2);
	        Col_addr(2) <= Col_addr(3);
	        Col_addr(3) <= (others => '0');

	        Bank_addr(0) <= Bank_addr(1);
	        Bank_addr(1) <= Bank_addr(2);
	        Bank_addr(2) <= Bank_addr(3);
	        Bank_addr(3) <= "00";

	        Bank_precharge(0) <= Bank_precharge(1);
	        Bank_precharge(1) <= Bank_precharge(2);
	        Bank_precharge(2) <= Bank_precharge(3);
	        Bank_precharge(3) <= "00";

	        A10_precharge(0) <= A10_precharge(1);
	        A10_precharge(1) <= A10_precharge(2);
	        A10_precharge(2) <= A10_precharge(3);
	        A10_precharge(3) <= '0';

	        -- Dqm pipeline for Read
	        Dqm_reg0 <= Dqm_reg1;
	        Dqm_reg1 <= Dqm;

            -- Read or Write with Auto Precharge Counter
	        if (Auto_precharge(0) = '1') then
	            Count_precharge(0) <= Count_precharge(0) + 1;
	        end if;
	        if (Auto_precharge(1) = '1') then
	            Count_precharge(1) <= Count_precharge(1) + 1;
	        end if;
	        if (Auto_precharge(2) = '1') then
	            Count_precharge(2) <= Count_precharge(2) + 1;
	        end if;
	        if (Auto_precharge(3) = '1') then
	            Count_precharge(3) <= Count_precharge(3) + 1;
	        end if;

	        ---- Read or Write Interrupt Counter
	        --if (RW_interrupt_write(0) = '1') then
	        --    RW_interrupt_counter(0) <= RW_interrupt_counter(0) + 1;
	        --end if;
	        --if (RW_interrupt_write(1) = '1') then
	        --    RW_interrupt_counter(1) <= RW_interrupt_counter(1) + 1;
	        --end if;
	        --if (RW_interrupt_write(2) = '1') then
	        --    RW_interrupt_counter(2) <= RW_interrupt_counter(2) + 1;
	        --end if;
	        --if (RW_interrupt_write(3) = '1') then
	        --    RW_interrupt_counter(3) <= RW_interrupt_counter(3) + 1;
	        --end if;

	        -- tMRD Counter
	        --MRD_chk <= MRD_chk + 1;
            if (Mode_reg_enable = '1') then
            	-- Register Mode
            	Mode_reg <= Addr;
            	--MRD_chk <= 0;
            end if;

            --Active Block (Latch Bank Address and Row Address)
        	if (Active_enable = '1') then
        		--Activate Bank 0
	            if (Ba = "00" and Pc_b0 = '1') then
	                -- Record variables
	                Act_b0 <= '1';
	                Pc_b0 <= '0';
	                B0_row_addr <= Addr(12 downto 0);
	            end if;

	            if (Ba = "01" and Pc_b1 = '1') then
	                -- Record variables
	                Act_b1 <= '1';
	                Pc_b1 <= '0';
	                B1_row_addr <= Addr(12 downto 0);
	            end if;

	            if (Ba = "10" and Pc_b2 = '1') then
	                -- Record variables
	                Act_b2 <= '1';
	                Pc_b2 <= '0';
	                B2_row_addr <= Addr(12 downto 0);
	            end if;

	            if (Ba = "11" and Pc_b3 = '1') then
	                -- Record variables
	                Act_b3 <= '1';
	                Pc_b3 <= '0';
	                B3_row_addr <= Addr(12 downto 0);
	            end if;

	            Prev_bank <= Ba;
        	end if;

	       	--Precharge Block
        	if (Prech_enable = '1') then
	            --Precharge Bank 0 (either specifically this bank, or as part of prech. all banks)
	            if ((Addr(10) = '1' or (Addr(10) = '0' and Ba = "00")) and Act_b0 = '1') then
	                Act_b0 <= '0';
	                Pc_b0 <= '1';
	            end if;

	            --Precharge Bank 1
	            if ((Addr(10) = '1' or (Addr(10) = '0' and Ba = "01")) and Act_b0 = '1') then
	                Act_b1 <= '0';
	                Pc_b1 <= '1';
	            end if;

	            --Precharge Bank 2
	            if ((Addr(10) = '1' or (Addr(10) = '0' and Ba = "10")) and Act_b0 = '1') then
	                Act_b2 <= '0';
	                Pc_b2 <= '1';
	            end if;

	            --Precharge Bank 3
	            if ((Addr(10) = '1' or (Addr(10) = '0' and Ba = "11")) and Act_b0 = '1') then
	                Act_b3 <= '0';
	                Pc_b3 <= '1';
	            end if;

	            --Terminate a Write Immediately (if same bank or all banks)
	            if (Data_in_enable = '1' and (Bank = Ba or Addr(10) = '1')) then
	                Data_in_enable <= '0';
	            end if;

	            --Precharge Command Pipeline for Read
	            if (Cas_latency_3 = '1') then
	                Command(2) <= std_ulogic_vector(to_unsigned(cmd_PRECH,4));
	                Bank_precharge(2) <= Ba;
	                A10_precharge(2) <= Addr(10);
	            elsif (Cas_latency_2 = '1') then
	                Command(1) <= std_ulogic_vector(to_unsigned(cmd_PRECH,4));
	                Bank_precharge(1) <= Ba;
	                A10_precharge(1) <= Addr(10);
	            end if;
        	end if;

        	--Burst terminate
        	if (Burst_term = '1') then
            	--Terminate a Write Immediately
	            if (Data_in_enable = '1') then
	                Data_in_enable <= '0';
	            end if;	

	            --Terminate a Read Depend on CAS Latency
	            if (Cas_latency_3 = '1') then
	                Command(2) <= std_ulogic_vector(to_unsigned(cmd_BST,4));
	            elsif (Cas_latency_2 = '1') then
	                Command(1) <= std_ulogic_vector(to_unsigned(cmd_BST,4));
	            end if;
        	end if;


	        --Read, Write, Column Latch
        	if (Read_enable = '1') then
	            --CAS Latency pipeline
	            if (Cas_latency_3 = '1') then
	                Command(2) <= std_ulogic_vector(to_unsigned(cmd_READ,4));
	                Col_addr(2) <= Addr(11) & Addr(9 downto 0);
	                Bank_addr(2) <= Ba;
	            elsif (Cas_latency_2 = '1') then
	                Command(1) <= std_ulogic_vector(to_unsigned(cmd_READ,4));
	                Col_addr(1) <= Addr(11) & Addr(9 downto 0);
	                Bank_addr(1) <= Ba;
	            end if;

            	--Read interrupt Write (terminate Write immediately)
            	if (Data_in_enable = '1') then
                	Data_in_enable <= '0';
         		end if;

 	            --Read with Auto Precharge
	            if (Addr(10) = '1') then
	                Auto_precharge(to_integer(unsigned(Ba))) <= '1';
	                Count_precharge(to_integer(unsigned(Ba))) <= 0;
	                --RW_interrupt_bank <= Ba;
	                Read_precharge(to_integer(unsigned(Ba))) <= '1';
	            end if;
    		end if;

        	--Write Command
       		if (Write_enable = '1') then
	            --Latch Write command, Bank, and Column
	            Command(0) <= std_ulogic_vector(to_unsigned(cmd_WRITE,4));
	            Col_addr(0) <= Addr(11) & Addr(9 downto 0);
	            Bank_addr(0) <= Ba;

	            --Write interrupt Write (terminate Write immediately)
	            if (Data_in_enable = '1') then
	                Data_in_enable <= '0';
	            end if;

            	--Write interrupt Read (terminate Read immediately)
            	if (Data_out_enable = '1') then
                	Data_out_enable <= '0';
                end if;

                --Write with Auto Precharge
	            if (Addr(10) = '1') then
	                Auto_precharge(to_integer(unsigned(Ba))) <= '1';
	                Count_precharge(to_integer(unsigned(Ba))) <= 0;
	                --RW_interrupt_bank <= Ba;
	                Write_precharge(to_integer(unsigned(Ba))) <= '1';
	            end if;
       		end if;

         	if ((Auto_precharge(0) = '1') and (Write_precharge(0) = '1')) then
	            if (Count_precharge (0) >= 8) then               
	                    Auto_precharge(0) <= '0';
	                    Write_precharge(0) <= '0';
	                    --RW_interrupt_write(0) <= '0';
	                    Pc_b0 <= '1';
	                    Act_b0 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(1) = '1') and (Write_precharge(1) = '1')) then
	            if (Count_precharge (1) >= 8) then               
	                    Auto_precharge(1) <= '0';
	                    Write_precharge(1) <= '0';
	                    --RW_interrupt_write(1) <= '0';
	                    Pc_b1 <= '1';
	                    Act_b1 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(2) = '1') and (Write_precharge(2) = '1')) then
	            if (Count_precharge (2) >= 8) then               
	                    Auto_precharge(2) <= '0';
	                    Write_precharge(2) <= '0';
	                    --RW_interrupt_write(2) <= '0';
	                    Pc_b2 <= '1';
	                    Act_b2 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(3) = '1') and (Write_precharge(3) = '1')) then
	            if (Count_precharge (3) >= 8) then               
	                    Auto_precharge(3) <= '0';
	                    Write_precharge(3) <= '0';
	                    --RW_interrupt_write(3) <= '0';
	                    Pc_b3 <= '1';
	                    Act_b3 <= '0';
	                end if;
           end if;


         	if ((Auto_precharge(0) = '1') and (Read_precharge(0) = '1')) then
	            if (Count_precharge (0) >= 8) then               
	                    Auto_precharge(0) <= '0';
	                    Read_precharge(0) <= '0';
	                    --RW_interrupt_write(0) <= '0';
	                    Pc_b0 <= '1';
	                    Act_b0 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(1) = '1') and (Read_precharge(1) = '1')) then
	            if (Count_precharge (1) >= 8) then               
	                    Auto_precharge(1) <= '0';
	                    Read_precharge(1) <= '0';
	                    --RW_interrupt_write(1) <= '0';
	                    Pc_b1 <= '1';
	                    Act_b1 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(2) = '1') and (Read_precharge(2) = '1')) then
	            if (Count_precharge (2) >= 8) then               
	                    Auto_precharge(2) <= '0';
	                    Read_precharge(2) <= '0';
	                    --RW_interrupt_write(2) <= '0';
	                    Pc_b2 <= '1';
	                    Act_b2 <= '0';
	                end if;
           end if;

         	if ((Auto_precharge(3) = '1') and (Read_precharge(3) = '1')) then
	            if (Count_precharge (3) >= 8) then               
	                    Auto_precharge(3) <= '0';
	                    Read_precharge(3) <= '0';
	                    --RW_interrupt_write(3) <= '0';
	                    Pc_b3 <= '1';
	                    Act_b3 <= '0';
	                end if;
           end if;

        	--Internal Precharge or Bst
        	if (unsigned(Command(0)) = cmd_PRECH) then    --Precharge terminate a read with same bank or all banks
	            if (Bank_precharge(0) = Bank or A10_precharge(0) = '1') then
	                if (Data_out_enable = '1') then
	                    Data_out_enable <= '0';
	                end if;
	            end if;
        	elsif (unsigned(Command(0)) = cmd_BST) then                  --BST terminate a read to current bank
	            if (Data_out_enable = '1') then
	                Data_out_enable <= '0';
	            end if;
        	end if;

	        if (Data_out_enable = '0') then
        	    Dq_reg <= (others => 'Z') AFTER tOH;
    	    end if;

	        --Detect Read or Write command
	        if (unsigned(Command(0)) = cmd_READ) THEN
	            Bank <= Bank_addr(0);
	            Col <= Col_addr(0);
	            Col_brst <= Col_addr(0);
	            case (Bank_addr(0)) is
	                when "00" => Row <= B0_row_addr;
	                when "01" => Row <= B1_row_addr;
	                when "10" => Row <= B2_row_addr;
	                when others => Row <= B3_row_addr;
	            end case;
	            Burst_counter <= (others => '0');
	            Data_in_enable <= '0';
	            Data_out_enable <= '1';
	        elsif (unsigned(Command(0)) = cmd_WRITE) THEN
	            Bank <= Bank_addr(0);
	            Col <= Col_addr(0);
	            Col_brst <= Col_addr(0);
	            case (Bank_addr(0)) is
	                when "00" => Row <= B0_row_addr;
	                when "01" => Row <= B1_row_addr;
	                when "10" => Row <= B2_row_addr;
	                when others => Row <= B3_row_addr;
	            end case;
	            Burst_counter <= (others => '0');
	            Data_in_enable <= '1';
	            Data_out_enable <= '0';
	        end if;

            --DQ buffer (Driver/Receiver)
            --if(Write_enable = '1') then
	        if (Data_in_enable = '1') then              --Writing Data to Memory
	            if (Dqm = '0') then
	                case (Bank) is
	                    when "00" => Bank0 (to_integer(row_col_concat)) <= dq_pipe(0);
	                    when "01" => Bank1 (to_integer(row_col_concat)) <= dq_pipe(0);
	                    when "10" => Bank2 (to_integer(row_col_concat)) <= dq_pipe(0);
	                    when others => Bank3 (to_integer(row_col_concat)) <= dq_pipe(0);
	                end case;
	            end if;
	            --burst decode
                --Advance Burst Counter
            	Burst_counter <= Burst_counter + 1;
        	 	--Col_temp <= unsigned(Col) + 1;				--sequential burst
        	 	Col <=  std_ulogic_vector(unsigned(Col) + 1);				--sequential burst
        	 	--Col (2 downto 0) <= std_ulogic_vector(Col_temp (2 downto 0)); 	-- burst length = 8

	            --Burst Read Single Write            
	            if (Write_burst_mode = '1') then
	                Data_in_enable <= '0';
	            end if;
                if (Burst_counter >= 8) then
                    Data_in_enable  <= '0';
                    Data_out_enable <= '0';
                end if;

            elsif (Data_out_enable = '1') then           --Reading Data from Memory
	            if (Dqm_reg0 = '0') then
	                case (Bank) is
	                    when "00" => Dq_reg <= Bank0 (to_integer(row_col_concat)) after tAC;
	                    when "01" => Dq_reg <= Bank1 (to_integer(row_col_concat)) after tAC;
	                    when "10" => Dq_reg <= Bank2 (to_integer(row_col_concat)) after tAC;
	                    when others => Dq_reg <= Bank3 (to_integer(row_col_concat)) after tAC;
	                end case;
	            else
	            	Dq_reg <= (others => 'Z') after tHZ;
	            end if;
	            --burst decode
                --Advance Burst Counter
            	Burst_counter <= Burst_counter + 1;
            	Col <= std_ulogic_vector(unsigned(Col) + 1);				--sequential burst
        	 	--Col_temp <= unsigned(Col) + 1;				--sequential burst
        	 	--Col (2 downto 0) <= std_ulogic_vector(Col_temp (2 downto 0)); 	-- burst length = 8

	            --Burst Read Single Write            
	            if (Write_burst_mode = '1') then
	                Data_in_enable <= '0';
	            end if;
                if (Burst_counter >= 8) then
                    Data_in_enable  <= '0';
                    Data_out_enable <= '0';
                end if;

	        end if;
    	end if;
    end process;
end rtl;