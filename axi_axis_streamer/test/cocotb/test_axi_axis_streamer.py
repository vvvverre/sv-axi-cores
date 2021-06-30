import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiStreamSink, AxiStreamBus
from cocotbext.bram import BRAMInterface, SinglePortBRAM

import cocotb_test.simulator
import pytest

import logging
import itertools
import os.path
import numpy as np
import struct


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.fork(Clock(dut.aclk, 10, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.aclk, dut.aresetn, False)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.aclk, dut.aresetn, False)

        dut.enable <= 0
        dut.frame_length <= 0

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

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



def block_data_linear(frame_length, nbits=16):
    return (np.arange(frame_length) + 1) % 2**nbits

def block_data_random(frame_length, nbits=16):
    global rng
    low = 0
    high = 2**(nbits)
    return rng.integers(low = low, high = high, size = frame_length)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def random_pause(f = 0.5):
    global rng
    while True:
        yield int(rng.uniform() >= f)


@cocotb.test()
async def run_test(dut, data_generator=None, idle_generator=None, backpressure_generator=None):
    global rng

    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)

    data_generator = data_generator or (lambda x, y: np.full(x, 10))
    
    dut._log.info(f"param AXI_DATA_WIDTH = {dut.AXI_DATA_WIDTH.value}")
    dut._log.info(f"param AXI_ADDR_WIDTH = {dut.AXI_ADDR_WIDTH.value}")
    dut._log.info(f"param DATA_WIDTH = {dut.DATA_WIDTH.value}")

    data_width = dut.DATA_WIDTH.value
    bram_size = 2**(dut.AXI_ADDR_WIDTH.value-2)
    bram_data = data_generator(bram_size, data_width)
    

    await tb.reset()

    for addr in range(bram_size):
        await tb.axil_master.write(addr*4, struct.pack("<I", bram_data[addr]))
        await Timer(1, units="ns")
        assert dut.bram_inst.memory[addr].value == bram_data[addr]

    dut.enable <= 1
    await RisingEdge(dut.aclk)
    
    recv_frame = await with_timeout(cocotb.fork(tb.sink.recv()), 100, "us")
    assert np.all(recv_frame.tdata == bram_data)

    recv_frame = await with_timeout(cocotb.fork(tb.sink.recv()), 100, "us")
    assert np.all(recv_frame.tdata == bram_data)

    for _ in range(100):
        await RisingEdge(dut.aclk)



if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.add_option("data_generator", [block_data_linear, block_data_random])
    factory.add_option("idle_generator", [None, cycle_pause, random_pause])
    factory.add_option("backpressure_generator", [None, cycle_pause, random_pause])
    factory.generate_tests()


rng = np.random.default_rng(12345)


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
root_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..'))


@pytest.mark.parametrize("axi_addr_width", [12, 10])
@pytest.mark.parametrize("data_width", [16, 24])
def test_axi_axis_streamer(request, axi_addr_width, data_width):
    dut = "axi_axis_streamer"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(root_dir, "bram", "rtl", "bram.sv"),
        os.path.join(root_dir, "axi_bram_interface", "rtl", "axi_bram_interface.sv"),
        os.path.join(root_dir, "axis_bram_reader", "rtl", "axis_bram_reader.sv")
    ]

    parameters = dict()
    parameters["AXI_ADDR_WIDTH"] = axi_addr_width
    parameters["DATA_WIDTH"] = data_width

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
