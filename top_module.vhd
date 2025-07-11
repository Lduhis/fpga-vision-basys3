library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.ram_pkg.all;
use work.register_address_gen_pkg.all;

entity top_module is
  generic (
    RGB_LENGTH    : integer := 4;
    RAM_WIDTH     : integer := 12;
    RAM_DEPTH     : integer := 131072;
    SYS_CLK_FREQ  : integer := 100_000_000;
    VGA_CLK_FREQ  : integer := 25_000_000;
    CAM_CLK_FREQ  : integer := 50_000_000;
    SSCB_CLK_FREQ : integer := 400_000

  );
  port (
    CLK             : in std_logic;
    RSND            : in std_logic;
    CONFIG_FINISHED : out std_logic;

    OV7670_PCLK  : in std_logic;
    OV7670_XCLK  : out std_logic;
    OV7670_VSYNC : in std_logic;
    OV7670_HREF  : in std_logic;
    OV7670_DATA  : in std_logic_vector((RGB_LENGTH * 2) - 1 downto 0);
    OV7670_SIOD  : inout std_logic;
    OV7670_SIOC  : out std_logic;
    OV7670_RST   : out std_logic;
    OV7670_PWDN  : out std_logic;

    VGA_HSYNC : out std_logic;
    VGA_VSYNC : out std_logic;
    VGA_R     : out unsigned(RGB_LENGTH - 1 downto 0);
    VGA_G     : out unsigned(RGB_LENGTH - 1 downto 0);
    VGA_B     : out unsigned(RGB_LENGTH - 1 downto 0);

    STATE_LED : out std_logic_vector(3 downto 0)
  );
end top_module;

architecture Behavioral of top_module is

  constant C_RGB_LENGTH   : integer := RGB_LENGTH;
  constant C_RAM_WIDTH    : integer := RAM_WIDTH;
  constant C_RAM_DEPTH    : integer := RAM_DEPTH;
  constant C_ADDR_WIDTH   : integer := clogb2(RAM_DEPTH);
  constant C_SYS_CLK_FREQ : integer := SYS_CLK_FREQ;
  constant C_VGA_CLK_FREQ : integer := VGA_CLK_FREQ;
  constant C_CAM_CLK_FREQ : integer := CAM_CLK_FREQ;

  signal CLK_VGA             : std_logic;
  signal CLK_CAM             : std_logic;
  signal RD_EN               : std_logic;
  signal WR_EN               : std_logic;
  signal VGA_EN              : std_logic;
  signal CAM_EN              : std_logic;
  signal RESEND              : std_logic;
  signal DEBOUNCED_RST       : std_logic;
  signal CONFIG_FINISHED_INT : std_logic;
  signal CAM_DATA            : std_logic_vector(RAM_WIDTH - 1 downto 0);
  signal WR_ADDR             : std_logic_vector(C_ADDR_WIDTH - 1 downto 0);
  signal RD_ADDR             : std_logic_vector(C_ADDR_WIDTH - 1 downto 0);
  signal BUFFER_DATA         : std_logic_vector((C_RGB_LENGTH * 3) - 1 downto 0);

  component debounce is
    generic (
      Clk_frequency    : integer := 100_000_000;
      Debounce_time_ms : integer := 10);
    port (
      Clk     : in std_logic;
      Btn_in  : in std_logic;
      Btn_out : out std_logic);
  end component debounce;

  component ov7670_controller is
    generic (
      Clk_frequency  : integer := 50_000_000;
      Sioc_frequency : integer := 400_000);
    port (
      Clk             : in std_logic;
      Resend          : in std_logic;
      Reset           : out std_logic;
      Enable          : in std_logic;
      Siod            : inout std_logic := 'Z';
      Sioc            : out std_logic   := '1';
      Xclk            : out std_logic;
      Pwnd            : out std_logic;
      Config_finished : out std_logic := '0');
  end component ov7670_controller;

  component frame_buffer is
    generic (
      RAM_WIDTH : integer := 12;
      RAM_DEPTH : integer := 131072
    );
    port (
      Clka  : in std_logic;
      Clkb  : in std_logic;
      Wea   : in std_logic;
      Addra : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0);
      Addrb : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0);
      Dina  : in std_logic_vector(RAM_WIDTH - 1 downto 0);
      Doutb : out std_logic_vector(RAM_WIDTH - 1 downto 0)
    );
  end component frame_buffer;

  component ov7670_capture is
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
  end component ov7670_capture;

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

  component clk_divider is
    port (
      Clk_in    : in std_logic;
      Clk_25MHz : out std_logic;
      Clk_50MHz : out std_logic);
  end component clk_divider;

