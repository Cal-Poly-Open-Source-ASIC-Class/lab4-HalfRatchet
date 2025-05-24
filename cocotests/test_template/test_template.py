
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

# Reset function
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.we.value = 0
    dut.re.value = 0
    dut.wdata.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1


# Write data into FIFO
async def write_fifo(dut, data_list, pause_chance=0.0):
    for data in data_list:
        if dut.full.value:
            await RisingEdge(dut.clk_w)
        else:
            dut.we.value = 1
            dut.wdata.value = data
            await RisingEdge(dut.clk_w)

    dut.we.value = 0

#  Read data from FIFO
async def read_fifo(dut, expected_data, pause_chance=0.0):
    for expected in expected_data:
        while dut.empty.value:
            await RisingEdge(dut.clk_r)

        dut.re.value = 1
        await RisingEdge(dut.clk_r)
        read_val = dut.rdata.value.integer

    dut.re.value = 0

@cocotb.test()
async def async_fifo_test(dut):

    # Start clocks
    cocotb.start_soon(Clock(dut.clk_w, 13, units='ns').start())  
    cocotb.start_soon(Clock(dut.clk_r, 7, units='ns').start())  

    await reset_dut(dut)

    # Test 1: Simultaneous read and write 
    test_data = [i for i in range(16)]
    writer = cocotb.start_soon(write_fifo(dut, test_data, pause_chance=0.2))
    reader = cocotb.start_soon(read_fifo(dut, test_data, pause_chance=0.1))


    await writer
    await reader
    await Timer(100, units='ns')

    # Test 2: Fill FIFO from write domain alone, then read out
    await reset_dut(dut)

    test_data2 = [random.randint(0, 255) for _ in range(8)]
    await write_fifo(dut, test_data2)
    await Timer(50, units='ns')
    await read_fifo(dut, test_data2) 
    

    await Timer(100, units='ns')

    # Test 3: Fill FIFO completely, then drain it slowly
    await reset_dut(dut)

    test_data3 = [random.randint(0, 255) for _ in range(16)]
    await write_fifo(dut, test_data3)
    await read_fifo(dut, test_data3, pause_chance=0.4)

    dut._log.info("All async FIFO tests passed!")