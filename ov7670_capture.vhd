library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity ov7670_capture is
Port(Pclk : in std_logic;
    VSync : in std_logic;
    Href : in std_logic;
    Data  : in std_logic_vector(7 downto 0);
    -- FIFO INTERFACE
    Fifo_wr : out std_logic;
    Fifo_data : out std_logic_vector(15 downto 0));
end ov7670_capture;

architecture Behavioral of ov7670_capture is
-- Internal Signals 
signal byte_state : std_logic := '0';  
signal temp_data  : std_logic_vector(7 downto 0) := (others => '0');
signal fifo_wr_int : std_logic := '0';
signal fifo_data_int : std_logic_vector(15 downto 0) := (others => '0');

begin

process(Pclk) 
begin
    if rising_edge(Pclk) then
        fifo_wr_int <= '0';                         -- Reset FIFO write signal on clock edge
                                                    -- Check for VSync and Href signals
                                                    -- Capture data only when Href is high and VSync is low
        if VSync = '1' then
            byte_state <= '0';                      -- Reset byte state on VSync
            fifo_wr_int <= '0';                     -- Reset FIFO write signal
        elsif Href = '1' then           
            if byte_state = '0' then            
                temp_data <= Data;                  -- Capture first byte of data
                byte_state <= '1';                  -- Move to next state
            else
                fifo_data_int <= temp_data & Data;  -- Concatenate second byte with first
                fifo_wr_int <= '1';                 -- Set FIFO write signal
                byte_state <= '0';                  -- Reset state for next capture
            end if;
        end if;
    end if;
end process;
Fifo_wr <= fifo_wr_int;
Fifo_data <= fifo_data_int;
end Behavioral;