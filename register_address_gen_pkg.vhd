library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package register_address_gen_pkg is
    type reg_array is array(natural range <>) of std_logic_vector(23 downto 0);
    constant ov7670_regs_array : reg_array := ( 
        x"12_80", -- COM7: Reset
        x"11_01", -- CLKRC: Clock prescaler (default 1)
        x"0C_04", -- COM3: Enable scaling
        x"3E_00", -- COM14: PCLK scaling off
        x"40_10", -- COM15: RGB565 format
        x"3A_04", -- TSLB: Set UV ordering, no auto reset window
        x"14_38", -- COM9: AGC ceiling
        x"3D_C0", -- COM13: Gamma enable, UV auto adjust
        x"12_04", -- COM7: Enable RGB output (RGB mode)
        x"0E_61", -- COM5: Reserved settings
        x"0F_4B", -- COM6: Reserved settings
        x"1E_07", -- MVFP: Mirror and flip control (0x07 is example)
        x"FF_FFFF" -- End marker
    );
    
end register_address_gen_pkg;



