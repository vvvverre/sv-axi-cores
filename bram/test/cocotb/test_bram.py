import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout, Timer
from cocotb.regression import TestFactory

import cocotb_test.simulator
import pytest

import logging
import itertools
import os.path
import numpy as np
import struct
import math


class TB:
    def __init__(self, dut, clka_period = 10, clkb_period = 10):
        self.dut = dut

        cocotb.fork(Clock(dut.clka, clka_period, units="ns").start())
        cocotb.fork(Clock(dut.clkb, clkb_period, units="ns").start())

        self.dut.ena <= 0
        self.dut.enb <= 0
        self.dut.rsta <= 0
        self.dut.rstb <= 0
        self.dut.addra <= 0
        self.dut.addrb <= 0
        self.dut.ina <= 0
        self.dut.inb <= 0
        self.dut.wea <= 0
        self.dut.web <= 0


def block_data_linear(frame_length, nbits=16):
    return (np.arange(frame_length) + 1) % 2**16

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

def mask_we(data, we, we_width):
    mask = 0
    for ii in range(we_width):
        if we & (1 << ii):
            mask |= 0xFF << (8*ii)
    
    return data & mask


@cocotb.test()
async def run_test_single_clock(dut, n_writes = 500, clock_periods = (10, 10), data_generator=None, we_generator=None):
    global rng

    tb = TB(dut, *clock_periods)

    data_generator = data_generator or (lambda x, y: np.full(x, 10))
    we_generator = we_generator or (lambda x, y: [2**y-1]*x)
    
    dut._log.info(f"param DATA_WIDTH = {dut.DATA_WIDTH.value}")
    dut._log.info(f"param ADDR_WIDTH = {dut.ADDR_WIDTH.value}")

    data_width = dut.DATA_WIDTH.value
    we_width = math.ceil(data_width/8)

    bram_size = 2**(dut.ADDR_WIDTH.value)
    bram_data = data_generator(n_writes, data_width)
    addrs = list(map(int, rng.integers(bram_size, size=n_writes)))
    we_list = we_generator(n_writes, we_width)
    writes = dict()

    for _ in range(10):
        await RisingEdge(dut.clka)

    dut.ena <= 1
    for addr, data, we in zip(addrs, bram_data, we_list):
        writes[addr] = (data, we)

        dut.addra <= addr
        dut.ina <= int(data)
        dut.wea <= int(we)

        dut._log.debug(f"Write 0x{data:08X} to {addr:d} (we = 0x{we:02X})")

        await RisingEdge(dut.clka)
        await Timer(1, units="ns")

        assert mask_we(dut.memory[addr].value, we, we_width) == mask_we(data, we, we_width)

    dut.wea <= 0
    dut.ena <= 0

    for _ in range(20):
        await RisingEdge(dut.clka)

    dut.ena <= 1
    for addr, write in writes.items():
        data, we = write
        dut._log.debug(f"Read from {addr:d}")

        dut.addra <= addr

        await RisingEdge(dut.clka)
        await Timer(1, units="ns")

        assert mask_we(dut.outa.value, we, we_width) == mask_we(data, we, we_width)

    dut.ena <= 0

    for _ in range(100):
        await RisingEdge(dut.clka)

if cocotb.SIM_NAME:

    factory = TestFactory(run_test_single_clock)
    factory.add_option("data_generator", [block_data_linear, block_data_random])
    factory.add_option("we_generator", [None, block_data_random])
    #factory.add_option("clock_periods", [(10, 10), (10, 7.5)])
    factory.generate_tests()


rng = np.random.default_rng(12345)


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
root_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..'))


@pytest.mark.parametrize("addr_width", [12, 16])
def test_bram(request, addr_width):
    dut = "bram"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv")
    ]

    parameters = dict()
    parameters["ADDR_WIDTH"] = addr_width

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
