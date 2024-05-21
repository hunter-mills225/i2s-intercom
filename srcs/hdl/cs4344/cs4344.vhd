---------------------------------------------------------------------------------------------------
--! @file     cs4344.vhd
--! @author   Hunter Mills
--! @brief    Entity to drive CS4344 I2S
--! @details  CS4344 DAC Driver: 32b P/S Converter
---------------------------------------------------------------------------------------------------

-- Standard Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- User Libraries

--! Entity top_level
entity cs4344 is
  port(
    s_axis_resetn : in std_logic;                     -- Synchronous axis reset (active low)
    s_axis_clk    : in std_logic;                     -- AXIS System Clock (125MHz)
    s_axis_tdata  : in std_logic_vector(31 downto 0); -- 32 bit input data
    s_axis_tvalid : in std_logic;                     -- AXIS Valid Signal
    s_axis_tready : out std_logic;                    -- AXIS Ready Signal
    sdata         : out std_logic;                    -- Serial Data for I2S stream
    lrclk         : out std_logic;                    -- Left Right 48kHz Clk
    sclk          : out std_logic;                    -- Serial 3.125MHz Clk
    mclk          : out std_logic                     -- Master 12.5MHz Clk
  );
end cs4344;

--! Architecture
architecture behav of cs4344 is

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
  
  component axis_data_fifo_0
    port (
      s_axis_aresetn  : in std_logic;
      s_axis_aclk     : in std_logic;
      s_axis_tvalid   : in std_logic;
      s_axis_tready   : out std_logic;
      s_axis_tdata    : in std_logic_vector(31 downto 0);
      m_axis_tvalid   : out std_logic;
      m_axis_tready   : in std_logic;
      m_axis_tdata    : out std_logic_vector(31 downto 0)
    );
  end component;

begin

  axis_audio_fifo : axis_data_fifo_0
    port map (
      s_axis_aresetn  => s_axis_resetn,
      s_axis_aclk     => s_axis_clk,
      s_axis_tvalid   => s_axis_tvalid,
      s_axis_tready   => s_axis_tready,
      s_axis_tdata    => s_axis_tdata,
      m_axis_tvalid   => fifo_tvalid,
      m_axis_tready   => fifo_tready,
      m_axis_tdata    => fifo_tdata
    );

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
  -- FIFO
  -- ------------------------------------------------
  --! Process to create tready for FIFO to advance
  fifo_tready_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        fifo_tready   <= '0';
      elsif (lrclk_reg = '0' and lrclk_s = '1') or (lrclk_reg = '1' and lrclk_s = '0') then
          fifo_tready <= '1';
      else
          fifo_tready <= '0';
      end if;
    end if;
  end process;

  --! Latch data from FIFO
  fifo_data_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        audio_data  <= (others => '0');
      elsif fifo_tvalid = '1' then
        audio_data  <= fifo_tdata;
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
  
  --! Serial Data
  sdata <= audio_data(to_integer(frame_count));

end behav;
