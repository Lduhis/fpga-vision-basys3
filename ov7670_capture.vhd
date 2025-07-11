library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity ov7670_capture is
  generic (
    RGB_LENGTH : integer := 4;
    RAM_WIDTH  : integer := 12;
    ADDR_WIDTH : integer := 17;
    RAM_DEPTH  : integer := 131072
  );
  port (
    Pclk     : in std_logic;
    Reset    : in std_logic;
    VSync    : in std_logic;
    Href     : in std_logic;
    Address  : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    Data_in  : in std_logic_vector(7 downto 0);
    Wr_en    : out std_logic;
    Data_out : out std_logic_vector(11 downto 0)
  );
end ov7670_capture;

architecture Behavioral of ov7670_capture is

  signal byte_state  : std_logic                                 := '0';
  signal wr_en_reg   : std_logic                                 := '0';
  signal temp_data   : std_logic_vector(7 downto 0)              := (others => '0');
  signal data_int    : std_logic_vector(11 downto 0)             := (others => '0');
  signal address_reg : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');

begin
  process (Pclk, Reset)
  begin
    if Reset = '1' then
      byte_state  <= '0';
      wr_en_reg   <= '0';
      temp_data   <= (others => '0');
      data_int    <= (others => '0');
      address_reg <= (others => '0');
    elsif rising_edge(Pclk) then
      wr_en_reg <= '0';
      if VSync = '0' and Href = '1' then
        if byte_state = '0' then
          temp_data  <= Data_in;
          byte_state <= '1';
        else
          -- RGB444 Format Decode
          data_int(11 downto 8) <= temp_data(7 downto 4); -- Red
          data_int(7 downto 4)  <= temp_data(3 downto 0); -- Green
          data_int(3 downto 0)  <= Data_in(7 downto 4); -- Blue
          wr_en_reg             <= '1';
          byte_state            <= '0';

          -- Write address
          if address_reg = std_logic_vector(to_unsigned(RAM_DEPTH - 1, ADDR_WIDTH)) then
            address_reg <= (others => '0');
          else
            address_reg <= std_logic_vector(unsigned(address_reg) + 1);
          end if;
        end if;
      else
        byte_state <= '0';
      end if;
    end if;
  end process;

  Wr_en    <= wr_en_reg;
  Address  <= address_reg;
  Data_out <= data_int;
end Behavioral;