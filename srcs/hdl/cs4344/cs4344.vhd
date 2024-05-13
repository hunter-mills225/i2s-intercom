---------------------------------------------------------------------------------------------------
--! @file     cs4344.vhd
--! @author   Hunter Mills
--! @brief    Entity to drive CS4344 I2S
--! @details  CS4344 AXIS DAC Driver: 32b P/S Converter
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
  resetn        : in std_logic; 										-- Synchronous reset (active low)
  clk125        : in std_logic; 										-- System Clk
  data_word     : in std_logic_vector(31 downto 0);	-- 32 bit input data
	sdata         : out std_logic;  									-- Serial Data for I2S stream
  lrck          : out std_logic;  									-- Left Right 97656.25kHz Clk
  sclk          : out std_logic;  									-- Serial 3.125MHz Clk
  mclk          : out std_logic  										-- Master 12.5MHz Clk
  );
end cs4344;

--! Architecture
architecture behav of cs4344 is
  -- ------------------------------------------------
  -- Signals
  -- ------------------------------------------------

  --! Counter Signals
  signal l_cnt    : natural range 0 to 1279 := 0;
  signal s_cnt    : natural range 0 to 39   := 0;
  signal m_cnt    : natural range 0 to 9    := 0;
  signal data_cnt : unsigned(4 downto 0)    := (others => '0');

  --! Clock Signals
  signal s_lrck : std_logic;
  signal s_sclk : std_logic;
  signal s_mclk : std_logic;

  --! Register
  signal data_word_reg  : std_logic_vector(31 downto 0);

begin
  -- ------------------------------------------------
  -- Processes for counters and clk
  -- ------------------------------------------------

	--! Process to count clk125 for MCLK
	--!		MCLK is 12.5MHz = 125MHz / 10
  mclk_cnt_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        m_cnt <= 0;
      else
        if m_cnt = 9 then
          m_cnt <= 0;
        else
          m_cnt <= m_cnt + 1;
        end if;
      end if;
    end if;
  end process;

	--! Process to count clk125 for LRCK
	--! 	LRCK is sample rate of putting both words into the device
	--!		LRCK = 12.5MHz / 128 = 97656.25Hz
  lrck_cnt_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        l_cnt <= 80;    -- This offset is to account for the 1 data_cnt offset, set to 0 if that is wrong
      else
        if l_cnt = 1279 then
          l_cnt <= 0;
        else
          l_cnt <= l_cnt + 1;
        end if;
      end if;
    end if;
  end process;

	--! Process to count clk125 for SCLK
	--!		SCLK is sample rate * 32b
	--!		SCLK = LRCK * 32
  sclk_cnt_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        s_cnt <= 0;
      else
        if s_cnt = 39 then
          s_cnt <= 0;
        else
          s_cnt <= s_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  --! Process to shift data on rising edge of SCLK
  data_cnt_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        data_cnt  <= (others => '1');
      else
        if s_sclk = '1' and s_cnt = 39 then
          data_cnt  <= data_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  --! Process to create lrck
  clk_lrck_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        s_lrck  <= '0';
      else
        if l_cnt = 1279 then
          s_lrck  <= not(s_lrck);
        end if;
      end if;
    end if;
  end process;

  --! Process to create sclk
  clk_sclk_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        s_sclk  <= '0';
      else
        if s_cnt = 39 then
          s_sclk  <= not(s_sclk);
        end if;
      end if;
    end if;
  end process;

  --! Process to create mclk
  clk_mclk_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        s_mclk  <= '0';
      else
        if m_cnt = 4 then
          s_mclk  <= not(s_mclk);
        end if;
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Register Input Data for Clock Domain Crossing
  -- ------------------------------------------------
  cdc_reg_data_word_p : process(clk125)
  begin
    if rising_edge(clk125) then
      if resetn = '1' then
        data_word_reg <= (others => '0');
      elsif data_cnt = 0 and s_cnt = 39 and s_sclk = '1' then
        data_word_reg <= data_word;
      end if;
    end if;
  end process;

  -- ------------------------------------------------
  -- Signal Assignments
  -- ------------------------------------------------
  lrck  <= s_lrck;
  bclk  <= s_bclk;
  mclk  <= s_mclk;
  sdata <= data_word_reg(to_integer(data_cnt));

end behav;
