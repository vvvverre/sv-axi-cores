import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
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
async def run_test_read(dut, n_reads = 200, data_generator=None, idle_generator=None, backpressure_generator=None):
    global rng

    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)

    data_generator = data_generator or (lambda x: np.full(x, 10))
    
    dut._log.info(f"param AXI_DATA_WIDTH = {dut.AXI_DATA_WIDTH.value}")
    dut._log.info(f"param AXI_ADDR_WIDTH = {dut.AXI_ADDR_WIDTH.value}")

    bram_size = 2**(dut.AXI_ADDR_WIDTH.value-2)
    bram_data = data_generator(bram_size)
    tb.bram.set_contents(dict(zip(range(bram_size), map(int, bram_data))))

    addrs = list(map(int, rng.choice(bram_size, size=n_reads, replace=False)))

    await tb.reset()

    for addr in addrs:
        response = await tb.axil_master.read(addr*4, 4)
        assert int.from_bytes(response.data, 'little', signed=False) == bram_data[addr]

    for _ in range(100):
        await RisingEdge(dut.aclk)

@cocotb.test()
async def run_test_write(dut, n_writes = 200, data_generator=None, idle_generator=None, backpressure_generator=None):
    global rng

    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)

    data_generator = data_generator or (lambda x: np.full(x, 10))
    
    dut._log.info(f"param AXI_DATA_WIDTH = {dut.AXI_DATA_WIDTH.value}")
    dut._log.info(f"param AXI_ADDR_WIDTH = {dut.AXI_ADDR_WIDTH.value}")

    bram_size = 2**(dut.AXI_ADDR_WIDTH.value-2)
    bram_data = data_generator(bram_size)
    addrs = list(map(int, rng.choice(bram_size, size=n_writes, replace=False)))
    contents = dict()

    await tb.reset()

    for addr in addrs:
        await tb.axil_master.write(addr*4, struct.pack("<I", bram_data[addr]))
        contents[addr] = bram_data[addr]

    tb.bram.verify(contents)

    for _ in range(100):
        await RisingEdge(dut.aclk)

@cocotb.test()
async def run_test_mixed(dut, nworkers=16):
    global rng

    tb = TB(dut)
    
    dut._log.info(f"param AXI_DATA_WIDTH = {dut.AXI_DATA_WIDTH.value}")
    dut._log.info(f"param AXI_ADDR_WIDTH = {dut.AXI_ADDR_WIDTH.value}")

    bram_size = 2**(dut.AXI_ADDR_WIDTH.value-2)

    async def worker(master, offset, aperture, seed, count=16):
        worker_rng = np.random.default_rng(seed)
        lengths = worker_rng.integers(1, min(32, aperture), count, endpoint=True)
        for length in lengths:
            data = worker_rng.integers(0, 256, length)
            test_data = bytearray(map(int, data))
            addr = int(offset + worker_rng.integers(0, aperture-length, 1)[0])

            delay = int(worker_rng.integers(1, 100, 1)[0])
            await Timer(delay, 'ns')

            await master.write(addr, test_data)

            delay = int(worker_rng.integers(1, 100, 1)[0])
            await Timer(delay, 'ns')

            response = await master.read(addr, length)

            assert response.data == test_data

    aperture = bram_size // nworkers
    offsets = np.arange(nworkers) * aperture
    seeds = rng.integers(2*32, size=nworkers)

    workers = list()
    for offset, seed in zip(offsets, seeds):
        workers.append(cocotb.fork(worker(tb.axil_master, offset, aperture, seed, count=32)))

    while workers:
        await workers.pop(0).join()

    for _ in range(100):
        await RisingEdge(dut.aclk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test_read)
    factory.add_option("data_generator", [block_data_linear, block_data_random])
    factory.add_option("idle_generator", [None, cycle_pause, random_pause])
    factory.add_option("backpressure_generator", [None, cycle_pause, random_pause])
    factory.generate_tests()

    factory = TestFactory(run_test_write)
    factory.add_option("data_generator", [block_data_linear, block_data_random])
    factory.add_option("idle_generator", [None, cycle_pause, random_pause])
    factory.add_option("backpressure_generator", [None, cycle_pause, random_pause])
    factory.generate_tests()


rng = np.random.default_rng(12345)


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
root_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..'))


@pytest.mark.parametrize("axi_addr_width", [12, 16])
def test_axis_bram_interface(request, axi_addr_width):
    dut = "axi_bram_interface"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv")
    ]

    parameters = dict()
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
