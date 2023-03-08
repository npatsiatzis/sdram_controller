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
	dut.i_W_n.value = 0
	dut.i_ads_n.value = 1
	dut.i_addr.value = 0
	await ClockCycles(dut.i_clk,cycles)
	dut.i_arst.value = 0
	await RisingEdge(dut.i_clk)
	dut._log.info("the core was reset")

@cocotb.test()
async def test(dut):
	"""Check results and coverage for SDR SDRAM controller"""

	cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())
	await reset(dut,5)	

	
	await RisingEdge(dut.o_init_done)
	
	while (full != True):
		data = random.randint(0,511)
		while(data in covered_valued):
			data = random.randint(0,511)

		dut.i_ads_n.value = 0
		dut.i_W_n.value = 0
		dut.i_data.value = data
		dut.i_addr.value = 0

		await FallingEdge(dut.o_tip)


		dut.i_ads_n.value = 1

		await ClockCycles(dut.i_clk,10)

		dut.i_ads_n.value = 0
		dut.i_W_n.value = 1
		# dut.i_data.value = 100
		dut.i_addr.value = 0

		await FallingEdge(dut.o_tip)
		# await FallingEdge(dut.o_data_valid)
		await RisingEdge(dut.i_clk)
		dut.i_ads_n.value = 1
		number_cover(dut)
		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"
		coverage_db["top.o_data"].add_threshold_callback(notify, 100)
		await ClockCycles(dut.i_clk,100)

	# coverage_db.report_coverage(cocotb.log.info,bins=True)
	coverage_db.export_to_xml(filename="coverage.xml")


