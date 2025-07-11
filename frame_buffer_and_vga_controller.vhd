library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.ram_pkg.all;
entity frame_buffer_and_vga_controller is
  generic (
    RAM_WIDTH : integer := 12;
    RAM_DEPTH : integer := 131072
  );
  port (
    Clk     : in std_logic;
    Reset   : in std_logic;
    Enable  : in std_logic;
    HSync   : out std_logic;
    VSync   : out std_logic;
    R, G, B : out unsigned(3 downto 0);
    DE      : out std_logic
  );
end frame_buffer_and_vga_controller;

architecture Behavioral of frame_buffer_and_vga_controller is

  signal Clk_25MHz, Clk_50MHz : std_logic                                          := '0';
  signal wr_clk, rd_clk       : std_logic                                          := '0';
  signal debounced_reset      : std_logic                                          := '0';
  signal we                   : std_logic                                          := '0';
  signal write_data           : std_logic_vector(RAM_WIDTH - 1 downto 0)           := (others => '0');
  signal read_data            : std_logic_vector(RAM_WIDTH - 1 downto 0)           := (others => '0');
  signal buffer_data          : std_logic_vector(RAM_WIDTH - 1 downto 0)           := (others => '0');
  signal write_address        : std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0) := (others => '0');
  signal read_address         : std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0) := (others => '0');

  component clk_divider is
    port (
      Clk_in    : in std_logic;
      Clk_25MHz : out std_logic;
      Clk_50Mhz : out std_logic);
  end component clk_divider;

  component frame_buffer is
    generic (
      RAM_WIDTH : integer := 12;
      RAM_DEPTH : integer := 131072
    );
    port (
      Clka  : in std_logic;
      Clkb  : in std_logic;
      Wea   : in std_logic;
      Dina  : in std_logic_vector(RAM_WIDTH - 1 downto 0);
      Addra : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0);
      Addrb : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0);
      Doutb : out std_logic_vector(RAM_WIDTH - 1 downto 0)

    );
  end component frame_buffer;

  component vga_controller is
    generic (
      h_Visible_Area  : integer   := 640; -- Horizontal visible area in pixels
      h_Front_Porch   : integer   := 16; -- Horizontal front porch in pixels
      h_Synch_Pulse   : integer   := 96; -- Horizontal sync pulse width in pixels
      h_Back_Porch    : integer   := 48; -- Horizontal back porch in pixels
      h_Whole_Line    : integer   := 800; -- Total horizontal line length in pixels
      h_Sync_Polarity : std_logic := '0'; -- Horizontal sync polarity (0 for negative, 1 for positive)

      v_Visible_Area  : integer   := 480; -- Vertical visible area in lines        
      v_Front_Porch   : integer   := 10; -- Vertical front porch in lines        
      v_Synch_Pulse   : integer   := 2; -- Vertical sync pulse width in lines
      v_Back_Porch    : integer   := 33; -- Vertical back porch in lines
      v_Whole_Line    : integer   := 525; -- Total vertical line length in lines
      v_Sync_Polarity : std_logic := '0'; -- Vertical sync polarity (0 for negative, 1 for positive)

      RGB_Length : integer := 4; -- Length of RGB data in bits
      ADDR_WIDTH : integer := 17
    );

    port (
      Clk_25MHz      : in std_logic;
      Reset          : in std_logic;
      Enable         : in std_logic;
      Buffer_Data    : in std_logic_vector(RGB_Length * 3 - 1 downto 0);
      DE             : out std_logic;
      HSync, VSync   : out std_logic;
      R, G, B        : out unsigned(RGB_Length - 1 downto 0);
      Buffer_Address : out std_logic_vector(ADDR_WIDTH - 1 downto 0)
    );
  end component vga_controller;

  component debounce is
    generic (
      Clk_frequency    : integer := 100_000_000;
      Debounce_time_ms : integer := 10);
    port (
      Clk     : in std_logic;
      Btn_in  : in std_logic;
      Btn_out : out std_logic);
  end component debounce;

begin

  clk_divider_inst : clk_divider
  port map
  (
    Clk_in    => Clk,
    Clk_25MHz => Clk_25MHz,
    Clk_50Mhz => Clk_50Mhz
  );

  frame_buffer_inst : frame_buffer
  generic map
  (
    RAM_WIDTH => RAM_WIDTH,
    RAM_DEPTH => RAM_DEPTH
  )
  port map
  (
    Clka  => Clk_25MHz,
    Clkb  => Clk,
    Wea   => we,
    Dina  => write_data,
    Addra => write_address,
    Addrb => read_address,
    Doutb => read_data
  );

  vga_controller_inst : vga_controller
  port map
  (
    Clk_25MHz      => Clk_25MHz,
    Reset          => debounced_reset,
    Enable         => Enable,
    Buffer_Data    => buffer_data,
    DE             => DE,
    HSync          => HSync,
    VSync          => VSync,
    R              => R,
    G              => G,
    B              => B,
    Buffer_Address => read_address
  );

  debounce_inst : debounce
  generic map(
    Clk_frequency    => 100_000_000,
    Debounce_time_ms => 10
  )
  port map
  (
    Clk     => Clk,
    Btn_in  => Reset,
    Btn_out => debounced_reset
  );

  buffer_data(11 downto 8) <= read_data(11 downto 8); -- Red [4 bit]
  buffer_data(7 downto 4)  <= read_data(7 downto 4); -- Green [4 bit]
  buffer_data(3 downto 0)  <= read_data(3 downto 0); -- Blue [4 bit]

end Behavioral;