begin

  CONFIG_FINISHED <= CONFIG_FINISHED_INT;
  CAM_EN          <= not CONFIG_FINISHED_INT;
  VGA_EN          <= CONFIG_FINISHED_INT;

  -- Instantiate the components
  --________________________________________________________________________--
  --Instantiate the clock divider
  Inst_clk_divider : clk_divider
  port map
  (
    Clk_in    => CLK,
    Clk_25MHz => CLK_VGA, 
    Clk_50MHz => CLK_CAM
  );
  --________________________________________________________________________--
  -- Instantiate the decounce
  Inst_debouncer : debounce
  generic map(
    Clk_frequency    => SYS_CLK_FREQ,
    Debounce_time_ms => 10
  )
  port map
  (
    Clk     => CLK,
    Btn_in  => RSND,
    Btn_out => RESEND
  );
  --________________________________________________________________________--
  --Instantiate the OV7670 controller
  Inst_ov7670_controller : ov7670_controller
  generic map(
    Clk_frequency  => CAM_CLK_FREQ,
    Sioc_frequency => SSCB_CLK_FREQ)
  port map
  (
    Clk             => CLK_CAM,
    Resend          => RESEND,
    Reset           => OV7670_RST,
    Enable          => CAM_EN,
    Siod            => OV7670_SIOD,
    Sioc            => OV7670_SIOC,
    Xclk            => OV7670_XCLK,
    Pwnd            => OV7670_PWDN,
    Config_finished => CONFIG_FINISHED_INT
  );
  --________________________________________________________________________--
  --Instantiate the OV7670 capture module
  Inst_ov7670_capture : ov7670_capture
  port map
  (
    Pclk     => OV7670_PCLK,
    Reset    => RESEND,
    VSync    => OV7670_VSYNC,
    Href     => OV7670_HREF,
    Address  => WR_ADDR,
    Data_in  => OV7670_DATA,
    Wr_en    => WR_EN,
    Data_out => CAM_DATA
  );
  --________________________________________________________________________--
  -- Instantiate the Frame Buffer (dual-port RAM)
  Inst_frame_buffer : frame_buffer
  port map
  (
    Clka  => OV7670_PCLK, -- Write clock (camera)
    Clkb  => CLK_VGA, -- Read clock (VGA)
    Wea   => WR_EN, -- Write enable
    Addra => WR_ADDR,
    Addrb => RD_ADDR,
    Dina  => CAM_DATA,
    Doutb => BUFFER_DATA
  );
  --________________________________________________________________________--
  -- INSTANTIATE THE VGA CONTROLLER
  Inst_vga_controller : vga_controller
  generic map(
    h_Visible_Area  => 640,
    h_Front_Porch   => 16,
    h_Synch_Pulse   => 96,
    h_Back_Porch    => 48,
    h_Whole_Line    => 800,
    h_Sync_Polarity => '0',

    v_Visible_Area  => 480,
    v_Front_Porch   => 10,
    v_Synch_Pulse   => 2,
    v_Back_Porch    => 33,
    v_Whole_Line    => 525,
    v_Sync_Polarity => '0',

    RGB_Length => RGB_LENGTH,
    ADDR_WIDTH => C_ADDR_WIDTH
  )
  port map
  (
    Clk_25MHz      => CLK_VGA,
    Reset          => RESEND,
    Enable         => VGA_EN,
    Buffer_Data    => BUFFER_DATA,
    HSync          => VGA_HSYNC,
    VSync          => VGA_VSYNC,
    R              => VGA_R,
    G              => VGA_G,
    B              => VGA_B,
    Buffer_Address => RD_ADDR
  );
  --________________________________________________________________________--

  STATE_LED(0) <= OV7670_VSYNC;
  STATE_LED(1) <= OV7670_HREF;
  STATE_LED(2) <= OV7670_PCLK;
  STATE_LED(3) <= WR_EN;
end Behavioral;
