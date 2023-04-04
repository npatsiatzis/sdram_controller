import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles,ReadWrite
from cocotb.result import TestFailure
import random
from cocotb_coverage.coverage import CoverPoint,coverage_db

covered_valued = []


full = False
def notify():
	global full
	full = True


# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered
@CoverPoint("top.o_data",xf = lambda x : x.o_data.value, bins = list(range(512)), at_least=1)
def number_cover(dut):
	covered_valued.append(int(dut.o_data.value))

async def reset(dut,cycles=1):
	dut.i_arst.value = 1
	dut.i_we.value = 0
	dut.i_stb.value = 0
	# dut.i_W_n.value = 0
	# dut.i_ads_n.value = 1
	dut.i_addr.value = 0
	await ClockCycles(dut.i_clk,cycles)
	dut.i_arst.value = 0
	await RisingEdge(dut.i_clk)
	dut._log.info("the core was reset")

		# 					INTERFACE REGISTER MAP

	# 			Address 		| 		Functionality
	#			   0 			|	(SYS_DATA_WIDTH -1 downto SYS_DATA_WIDTH-2) => i_w_n, i_ads_n, (SYS_ADDR_WIDTH -1 downto 0) => sdram_address
	#			   1 			|	write data to tx
	#			   2 			|	data received from sdram

@cocotb.test()
async def test_consecutive(dut):
	"""Check results and coverage for SDR SDRAM controller with a succession of write burts first
	 and then a succession of read bursts to verify the transactions"""

	cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())
	await reset(dut,5)	

	data_lst = []
	addr_range_lst = []
	addr_lst = []

	
	await RisingEdge(dut.o_init_done)
	await ClockCycles(dut.i_clk,20)
	
	for i in range(512):
		data = random.randint(0,511)
		# sys addr : row addr    bank addr   col addr
		# row addr is 13 bits, reduced to 9 for the tests
		# col addr is 11 bits, reduced to 7 for the tests
		# bank addr is 2 bits
		# select values from range 0 ...2**18-1
		addr = random.randint(0,2**18-10)

		while (addr in addr_lst):
			addr = random.randint(0,2**18-10)
		while True:
			br = 0
			for i in addr_lst:
				if(abs(i-addr) <= 8):
					br = 1
			if(br == 0):
				break
			else:
				addr = random.randint(0,2**18-10)

		while(data in data_lst):
			data = random.randint(0,511)

		data_lst.append(data)
		addr_lst.append(addr)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 1
		dut.i_data.value = data
		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr  # W_n = 0 , ads_n = 0

		await RisingEdge(dut.i_clk)

		dut.i_stb.value = 0
	
		await RisingEdge(dut.o_tip)
		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**30  # W_n = 0 , ads_n = 1
		await RisingEdge(dut.i_clk)

		await RisingEdge(dut.o_wr_burst_done)

	await ClockCycles(dut.i_clk,20)

	for i in range(512):

		data = data_lst.pop(0)
		addr = addr_lst.pop(0)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**31  # W_n = 1 , ads_n = 0
		await RisingEdge(dut.i_clk)
		dut.i_stb.value = 0

		await RisingEdge(dut.o_tip)
		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**31 + 2**30  # W_n = 1 , ads_n = 1
		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.o_rd_burst_done)


		dut.i_we.value =0
		dut.i_stb.value = 1
		dut.i_addr.value = 2

		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.i_clk)

		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"


@cocotb.test()
async def test(dut):
	"""Check results and coverage for SDR SDRAM controller with interleaved read/write bursts
	on the same location (bank, row, col)"""

	cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())
	await reset(dut,5)	

	
	await RisingEdge(dut.o_init_done)
	
	while (full != True):
		data = random.randint(0,511)
		# sys addr : row addr    bank addr   col addr
		# row addr is 13 bits, reduced to 9 for the tests
		# col addr is 11 bits, reduced to 7 for the tests
		# bank addr is 2 bits
		# select values from range 0 ...2**18-1
		addr = random.randint(0,2**18-10) 
		while(data in covered_valued):
			data = random.randint(0,511)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 1
		dut.i_data.value = data
		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr  # W_n = 0 , ads_n = 0

		await RisingEdge(dut.i_clk)

		dut.i_stb.value = 0
	
		await RisingEdge(dut.o_tip)
		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**30  # W_n = 0 , ads_n = 1
		await RisingEdge(dut.i_clk)

		await RisingEdge(dut.o_wr_burst_done)


		# dut.i_ads_n.value = 1

		await ClockCycles(dut.i_clk,10)

		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**31  # W_n = 1 , ads_n = 0
		await RisingEdge(dut.i_clk)
		dut.i_stb.value = 0

		await RisingEdge(dut.o_tip)
		dut.i_we.value = 1
		dut.i_stb.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = addr + 2**31 + 2**30  # W_n = 1 , ads_n = 1
		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.o_rd_burst_done)


		dut.i_we.value =0
		dut.i_stb.value = 1
		dut.i_addr.value = 2

		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.i_clk)

		number_cover(dut)
		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"
		coverage_db["top.o_data"].add_threshold_callback(notify, 100)
		await ClockCycles(dut.i_clk,10)

	# coverage_db.report_coverage(cocotb.log.info,bins=True)
	coverage_db.export_to_xml(filename="coverage.xml")


