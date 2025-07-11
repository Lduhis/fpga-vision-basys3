library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.register_address_gen_pkg.all;

entity ov7670_controller is
  generic (
    Clk_frequency  : integer := 50_000_000; -- System Clock Frequency 50MHz
    Sioc_frequency : integer := 400_000); -- SCCB Clock Frequency 400kHz
  port (
    Clk             : in std_logic;
    Resend          : in std_logic;
    Reset           : out std_logic;
    Enable          : in std_logic;
    Siod            : inout std_logic := 'Z';
    Sioc            : out std_logic   := '1';
    Xclk            : out std_logic;
    Pwnd            : out std_logic;
    Config_finished : out std_logic
  );
end ov7670_controller;
architecture Behavioral of ov7670_controller is

  type state_type is (S_IDLE, S_START, S_ADDRESS, S_ADDRESS_DC, S_REGISTER, S_REGISTER_DC, S_DATA, S_DATA_DC, S_STOP, s_DONE);
  signal state : state_type := S_IDLE;

  -- CONSTANTS
  constant clk_divider : integer := Clk_frequency / (2 * Sioc_frequency);
  constant midpoint    : integer := clk_divider / 2;
  -- INTERNAL SIGNALS
  signal sioc_clk      : std_logic;
  signal sioc_clk_prev : std_logic;
  signal sioc_int      : std_logic := '1';
  signal siod_int      : std_logic := 'Z';
  signal Xclk_reg      : std_logic := '0';

  signal sioc_rising  : std_logic;
  signal sioc_falling : std_logic;
  signal start        : std_logic := '0';
  --
  signal clk_cnt        : integer range 0 to clk_divider - 1;
  signal clk_enable_mid : std_logic;

  signal bit_index       : integer range 0 to 7                            := 0;
  signal current_command : integer range 0 to OV7670_REGS_ARRAY'length - 1 := 0;

  signal address_buffer      : std_logic_vector(7 downto 0) := (others => '0');
  signal data_buffer         : std_logic_vector(7 downto 0) := (others => '0');
  signal register_buffer     : std_logic_vector(7 downto 0) := (others => '0');
  signal config_finished_int : std_logic;

begin

  Sioc <= sioc_clk when state = S_ADDRESS or state = S_REGISTER or state = S_DATA else
    sioc_int;
  Siod <= siod_int when Enable = '1' else
    'Z';

  -- XCLK generation: divide 50MHz by 2 --> 25MHz
  process (Clk)
  begin
    if rising_edge(Clk) then
      Xclk_reg <= not Xclk_reg;
    end if;
  end process;

  Xclk <= Xclk_reg;
  Pwnd <= '0';

  --SIOC CLOCK GENERATION PROCESS
  process (Clk)
  begin
    if rising_edge(Clk) then
      if clk_cnt = midpoint - 1 then
        clk_enable_mid <= '1';
      else
        clk_enable_mid <= '0';
      end if;

      sioc_clk_prev <= sioc_clk;

      if clk_cnt = clk_divider - 1 then
        clk_cnt  <= 0;
        sioc_clk <= not sioc_clk;
      else
        clk_cnt <= clk_cnt + 1;
      end if;
    end if;
  end process;

  --SIOC CLOCK EDGE DETECTION PROCESS
  process (Clk)
  begin
    if rising_edge(Clk) then
      if sioc_clk = '1' and sioc_clk_prev = '0' then
        sioc_rising <= '1';
      else
        sioc_rising <= '0';
      end if;
      if sioc_clk = '0' and sioc_clk_prev = '1' then
        sioc_falling <= '1';
      else
        sioc_falling <= '0';
      end if;
    end if;
  end process;

  Reset <= '1' when (Resend = '1' and config_finished_int = '0') else
    '0';

  --MAIN PROCESS
  Main_Process : process (Clk, Resend)
  begin

    if Resend = '1' then
      state               <= S_IDLE;
      Config_finished_int <= '0';
      current_command     <= 0;
      start               <= '0';
      siod_int            <= 'Z';
      sioc_int            <= '1';
      bit_index           <= 0;

    elsif rising_edge(Clk) then
      case state is
        when S_IDLE =>
          if sioc_falling = '1' then
            if Enable = '1' then
              siod_int <= '1';
              sioc_int <= '1';
              start    <= '1';
            else
              siod_int <= 'Z';
              sioc_int <= '1';
            end if;
          elsif sioc_rising = '1' and start = '1' then
            siod_int <= '0';
            state    <= S_START;
          end if;
        when S_START =>
          if sioc_falling = '1' then
            address_buffer  <= OV7670_I2C_ADDRESS;
            register_buffer <= OV7670_REGS_ARRAY(current_command)(15 downto 8);
            data_buffer     <= OV7670_REGS_ARRAY(current_command)(7 downto 0);
            state           <= S_ADDRESS;
          end if;
        when S_ADDRESS =>
          if sioc_clk = '0' and clk_enable_mid = '1' then
            siod_int <= address_buffer(7 - bit_index);
            if bit_index < 7 then
              bit_index <= bit_index + 1;
            else
              bit_index <= 0;
              state     <= S_ADDRESS_DC;
            end if;
          end if;
        when S_ADDRESS_DC =>

          if sioc_falling = '1' then
            siod_int <= 'Z';
            state    <= S_REGISTER;
          end if;
        when S_REGISTER =>
          if sioc_clk = '0' and clk_enable_mid = '1' then
            siod_int <= register_buffer(7 - bit_index);
            if bit_index < 7 then
              bit_index <= bit_index + 1;
            else
              bit_index <= 0;
              state     <= S_REGISTER_DC;
            end if;
          end if;
        when S_REGISTER_DC =>
          if sioc_falling = '1' then
            siod_int <= 'Z';
            state    <= S_DATA;
          end if;
        when S_DATA =>
          if sioc_clk = '0' and clk_enable_mid = '1' then
            siod_int <= data_buffer(7 - bit_index);
            if bit_index < 7 then
              bit_index <= bit_index + 1;
            else
              bit_index <= 0;
              state     <= S_DATA_DC;
            end if;
          end if;
        when S_DATA_DC =>
          if sioc_falling = '1' then
            siod_int <= 'Z';
            state    <= S_STOP;
          end if;
        when S_STOP =>
          if sioc_rising = '1' then
            siod_int <= 'Z';
            if OV7670_REGS_ARRAY(current_command + 1) = x"FFFF" then
              state <= s_DONE;
            else
              current_command <= current_command + 1;
              state           <= S_START;
            end if;
          end if;
        when S_DONE =>
          siod_int            <= '1';
          config_finished_int <= '1';
          start               <= '0';
          current_command     <= 0;
          if Resend = '1' then
            current_command     <= 0;
            config_finished_int <= '0';
            state               <= S_START;
          else
            state <= S_IDLE;
          end if;
      end case;
    end if;
  end process;
  Config_finished <= config_finished_int;
end Behavioral;