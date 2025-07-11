library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package ram_pkg is
  function clogb2 (depth : in natural) return integer;
end ram_pkg;

package body ram_pkg is

  function clogb2(depth : natural) return integer is
    variable temp         : integer := depth;
    variable ret_val      : integer := 0;
  begin
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;
    end loop;

    return ret_val;
  end function;

end package body ram_pkg;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.ram_pkg.ALL;
use std.textio.ALL;

entity xilinx_simple_dual_port_2_clock_ram is
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

end xilinx_simple_dual_port_2_clock_ram;

architecture rtl of xilinx_simple_dual_port_2_clock_ram is

  constant C_RAM_WIDTH       : integer := RAM_WIDTH;
  constant C_RAM_DEPTH       : integer := RAM_DEPTH;
  constant C_RAM_PERFORMANCE : string  := RAM_PERFORMANCE;


  signal ram_data  : std_logic_vector(C_RAM_WIDTH - 1 downto 0);
  signal doutb_reg : std_logic_vector(C_RAM_WIDTH - 1 downto 0) := (others => '0');

  type ram_type is array (C_RAM_DEPTH - 1 downto 0) of std_logic_vector (C_RAM_WIDTH - 1 downto 0); -- 2D Array Declaration for RAM signal
  signal ram_name : ram_type := (others => (others => '0'));

begin

  process (clka)
  begin
    if rising_edge(clka) then
      if (wea = '1') then
        ram_name(to_integer(unsigned(addra))) <= dina;
      end if;
    end if;
  end process;

  process (clkb)
  begin
    if rising_edge(clkb) then
      ram_data <= ram_name(to_integer(unsigned(addrb)));
    end if;
  end process;

  no_output_register : if C_RAM_PERFORMANCE = "LOW_LATENCY" generate
    doutb <= ram_data;
  end generate;

end rtl;