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
    s_axis_tlast  : in std_logic;                     -- AXIS Last Signal
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
  signal frame_count        : natural range 0 to 63   := 0; --! SCLK per LRCLK Period

  --! Data Counter
  signal data_count : natural range 0 to 23 := 23;

  --! Register Signals
  signal data_word  : std_logic_vector(31 downto 0);
  signal tvalid_reg : std_logic;
  signal tlast_reg  : std_logic;
  signal ready      : std_logic;

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
        mclk_s              <= '0';
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
        sclk_s              <= '0';
      elsif sclk_125clk_count = 19 then
        sclk_125clk_count <= 0;
        sclk_s            <= not(sclk_s);
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
        lrclk_s               <= '0';
      elsif lrclk_125clk_count = 1279 then
        lrclk_125clk_count  <= 0;
        lrclk_s               <= not(lrclk_s);
      else
      lrclk_125clk_count <= lrclk_125clk_count + 1;
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Data Count
  -- ------------------------------------------------
  data_count_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        data_count  <= 23;
      elsif lrclk_reg = '0' and lrclk_s = '1' and data_count > 0 then
        data_count <= data_count - 1;
      elsif lrclk_reg = '1' and lrclk_s = '0' and data_count > 0 then
        data_count <= data_count - 1;
      else
        data_count <= 0;
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
        tvalid_reg  <= '0';
        tlast_reg   <= '0';
        lrclk_reg   <= '0';
      else
        tvalid_reg  <= s_axis_tvalid;
        tlast_reg   <= s_axis_tlast;
        lrclk_reg   <= lrclk_s;
      end if;
    end if;
  end process;

  --! Latch Left and Right channel data
  latch_data_p : process(s_axis_clk)
  begin
    if rising_edge(s_axis_clk) then
      if s_axis_resetn = '0' then
        ldata <= (others => '0');
        rdata <= (others => '0');
      elsif tvalid_reg = '0' and s_axis_tvalid = '1' then
        ldata <= s_axis_tdata;
        ldata_valid <= '1';
      elsif tlast_reg = '0' and s_axis_tlast = '1' then
        rdata <= s_axis_tdata;
        rdata_valid <= '1';
      elsif ldata_valid = '1' and data_count = 0 then
        ldata_valid <= '0';
      elsif rdata_valid = '1' and data_count = 0 then
        rdata_valid <= '0';
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Signal Assignments
  -- ------------------------------------------------
  --! Process to assign sdata

  mclk <= mclk_s;
  sclk <= sclk_s;
  lrclk <= lrclk_s;
  s_axis_tready <= ready;

end behav;
