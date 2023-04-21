from cocotb.triggers import FallingEdge,RisingEdge,ClockCycles
from cocotb_coverage import crv
from cocotb.clock import Clock
from pyuvm import *
import random
import cocotb
import pyuvm
from utils import AxilSdramBfm
from cocotb_coverage.coverage import CoverPoint,coverage_db

# g_sys_clk = int(cocotb.top.g_sys_clk)
# period_ns = 10**9 / g_sys_clk
# g_data_width = int(cocotb.top.g_data_width)
covered_values = []
covered_values_seq = []


full = False
def notify():
    global full
    full = True

# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered
# even if g_data_with is >8, do not exercize full range as it is extremelly comp. heavy
@CoverPoint("top.i_tx_data",xf = lambda x : x, bins = list(range(2**9)), at_least=1)
def number_cover(x):
    pass


class crv_inputs(crv.Randomized):
    def __init__(self,tx_addr,tx_data):
        crv.Randomized.__init__(self)
        self.tx_addr = tx_addr
        self.tx_data = tx_data
        self.add_rand("tx_addr",list(range(2**18-10)))
        self.add_rand("tx_data",list(range(2**9)))

# Sequence classes
class SeqItem(uvm_sequence_item):

    def __init__(self, name, i_addr,i_tx_data):
        super().__init__(name)
        self.i_crv = crv_inputs(i_addr,i_tx_data)

    def randomize_operands(self):
        self.i_crv.randomize()

    def randomize(self):
        self.randomize_operands()


class RandomSeq(uvm_sequence):
        
    async def body(self):
        while(len(covered_values) != 2**9):
            data_tr = SeqItem("data_tr", None, None)
            await self.start_item(data_tr)
            data_tr.randomize_operands()
            while(data_tr.i_crv.tx_data in covered_values):
                data_tr.randomize_operands()
            covered_values.append(data_tr.i_crv.tx_data)
            await self.finish_item(data_tr)


class TestAllSeq(uvm_sequence):

    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        random = RandomSeq("random")
        await random.start(seqr)


