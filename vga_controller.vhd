library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity vga_controller is
Generic(h_Visible_Area  : integer := 640;
        h_Front_Porch   : integer := 16;
        h_Synch_Pulse   : integer := 96;
        h_Back_Porch    : integer := 48;
        h_Whole_Line    : integer := 800;
        h_Sync_Polarity : std_logic := '0';
        
        v_Visible_Area  : integer := 480;
        v_Front_Porch   : integer := 10;
        v_Synch_Pulse   : integer := 2;
        v_Back_Porch    : integer := 33;
        v_Whole_Line    : integer := 525;
        v_Sync_Polarity : std_logic := '0';
        
        RGB_Length      : integer  := 8);    

Port(Clk_25MHz      : in std_logic;
    Enable          : in std_logic;
    Buffer_Data     : in std_logic_vector(RGB_Length * 3 - 1 downto 0);
    DE              : out std_logic;
    HSync, VSync    : out std_logic;
    R, G, B         : out std_logic_vector(RGB_Length - 1 downto 0);
    Buffer_Address  : out std_logic_vector(31 downto 0));
end vga_controller;

architecture Behavioral of vga_controller is

signal h_Count : integer range 0 to h_Whole_Line - 1 := 0;
signal v_Count : integer range 0 to v_Whole_Line - 1 := 0;

signal h_Pulse, v_Pulse : std_logic;
signal h_Visible, v_Visible : std_logic;

begin

process(Clk_25MHz)
begin
    if rising_edge(Clk_25MHz) and Enable = '1' then

        if h_Count < h_Whole_Line - 1 then
            h_Count <= h_Count + 1;
        else 
            h_Count <= 0;
            if  v_Count < v_Whole_Line - 1 then
                v_Count <= v_Count + 1;
            else 
                v_Count <= 0;
            end if;
        end if;
        
        if h_Count < h_Visible_Area then
            h_Pulse     <= '0';
            h_Visible   <= '1';
        elsif h_Count < h_Visible_Area + h_Front_Porch then
            h_Pulse     <= '0';
            h_Visible   <= '0';
        elsif h_Count < h_Visible_Area + h_Front_Porch + h_Synch_Pulse then
            h_Pulse     <= '1';
            h_Visible   <= '0';
        elsif h_Count < h_Whole_Line then
            h_Pulse     <= '0';
            h_Visible   <= '0';

        end if;
        if v_Count < v_Visible_Area then
            v_Pulse     <= '0';
            v_Visible   <= '1';
        elsif v_Count < v_Visible_Area + v_Front_Porch then
            v_Pulse     <= '0';
            v_Visible   <= '0';
        elsif v_Count < v_Visible_Area + v_Front_Porch + v_Synch_Pulse then
            v_Pulse     <= '1';
            v_Visible   <= '0';
        elsif v_Count < v_Whole_Line then
            v_Pulse     <= '0';
            v_Visible   <= '0';
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

            R   <= Buffer_Data(RGB_Length * 3 - 1 downto RGB_Length * 2);
            G   <= Buffer_Data(RGB_Length * 2 - 1 downto RGB_Length);
            B   <= Buffer_Data(RGB_Length - 1 downto 0);
            DE  <= '1';
        else
            R   <= (others => '0');
            G   <= (others => '0');
            B   <= (others => '0');
            DE  <= '0';
        end if;
    end if;
end process;
end Behavioral;
