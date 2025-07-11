library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.ram_pkg.all;

entity frame_buffer is
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
end frame_buffer;

architecture Behavioral of frame_buffer is

  component xilinx_simple_dual_port_2_clock_ram is
    generic (
      RAM_WIDTH       : integer := 12; -- Specify RAM data width
      RAM_DEPTH       : integer := 131072; -- Specify RAM depth (number of entries)
      RAM_PERFORMANCE : string  := "LOW_LATENCY" -- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    );

    port (
      addra : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0); -- Write address bus, width determined from RAM_DEPTH
      addrb : in std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0); -- Read address bus, width determined from RAM_DEPTH
      dina  : in std_logic_vector(RAM_WIDTH - 1 downto 0); -- RAM input data
      clka  : in std_logic; -- Write Clock
      clkb  : in std_logic; -- Read Clock
      wea   : in std_logic; -- Write enable
      doutb : out std_logic_vector(RAM_WIDTH - 1 downto 0) -- RAM output data
    );

  end component xilinx_simple_dual_port_2_clock_ram;

begin

  Inst_xilinx_simple_dual_port_2_clock_ram : xilinx_simple_dual_port_2_clock_ram
  generic map(
    RAM_WIDTH => RAM_WIDTH,
    RAM_DEPTH => RAM_DEPTH
  )
  port map
  (
    addra => Addra,
    addrb => Addrb,
    dina  => Dina,
    clka  => Clka,
    clkb  => Clkb,
    wea   => Wea,
    doutb => Doutb
  );

end Behavioral;
