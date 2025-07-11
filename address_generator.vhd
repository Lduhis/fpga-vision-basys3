library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
entity address_generator is
  generic (
    ADDR_WIDTH      : integer := 17;
    H_VISIBLE_AREA  : integer := 640
  );
  port (
    Clk_25MHz : in std_logic;
    Reset     : in std_logic;
    Enable    : in std_logic;
    H_count   : in unsigned(9 downto 0);
    V_count   : in unsigned(9 downto 0);
    Address   : out std_logic_vector(ADDR_WIDTH - 1 downto 0)
  );
end address_generator;

architecture Behavioral of address_generator is

  signal pixel_address : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');

begin
    process(Clk_25MHz)
    begin
        if rising_edge(Clk_25MHz) then
            if Reset = '1' then
                pixel_address <= (others => '0');
            elsif Enable = '1' then
                pixel_address <= unsigned(V_count * H_VISIBLE_AREA + H_count);
            end if;
        end if;
end process;
end Behavioral;