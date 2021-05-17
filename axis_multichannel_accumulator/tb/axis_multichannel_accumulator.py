import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink

import itertools
import numpy as np


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.fork(Clock(dut.aclk, 10, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.aclk, dut.aresetn, False)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.aclk, dut.aresetn, False)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.aresetn.setimmediatevalue(1)
        await RisingEdge(self.dut.aclk)
        await RisingEdge(self.dut.aclk)
        self.dut.aresetn <= 0
        await RisingEdge(self.dut.aclk)
        await RisingEdge(self.dut.aclk)
        self.dut.aresetn <= 1
        await RisingEdge(self.dut.aclk)
        await RisingEdge(self.dut.aclk)


#@cocotb.test()
async def run_test(dut, nblocks=1, rate=4, block_size=8, block_data_gen=None, idle_generator=None, backpressure_generator=None):
    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)
    dut.rate <= rate

    block_data_gen = block_data_gen or (lambda x, y: np.full((rate, block_size), 10))
    
    await tb.reset()

    for nn in range(nblocks):
        block_data = block_data_gen(block_size, rate)
        expected_output = np.sum(block_data, axis = 0)

        for ii in range(rate):
            test_frame = AxiStreamFrame(list(map(int, block_data[ii])))
            await tb.source.send(test_frame)

        recv_frame = await tb.sink.recv()

        for _ in range(100):
            await RisingEdge(dut.aclk)

        recv_data = np.array(recv_frame.tdata)
        recv_data = ((recv_data & 0xFFFFFF) ^ 0x800000) - 0x800000

        dut._log.info(f"RX Frame Length = {len(recv_frame.tdata)}")
        assert len(recv_frame.tdata) == block_size
        assert np.all(recv_data == expected_output)

def block_data_linear(block_size, rate):
    return np.arange(rate * block_size).reshape((rate, block_size))

def block_data_random(block_size, rate, nbits=16):
    global rng
    low = -(2**(nbits-1))
    high = 2**(nbits-1)
    return rng.integers(low = low, high = high, size = (rate, block_size))

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

rng = np.random.default_rng(12345)

factory = TestFactory(run_test)
# factory.add_option("rate", [16, 32])
# factory.add_option("block_size", [64, 128])
factory.add_option("block_data_gen", [block_data_linear, block_data_random])
# factory.add_option("nblocks", [1, 2, 5])
factory.add_option("idle_generator", [None, cycle_pause])
# factory.add_option("backpressure_generator", [None, cycle_pause])
factory.generate_tests()