class Driver(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    def start_of_simulation_phase(self):
        self.bfm = AxilSdramBfm()

    async def launch_tb(self):
        await self.bfm.reset()
        self.bfm.start_bfm()

    async def run_phase(self):
        await self.launch_tb()
        while True:
            data = await self.seq_item_port.get_next_item()
            await self.bfm.send_data((1,1,1,data.i_crv.tx_data,1,0,0,0))
            await RisingEdge(self.bfm.dut.S_AXI_BVALID)
            await self.bfm.send_data((1,0,1,data.i_crv.tx_addr,1,0,0,0))
            await RisingEdge(self.bfm.dut.S_AXI_BVALID)
            await self.bfm.send_data((0,0,0,data.i_crv.tx_addr,1,0,0,0))


            # await self.bfm.send_data((1,0,0,data.i_crv.tx_addr))
            await RisingEdge(self.bfm.dut.o_tip)
            
            addr = (data.i_crv.tx_addr + 2**30)
            await self.bfm.send_data((1,0,1,addr,1,0,0,0))
            await RisingEdge(self.bfm.dut.S_AXI_BVALID)
            await self.bfm.send_data((0,0,0,addr,1,0,0,0))
            await RisingEdge(self.bfm.dut.o_wr_burst_done)
            # await RisingEdge(self.bfm.dut.o_wr_burst_done)
            # self.bfm.dut.i_ads_n.value = 1

            await ClockCycles(self.bfm.dut.S_AXI_ACLK,10)
            addr = (data.i_crv.tx_addr + 2**31)
            await self.bfm.send_data((1,0,1,addr,1,0,0,0))
            await RisingEdge(self.bfm.dut.S_AXI_BVALID)

            await self.bfm.send_data((0,0,0,addr,1,0,0,0))
            # await self.bfm.send_data((1,0,0,data.i_crv.tx_addr))
            await RisingEdge(self.bfm.dut.o_tip)

            addr = (data.i_crv.tx_addr + 2**31 + 2**30)
            await self.bfm.send_data((1,0,1,addr,1,0,0,0))
            await RisingEdge(self.bfm.dut.S_AXI_BVALID)
            await self.bfm.send_data((0,0,0,addr,1,0,0,0))
            # await RisingEdge(self.bfm.dut.S_AXI_BVALID)
            await RisingEdge(self.bfm.dut.o_rd_burst_done)

            await self.bfm.send_data((0,0,0,addr,1,1,2,1))
            await FallingEdge(self.bfm.dut.S_AXI_RVALID)
            await self.bfm.send_data((0,0,0,0,1,0,2,1))
            # await RisingEdge(self.bfm.dut.S_AXI_ACLK)

            # await self.bfm.send_data((1,0,data.i_crv.tx_addr,data.i_crv.tx_data))
            # await RisingEdge(self.bfm.dut.o_rd_burst_done)
            # self.bfm.dut.i_ads_n.value = 1
            # await RisingEdge(self.bfm.dut.S_AXI_ACLK)


            # await RisingEdge(self.bfm.dut.o_tx_ready)
            # await self.bfm.send_data((0,0))
            result = await self.bfm.get_result()
            self.ap.write(result)
            data.result = result
            self.seq_item_port.item_done()



class Coverage(uvm_subscriber):

    def end_of_elaboration_phase(self):
        self.cvg = set()

    def write(self, data):
        number_cover(data)
        if(int(data) not in self.cvg):
            self.cvg.add(int(data))

    def report_phase(self):
        try:
            disable_errors = ConfigDB().get(
                self, "", "DISABLE_COVERAGE_ERRORS")
        except UVMConfigItemNotFound:
            disable_errors = False
        if not disable_errors:
            # if (len(set(covered_values) - self.cvg) > 0):
            if len(self.cvg) != 2**9:
                self.logger.error(
                    f"Functional coverage error. Missed: {set(covered_values)-self.cvg}")   
                assert False
            else:
                self.logger.info("Covered all input space")
                assert True


class Scoreboard(uvm_component):

    def build_phase(self):
        self.data_fifo = uvm_tlm_analysis_fifo("data_fifo", self)
        self.result_fifo = uvm_tlm_analysis_fifo("result_fifo", self)
        self.data_get_port = uvm_get_port("data_get_port", self)
        self.result_get_port = uvm_get_port("result_get_port", self)
        self.data_export = self.data_fifo.analysis_export
        self.result_export = self.result_fifo.analysis_export

    def connect_phase(self):
        self.data_get_port.connect(self.data_fifo.get_export)
        self.result_get_port.connect(self.result_fifo.get_export)

    def check_phase(self):
        passed = True
        try:
            self.errors = ConfigDB().get(self, "", "CREATE_ERRORS")
        except UVMConfigItemNotFound:
            self.errors = False
        while self.result_get_port.can_get():
            _, actual_result = self.result_get_port.try_get()
            data_success, data = self.data_get_port.try_get()
            if not data_success:
                self.logger.critical(f"result {actual_result} had no command")
            else:
                if int(data) == int(actual_result):
                    self.logger.info("PASSED")
                    print("i_tx_data is {}, rx_data is {}".format(int(data),int(actual_result)))
                else:
                    self.logger.error("FAILED")
                    print("i_tx_data is {}, rx_data is {}".format(int(data),int(actual_result)))
                    passed = False
        assert passed


class Monitor(uvm_component):
    def __init__(self, name, parent, method_name):
        super().__init__(name, parent)
        self.method_name = method_name

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.bfm = AxilSdramBfm()
        self.get_method = getattr(self.bfm, self.method_name)

    async def run_phase(self):
        while True:
            datum = await self.get_method()
            self.logger.debug(f"MONITORED {datum}")
            self.ap.write(datum)


class Env(uvm_env):

    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        ConfigDB().set(None, "*", "SEQR", self.seqr)
        self.driver = Driver.create("driver", self)
        self.data_mon = Monitor("data_mon", self, "get_data")
        self.coverage = Coverage("coverage", self)
        self.scoreboard = Scoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        self.data_mon.ap.connect(self.scoreboard.data_export)
        self.data_mon.ap.connect(self.coverage.analysis_export)
        self.driver.ap.connect(self.scoreboard.result_export)

@pyuvm.test()
class Test(uvm_test):
    """Check results and coverage for SDR SDRAM controller with interleaved read/write bursts
    on the same location (bank, row, col)"""

    def build_phase(self):
        self.env = Env("env", self)
        self.bfm = AxilSdramBfm()

    def end_of_elaboration_phase(self):
        self.test_all = TestAllSeq.create("test_all")

    async def run_phase(self):
        self.raise_objection()
        cocotb.start_soon(Clock(self.bfm.dut.S_AXI_ACLK, 10, units="ns").start())
        await self.test_all.start()

        coverage_db.report_coverage(cocotb.log.info,bins=True)
        coverage_db.export_to_xml(filename="coverage.xml")
        self.drop_objection()
