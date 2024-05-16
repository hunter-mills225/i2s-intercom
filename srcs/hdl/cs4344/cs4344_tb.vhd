---------------------------------------------------------------------------------------------------
--! @file     cs4344_tb.vhd
--! @author   Hunter Mills
--! @brief    Entity to drive CS4344 I2S
--! @details  Simple testbench for CS4344 DAC Driver : 2 Frames of AXI4-Stream Data
---------------------------------------------------------------------------------------------------
-- Standard Libraries

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;
  use ieee.math_real.all;

-- User Libraries
use work.all;

-- Entity
entity cs4344_tb is
end entity cs4344_tb;

-- Architecture
architecture behav of cs4344_tb is

  --------------------------------------------------------------------------------
  -- Device Under Test Interface Signals
  --------------------------------------------------------------------------------
  -- AXI4-Stream Inputs
  signal s_axis_resetn  : std_logic := '0';                      -- Synchronous axis reset (active low)
  signal s_axis_clk     : std_logic := '0'; 										  -- AXIS System Clock (125MHz)
  signal s_axis_tdata   : std_logic_vector(31 downto 0) := (others => '0');	-- 32 bit input data
  signal s_axis_tvalid  : std_logic := '0';
  signal s_axis_tready  : std_logic := '1';
  signal s_axis_tlast   : std_logic := '0';

  -- CS4344 PMOD Signals
	signal sdata         : std_logic;  									  -- Serial Data for I2S stream
  signal lrclk         : std_logic;  									  -- Left Right 48kHz Clk
  signal sclk          : std_logic;  									  -- Serial 3.125MHz Clk
  signal mclk          : std_logic;  									  -- Master 12.5MHz Clk

  --------------------------------------------------------------------------------
  -- Testbench
  --------------------------------------------------------------------------------
  -- Constants
  constant CLOCK_PERIOD              : time      := 8 ns;   -- 125MHz

  -- Signals
  signal   simulation_done           : boolean   := false;
  signal   clock                     : std_logic := '0';
  signal   resetn                    : std_logic := '1';

begin

  --------------------------------------------------------------------------------
  -- Device Under Test
  --------------------------------------------------------------------------------
  u_dut : entity cs4344
    port map (
      s_axis_resetn => s_axis_resetn,
      s_axis_clk    => s_axis_clk,
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
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
    -- First Frame
    -- --------------------------------------------------
    s_axis_tdata  <= x"00F0F0F0";
    s_axis_tvalid <= '1';
    wait for CLOCK_PERIOD;
    s_axis_tdata  <= x"000F0F0F";
    s_axis_tlast  <= '1';
    wait for CLOCK_PERIOD;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';
    wait until s_axis_tready = '1';
    wait for CLOCK_PERIOD * 100;
    simulation_done <= true;


  end process w_test_procedure;

end architecture behav;