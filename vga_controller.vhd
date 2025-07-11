library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
entity vga_controller is
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
end vga_controller;

architecture Behavioral of vga_controller is

  signal h_Count : integer range 0 to h_Whole_Line - 1 := 0; -- Horizontal pixel counter
  signal v_Count : integer range 0 to v_Whole_Line - 1 := 0; -- Vertical line counter

  signal h_Pulse, v_Pulse     : std_logic := '0'; -- Horizontal and vertical sync pulse signals
  signal h_Visible, v_Visible : std_logic := '0'; -- Horizontal and vertical visible area signals

begin

  Buffer_Address <= std_logic_vector(to_unsigned(v_Count * h_Visible_Area + h_Count, ADDR_WIDTH));

  process (Clk_25MHz, Reset, Enable)
  begin
    if Reset = '1' then
      h_Count   <= 0;
      v_Count   <= 0;
      h_Pulse   <= '0';
      v_Pulse   <= '0';
      h_Visible <= '0';
      v_Visible <= '0';

    elsif rising_edge(Clk_25MHz) and Enable = '1' then
      if h_Count < h_Whole_Line - 1 then
        h_Count <= h_Count + 1;
      else
        h_Count <= 0;
        if v_Count < v_Whole_Line - 1 then
          v_Count <= v_Count + 1;
        else
          v_Count <= 0;
        end if;
      end if;

      if h_Count < h_Visible_Area then
        h_Pulse   <= '0';
        h_Visible <= '1';
      elsif h_Count < h_Visible_Area + h_Front_Porch then
        h_Pulse   <= '0';
        h_Visible <= '0';
      elsif h_Count < h_Visible_Area + h_Front_Porch + h_Synch_Pulse then
        h_Pulse   <= '1';
        h_Visible <= '0';
      elsif h_Count < h_Whole_Line then
        h_Pulse   <= '0';
        h_Visible <= '0';
      end if;

      if v_Count < v_Visible_Area then
        v_Pulse   <= '0';
        v_Visible <= '1';
      elsif v_Count < v_Visible_Area + v_Front_Porch then
        v_Pulse   <= '0';
        v_Visible <= '0';
      elsif v_Count < v_Visible_Area + v_Front_Porch + v_Synch_Pulse then
        v_Pulse   <= '1';
        v_Visible <= '0';
      elsif v_Count < v_Whole_Line then
        v_Pulse   <= '0';
        v_Visible <= '0';
      end if;

      if h_Pulse = '1' then
        HSync <= h_Sync_Polarity;
      else
        HSync <= not h_Sync_Polarity;
      end if;

      if v_Pulse = '1' then
        VSync <= v_Sync_Polarity;
      else
        VSync <= not v_Sync_Polarity;
      end if;

      if h_Visible = '1' and v_Visible = '1' then
        R  <= unsigned(Buffer_Data(11 downto 8));
        G  <= unsigned(Buffer_Data(7 downto 4));
        B  <= unsigned(Buffer_Data(3 downto 0));
        DE <= '1';
      else
        R  <= (others => '0');
        G  <= (others => '0');
        B  <= (others => '0');
        DE <= '0';
      end if;
    end if;
  end process;
end Behavioral;
