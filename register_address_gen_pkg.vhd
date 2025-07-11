library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


package register_address_gen_pkg is

  constant OV7670_I2C_ADDRESS : std_logic_vector(7 downto 0) := x"42";

  type reg_array is array(natural range <>) of std_logic_vector(15 downto 0);
  constant OV7670_REGS_ARRAY : reg_array := (
  x"1280",  -- COM7 Reset
  x"1101",  -- CLKRC Prescaler
  x"0C04",  -- COM3 Scaling
  x"3E00",  -- COM14 PCLK scaling off
  x"40C0",  -- COM15 RGB444 + Full range
  x"8C08",  -- RGB444 Enable
  x"3A04",  -- TSLB output sequence
  x"1204",  -- COM7 RGB output
  x"1E07",  -- MVFP Mirror/Flip
  x"FFFF"   -- End marker
  );

end register_address_gen_pkg;
