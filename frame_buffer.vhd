library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity frame_buffer is
--  Port ( );
end frame_buffer;

architecture Behavioral of frame_buffer is

component fifo_generator_0 IS
Port (rst           : IN STD_LOGIC;
    wr_clk          : IN STD_LOGIC;
    rd_clk          : IN STD_LOGIC;
    din             : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en           : IN STD_LOGIC;
    rd_en           : IN STD_LOGIC;
    dout            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full            : OUT STD_LOGIC;
    almost_full     : OUT STD_LOGIC;
    empty           : OUT STD_LOGIC;
    almost_empty    : OUT STD_LOGIC;
    wr_rst_busy     : OUT STD_LOGIC;
    rd_rst_busy     : OUT STD_LOGIC
  );
end component fifo_generator_0;    

signal rst : std_logic := '0';
signal wr_clk : std_logic := '0';
signal rd_clk : std_logic := '0';
signal din : std_logic_vector(15 downto 0) := (others => '0');
signal wr_en : std_logic := '0';
signal rd_en : std_logic := '0';
signal dout : std_logic_vector(15 downto 0);
signal full : std_logic;
signal almost_full : std_logic;
signal empty : std_logic;       
--
signal data_in_buffer : std_logic_vector(15 downto 0) := (others => '0');
signal data_out_buffer : std_logic_vector(15 downto 0) := (others => '0');

begin

-- FIFO Instance
fifo_inst: fifo_generator_0
port map (
    rst             => rst,
    wr_clk          => wr_clk,
    rd_clk          => rd_clk,
    din             => din,
    wr_en           => wr_en,
    rd_en           => rd_en,
    dout            => dout,
    full            => full,
    almost_full     => almost_full,
    empty           => empty,
    almost_empty    => '0',     -- Not used
    wr_rst_busy     => '0',     -- Not used
    rd_rst_busy     => '0'      -- Not used
);

-- Write Process
write_process: process(wr_clk)
begin
    if rising_edge(wr_clk) then
        if wr_en = '1' then
            din <= data_in_buffer;
        end if;   
    end if;
end process write_process;
-- Read Process
read_process: process(rd_clk)
begin
    if rising_edge(rd_clk) then
        if rd_en = '1' then
            data_out_buffer <= dout;
        end if;
    end if;
end process read_process;

end Behavioral;

