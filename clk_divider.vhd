library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity clk_divider is
  Generic (
    Sys_frequency   : integer := 100_000_000;
    Clk_25MHz_freq  : integer := 25_000_000;
    Clk_50MHz_freq  : integer := 50_000_000
  );
  port (
    Clk_in    : in std_logic;
    Clk_25MHz : out std_logic;
    Clk_50MHz : out std_logic);
end clk_divider;

architecture Behavioral of clk_divider is

  constant divisor_25MHz : integer := (Sys_frequency/(Clk_25MHz_freq * 2));   -- Divisor for 25 MHz clock
  constant divisor_50MHz : integer := (Sys_frequency/(Clk_50MHz_freq * 2));   -- Divisor for 50 MHz clock  

  signal count_25MHz   : integer range 0 to divisor_25MHz - 1 := 0;             -- Counter for 25 MHz clock
  signal count_50MHz   : integer range 0 to divisor_50MHz - 1 := 0;             -- Counter for 50 MHz clock
  
  signal Clk_25MHz_int : std_logic := '0';                                  -- Internal signal for 25 MHz clock
  signal Clk_50MHz_int : std_logic := '0';                                  -- Internal signal for 50 MHz clock

begin
  process (Clk_in)
  begin
    if rising_edge(Clk_in) then
      -- Generate 25 MHz clock
      if count_25MHz = divisor_25MHz - 1 then
        Clk_25MHz_int <= not Clk_25MHz_int; -- Toggle clock signal
        count_25MHz   <= 0; -- Reset counter
      else 
        count_25MHz <= count_25MHz + 1;
      end if;

      -- Generate 50 MHz clock
      if count_50MHz = divisor_50MHz - 1 then
        Clk_50MHz_int <= not Clk_50MHz_int; -- Toggle clock signal
        count_50MHz   <= 0; -- Reset counter
      else
        count_50MHz <= count_50MHz + 1;
      end if;
    end if;
  end process;
  Clk_25MHz <= Clk_25MHz_int;
  Clk_50MHz <= Clk_50MHz_int;
end Behavioral;
