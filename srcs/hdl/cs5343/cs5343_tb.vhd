---------------------------------------------------------------------------------------------------
--! @file     cs5343_tb.vhd
--! @author   Hunter Mills
--! @brief    Entity to drive CS5343 I2S
--! @details  Simple testbench for CS5343 ADC Driver : 2 Frames of AXI4-Stream Data
---------------------------------------------------------------------------------------------------
-- Standard Libraries

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;
  use ieee.math_real.all;
  use std.env.finish;

-- User Libraries
use work.all;

-- Entity
entity cs5343_tb is
end entity cs5343_tb;

-- Architecture
architecture behav of cs5343_tb is

  --------------------------------------------------------------------------------
  -- Device Under Test Interface Signals
  --------------------------------------------------------------------------------
  -- AXI4-Stream Inputs
  signal s_axis_resetn  : std_logic := '0';                                 -- Synchronous axis reset (active low)
  signal s_axis_clk     : std_logic := '0'; 										            -- AXIS System Clock (125MHz)
  signal m_axis_clk     : std_logic; 										            -- AXIS System Clock (125MHz)
  signal m_axis_tdata   : std_logic_vector(31 downto 0) := (others => '0');	-- 32 bit input data
  signal m_axis_tvalid  : std_logic := '0';
  signal m_axis_tready  : std_logic := '1';

  -- CS5343 PMOD Signals
	signal sdata         : std_logic; -- Serial Data for I2S stream
  signal lrclk         : std_logic; -- Left Right 48kHz Clk
  signal sclk          : std_logic; -- Serial 3.125MHz Clk
  signal mclk          : std_logic; -- Master 12.5MHz Clk

  --------------------------------------------------------------------------------
  -- Testbench
  --------------------------------------------------------------------------------
  -- Constants
  constant CLOCK_PERIOD : time := 8 ns; -- 125MHz

  -- Signals
  signal   simulation_done  : boolean   := false;
  signal   clock            : std_logic := '0';
  signal   resetn           : std_logic := '1';

  -- Test Vector
  signal sdata_arr : std_logic_vector(63 downto 0) := x"a5f3aa005a3faa00";

begin

  --------------------------------------------------------------------------------
  -- Device Under Test
  --------------------------------------------------------------------------------
  u_dut : entity cs5343
    port map (
      s_axis_resetn => s_axis_resetn,
      s_axis_clk    => s_axis_clk,
      m_axis_clk    => m_axis_clk,
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      sdata         => sdata,
      lrclk         => lrclk,
      sclk          => sclk,
      mclk          => mclk
    );

  --------------------------------------------------------------------------------
  -- Clocks and Resets
  --------------------------------------------------------------------------------
  -- Waveform process to generate a clock
  w_clock : process is
  begin

    if (simulation_done = false) then
      clock <= '0';
      wait for CLOCK_PERIOD / 2;
      clock <= '1';
      wait for CLOCK_PERIOD / 2;
    else
      wait;
    end if;

  end process w_clock;

  -- Copy the clock and reset for the AXI4-Stream
  s_axis_clk    <= clock;
  s_axis_resetn <= resetn;

  --------------------------------------------------------------------------------
  -- Main Test Procedure
  --------------------------------------------------------------------------------
  w_test_procedure : process is

  begin

    -- --------------------------------------------------
    -- Reset
    -- --------------------------------------------------
    resetn                <= '0';
    wait for CLOCK_PERIOD * 20; -- Wait for an arbitrary 20 clocks
    resetn                <= '1';
    wait for CLOCK_PERIOD * 10;

    -- --------------------------------------------------
    -- Data frames
    -- --------------------------------------------------
    for I in 63 downto 0 loop
      report "Data Frames";
      sdata <= sdata_arr(I);
      wait until falling_edge(sclk);
    end loop;

    wait for CLOCK_PERIOD * 100;
    report "************ TB COMPLETE***************";
    simulation_done <= true;
    finish;

  end process w_test_procedure;

end architecture behav;