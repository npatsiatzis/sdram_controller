
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles
from cocotb.clock import Clock
from cocotb.queue import QueueEmpty, Queue
import cocotb
import enum
import random
from cocotb_coverage import crv 
from cocotb_coverage.coverage import CoverCross,CoverPoint,coverage_db
from pyuvm import utility_classes



class SdramBfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue = Queue(maxsize=1)
        self.data_mon_queue = Queue(maxsize=0)
        self.result_mon_queue = Queue(maxsize=0)

    async def send_data(self, data):
        await self.driver_queue.put(data)

    async def get_data(self):
        data = await self.data_mon_queue.get()
        return data

    async def get_result(self):
        result = await self.result_mon_queue.get()
        return result

    async def reset(self):
        await RisingEdge(self.dut.i_clk)
        self.dut.i_arst.value = 1
        self.dut.i_W_n.value = 0
        self.dut.i_ads_n.value = 1
        self.dut.i_addr.value = 0
        self.dut.i_data.value = 0
        await ClockCycles(self.dut.i_clk,5)
        self.dut.i_arst.value = 0


    async def driver_bfm(self):
        # self.dut.i_tx_en.value = 0
        # self.dut.i_rx.value = 1
        # self.dut.i_tx_data.value = 0

        while True:
            await RisingEdge(self.dut.i_clk)
            # self.dut.i_miso.value = self.dut.o_mosi.value
            try:
                (i_W_n,i_ads_n,i_addr,i_data) = self.driver_queue.get_nowait()
                self.dut.i_W_n.value = i_W_n
                self.dut.i_ads_n.value = i_ads_n
                self.dut.i_addr.value = i_addr
                self.dut.i_data.value = i_data

            except QueueEmpty:
                pass

    async def data_mon_bfm(self):
        while True:
            await RisingEdge(self.dut.o_wr_burst_done)
            i_data = self.dut.i_data.value 
            self.data_mon_queue.put_nowait(i_data)


    async def result_mon_bfm(self):
        while True:
            await RisingEdge(self.dut.o_rd_burst_done)
            await RisingEdge(self.dut.i_clk)
            self.result_mon_queue.put_nowait(self.dut.o_data.value)


    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm())
        cocotb.start_soon(self.data_mon_bfm())
        cocotb.start_soon(self.result_mon_bfm())