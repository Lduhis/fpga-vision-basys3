library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce is
Generic (
    Clk_frequency : integer := 100_000_000;
    Debounce_time_ms : integer := 10);
Port (
    Clk : in std_logic;
    Btn_in : in std_logic;
    Btn_out : out std_logic);
end debounce;

architecture Behavioral of debounce is

-- Constant
constant count_max : integer := (Clk_frequency /1000) * Debounce_time_ms;
constant threshold : unsigned(27 downto 0) := to_unsigned(count_max, 28); 
-- Signal
signal counter      : unsigned(27 downto 0) := (others => '0');
signal btn_state    : std_logic := '0';
signal btn_sync0    : std_logic := '0';
signal btn_sync1    : std_logic := '0';

begin 
process (Clk)
begin
    if rising_edge(Clk) then
        btn_sync0 <= Btn_in;
        btn_sync1 <= btn_sync0;
        if btn_sync1 = btn_state then
            counter <= (others => '0');
        else
            if counter >= threshold then
                btn_state <= btn_sync1;
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if; 
        end if;
    end if;
end process;
Btn_out <= btn_state;
end Behavioral;
