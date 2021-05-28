import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotbext.bram import BRAMInterface, SinglePortBRAM

import cocotb_test.simulator
import pytest

import logging
import itertools
import os.path
import numpy as np


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.fork(Clock(dut.aclk, 10, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.aclk, dut.aresetn, False)
        self.bram = SinglePortBRAM(BRAMInterface(dut))

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

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



def block_data_linear(frame_length):
    return (np.arange(frame_length) + 1)

def block_data_random(frame_length, nbits=16):
    global rng
    low = 0
    high = 2**(nbits)+1
    return rng.integers(low = low, high = high, size = frame_length)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def random_pause(f = 0.5):
    global rng
    while True:
        yield int(rng.uniform() >= f)


@cocotb.test()
async def run_test(dut, nblocks=1, data_generator=None, idle_generator=None, backpressure_generator=None):
    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)

    data_generator = data_generator or (lambda x: np.full(x, 10))
    
    dut._log.info(f"param AXI_DATA_WIDTH = {dut.AXI_DATA_WIDTH.value}")
    dut._log.info(f"param AXI_ADDR_WIDTH = {dut.AXI_ADDR_WIDTH.value}")

    frame_length = 2**(dut.ADDR_WIDTH.value)
    frame_data = data_generator(frame_length)
    contents = dict(zip(range(frame_length), map(int, frame_data)))
    tb.bram.set_contents(contents)

    dut.limit <= 0
    await tb.reset()

    #recv_frame = await tb.sink.recv()
    for nn in range(nblocks):
        recv_frame = await tb.sink.recv()
        
        assert np.all(recv_frame.tdata == frame_data)

    for _ in range(100):
        await RisingEdge(dut.aclk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()

rng = np.random.default_rng(12345)


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
root_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..'))


@pytest.mark.parametrize("axi_data_width", [16, 32])
@pytest.mark.parametrize("axi_addr_width", [8, 12])
def test_axis_bram_reader(request, axi_data_width, axi_addr_width):
    dut = "axi_bram_interface"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv")
    ]

    parameters = dict()
    parameters["AXI_DATA_WIDTH"] = axi_data_width
    parameters["AXI_ADDR_WIDTH"] = axi_addr_width

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
