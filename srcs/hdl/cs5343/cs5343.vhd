---------------------------------------------------------------------------------------------------
--! @file     cs5343.vhd
--! @author   Hunter Mills
--! @brief    Entity to drive CS5343 I2S
--! @details  CS5343 ADC Driver: 32b S/P Converter
---------------------------------------------------------------------------------------------------

-- Standard Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- User Libraries

--! Entity top_level
entity cs5343 is
  port(
    s_axis_resetn : in std_logic;                       -- Synchronous axis reset (active low)
    s_axis_clk    : in std_logic;                       -- AXIS System Clock (125MHz)
    m_axis_clk    : out std_logic;                      -- AXIS System Clock (125MHz)
    m_axis_tdata  : out std_logic_vector(31 downto 0);  -- 32 bit input data
    m_axis_tvalid : out std_logic;                      -- AXIS Valid Signal
    m_axis_tready : in std_logic;                       -- AXIS Ready Signal
    sdata         : in std_logic;                       -- Serial Data for I2S stream
    lrclk         : out std_logic;                      -- Left Right 48kHz Clk
    sclk          : out std_logic;                      -- Serial 3.125MHz Clk
    mclk          : out std_logic                       -- Master 12.5MHz Clk
  );
end cs5343;

--! Architecture
architecture behav of cs5343 is

  -- ------------------------------------------------
  -- Signals
  -- ------------------------------------------------
  --! Clock signals
  signal mclk_s   : std_logic;
  signal sclk_s   : std_logic;
  signal lrclk_s  : std_logic;
 
  --! Clock Counts
  signal mclk_125clk_count  : natural range 0 to 4    := 0;
  signal sclk_125clk_count  : natural range 0 to 19   := 0;
  signal lrclk_125clk_count : natural range 0 to 1279 := 0;
  signal frame_count        : unsigned(4 downto 0); --! SCLK per LRCLK Period

  --! Register Signals
  signal lrclk_reg  : std_logic;
  
  --! FIFO Signals
  signal fifo_tready  : std_logic;
  signal fifo_tvalid  : std_logic;
  signal fifo_tdata   : std_logic_vector(31 downto 0);
  signal audio_data   : std_logic_vector(31 downto 0);

begin

  -- ------------------------------------------------
  -- Clock Processes
  -- ------------------------------------------------
  --! Process to create MCLK
  mclk_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        mclk_125clk_count <= 0;
        mclk_s            <= '0';
      elsif mclk_125clk_count = 4 then
        mclk_125clk_count <= 0;
        mclk_s            <= not(mclk_s);
      else
        mclk_125clk_count <= mclk_125clk_count + 1;
      end if;
    end if;
  end process;

  --! Process to create SCLK
  sclk_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        sclk_125clk_count <= 0;
        sclk_s            <= '0';
        frame_count       <= "10111";
      elsif sclk_125clk_count = 19 then
        sclk_125clk_count <= 0;
        sclk_s            <= not(sclk_s);
        if sclk_s = '1' then --! Inc frame count on SCLK
          frame_count     <= frame_count - 1;
        end if;
      else
        sclk_125clk_count <= sclk_125clk_count + 1;
      end if;
    end if;
  end process;

  --! Process to create LRCLK
  lrclk_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        lrclk_125clk_count  <= 0;
        lrclk_s             <= '1';
      elsif lrclk_125clk_count = 1279 then
        lrclk_125clk_count  <= 0;
        lrclk_s             <= not(lrclk_s);
      else
      lrclk_125clk_count    <= lrclk_125clk_count + 1;
      end if;
    end if;
  end process;
  
  -- ------------------------------------------------
  -- Registers
  -- ------------------------------------------------
  --! RisingEdge Detector
  reg_axis_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        lrclk_reg   <= '0';
      else
        lrclk_reg   <= lrclk_s;
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Serial Data
  -- ------------------------------------------------
  --! Process to shift serial data into m_axis_tdata
  sdata_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        m_axis_tdata  <= (others => '0');
      elsif sclk_125clk_count = 19 then
        m_axis_tdata(to_integer(frame_count)) <= sdata;
      end if;
    end if;
  end process;

  --! Process to create AXIS valid
  valid_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        m_axis_tvalid <= '0';
      elsif frame_count = "11000" and sclk_125clk_count = 19 and sclk_s = '1' and m_axis_tready = '1' then
        m_axis_tvalid <= '1';
      else
        m_axis_tvalid <= '0';
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Signal Assignments
  -- ------------------------------------------------
  --! Clocks
  mclk  <= mclk_s;
  sclk  <= sclk_s;
  lrclk <= lrclk_s;

  --! AXIS
  m_axis_clk  <= s_axis_clk;

end behav;
