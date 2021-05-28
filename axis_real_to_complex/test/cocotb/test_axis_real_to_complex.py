import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink

import cocotb_test.simulator
import pytest

import itertools
import os.path
import numpy as np


class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.fork(Clock(dut.aclk, 10, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.aclk, dut.aresetn, False)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.aclk, dut.aresetn, False, byte_lanes=2)

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


@cocotb.test()
async def run_test(dut, nblocks=1, frame_length=32, data_generator=None, idle_generator=None, backpressure_generator=None):
    tb = TB(dut)
    tb.set_idle_generator(idle_generator)
    tb.set_backpressure_generator(backpressure_generator)

    data_generator = data_generator or (lambda x: np.full(x, 10))
    
    await tb.reset()

    for nn in range(nblocks):
        frame_data = data_generator(frame_length)
        imag_data = [0] * frame_length
        expected_output = [val for pair in zip(frame_data, imag_data) for val in pair]

        test_frame = AxiStreamFrame(list(map(int, frame_data)))
        await tb.source.send(test_frame)

        recv_frame = await with_timeout(cocotb.fork(tb.sink.recv()), 10, 'us')

        for _ in range(100):
            await RisingEdge(dut.aclk)

        dut._log.info(f"RX Frame Data = {recv_frame.tdata}")

        recv_data = np.array(recv_frame.tdata)
        recv_data = ((recv_data & 0xFFFF) ^ 0x8000) - 0x8000

        assert len(recv_frame.tdata) == 2 * frame_length
        assert np.all(recv_data == expected_output)

def block_data_linear(frame_length):
    return np.arange(frame_length)

def block_data_random(frame_length, nbits=16):
    global rng
    low = -(2**(nbits-1))
    high = 2**(nbits-1)
    return rng.integers(low = low, high = high, size = frame_length)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def random_pause(f = 0.5):
    global rng
    while True:
        yield int(rng.uniform() >= f)

if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.add_option("frame_length", [64, 128])
    factory.add_option("data_generator", [block_data_linear, block_data_random])
    factory.add_option("idle_generator", [None, cycle_pause, random_pause])
    factory.add_option("backpressure_generator", [None, cycle_pause, random_pause])
    factory.generate_tests()

rng = np.random.default_rng(12345)


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
root_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..'))


@pytest.mark.parametrize("opt_register", [False, True])
@pytest.mark.parametrize("data_width", [16, 24, 32])
def test_axis_real_to_complex(request, data_width, opt_register):
    dut = "axis_real_to_complex"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(root_dir, "axis_skid_buffer", "rtl", "axis_skid_buffer.sv")
    ]

    parameters = dict()
    parameters["DATA_WIDTH"] = data_width
    parameters["OPT_REGISTER"] = int(opt_register)

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
