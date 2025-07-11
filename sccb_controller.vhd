library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sccb_controller is
Generic(
    clk_frequency   : integer := 50_000_000;                                -- System clock frequency in Hz
    scioc_frequency : integer := 400_000
);                                  
Port(
    Clk : in std_logic;                                                    -- System clock input
    Start : in std_logic;                                                    -- Start signal for SCCB communication
    Enable : in std_logic;                                                   -- Enable signal for SCCB controller
    Siod : inout std_logic;                                                  -- System clock input
    Sioc : out std_logic;                                                    -- SCCB clock output 400 kHz
    Config_finished : out std_logic                                         -- Configuration finished signal
);
end sccb_controller;

architecture Behavioral of sccb_controller is

constant clk_divisor : integer := clk_frequency / (2 * scioc_frequency);    -- Clock divisor for SCCB frequency    
constant midpoint    : integer := clk_divisor / 2; 

signal clk_cnt : integer range 0 to clk_divisor - 1 := 0;                   -- Clock counter for SCCB clock generation
signal clk_enable_mid : std_logic := '0';
signal siod_int : std_logic := 'Z';                                         -- Internal SCCB data signal,
signal signal_enable : std_logic := '0';                                       -- Enable signal for SCCB data line
signal siod_drive : std_logic := '0';                                       -- Drive signal for SCCB data line
signal sioc_int : std_logic := '1';                                         -- Internal SCCB clock signal
signal sioc_clk : std_logic := '1';                                         -- SCCB clock signal output
signal sioc_clk_prev : std_logic := '1';                                   -- Previous state of SCCB clock signal

signal sent_byte : integer range 0 to 2 := 0;                               -- Counter for sent bytes
signal bit_index : integer range 0 to 7 := 0;                               -- Index for the current bit being sent

signal buffer_data : std_logic_vector(7 downto 0) := (others => '0');       -- Buffer for data to be sent
signal error_flag : std_logic := '0';                                       -- Error flag for SCCB communication
signal config_reg : std_logic := '0';                                       -- Configuration register
signal start_reg : std_logic := '0';                                       -- Start register

signal SWriteData : std_logic := '0';                                    -- Signal to indicate data is being written

signal data_in : std_logic_vector(7 downto 0) := (others => '0');               -- Data input for SCCB communication

type sccb_state_type is (S_IDLE, S_START_CONDITION, S_START, S_SEND_BYTE, S_DONTCARE, S_STOP_CONDITION, S_STOP, S_DONE);     
signal sccb_state : sccb_state_type := S_IDLE;                                -- Current state of the SCCB controller

type reg_array is array(natural range <>) of std_logic_vector(7 downto 0);
constant ov7670_regs_array : reg_array := ( 
    x"42",  -- Write address for OV7670 register
    x"12",  -- COM7: Reset
    x"80"   -- Reset value
);

begin

signal_enable <= Enable;
Sioc <= sioc_clk when sccb_state = S_SEND_BYTE else sioc_int;
Siod <= siod_int when signal_enable = '1' else 'Z';  
start_reg <= '1' when Start = '1' and signal_enable = '1' else '0';                       -- Tri-state buffer for SCCB data line

-- SCCB CLOCK GENERATION PROCESS
process(clk)
begin
    if rising_edge(clk) then

        sioc_clk_prev <= sioc_clk;                           -- Store previous state of SCCB clock signal
        
        if clk_cnt = midpoint - 1 then
            clk_enable_mid <= '1';                               -- Enable mid-point clock signal
        else
            clk_enable_mid <= '0';
        end if;

        if clk_cnt < clk_divisor - 1 then
            clk_cnt <= clk_cnt + 1;
        else
            clk_cnt <= 0;
            sioc_clk <= not sioc_clk;                           -- Toggle the SCCB clock signal
        end if;
    end if;
end process;
-- MAIN PROCESS
Main_process: process(Clk)
begin
    if rising_edge(Clk) then
        case sccb_state is
            when S_IDLE =>
                if sioc_clk = '0' and sioc_clk_prev = '1' then
                    if start_reg = '1' then
                        siod_int <= '1';
                        sioc_int <= '1';
                        SWriteData  <= '1';
                    else
                        siod_int <= 'Z'; 
                        sioc_int <= '1';
                    end if;
                elsif sioc_clk = '1' and sioc_clk_prev = '0' and SWriteData = '1' then
                    siod_int <= '0';
                    sccb_state <= S_START;
                end if;
            when S_START =>                                -- Reset bit index for the new byte
                if sioc_clk = '0' and sioc_clk_prev = '1' then
                    buffer_data <= ov7670_regs_array(sent_byte);  -- Load the next byte to be sent
                    sccb_state <= S_SEND_BYTE;
                end if;
            when S_SEND_BYTE =>
                if sioc_clk = '0' and clk_enable_mid = '1' then
                    siod_int <= buffer_data(7 - bit_index);
                    if bit_index < 7 then
                        bit_index <= bit_index + 1;
                    else
                        if sent_byte < 2 then
                            bit_index <= 0;                     -- Reset bit index for the next byte
                            sent_byte <= sent_byte + 1;
                            sccb_state <= S_DONTCARE;   -- Go to don't care state
                        end if;
                    end if;
                end if;
            when S_DONTCARE =>
                if sioc_clk = '0' and clk_enable_mid = '1' then
                    siod_int <= '0';
                if sent_byte = 2 then
                    sccb_state <= S_STOP;
                else
                    sccb_state <= S_START;                  
                end if;
                end if;
                
                if sioc_clk = '1' and sioc_clk_prev = '0' then
                    sccb_state <= S_STOP;            -- Go to stop condition state
                end if;
            when S_STOP =>
                if sioc_clk = '1' and sioc_clk_prev = '0' then
                    siod_int <= 'Z';                            -- Release the data line
                    sccb_state <= S_DONE;
                end if;
            when S_DONE =>
                siod_int <= '1';                             -- Release the data line
                Config_finished <= '1';                      -- Indicate that configuration is finished
                if start_reg = '1' then
                    sccb_state <= S_START;                     -- Go back to idle state if start signal is not active
                else
                    sccb_state <= S_IDLE;                      -- Go back to idle state
                end if;
            when others =>
                null;
        end case;
    end if;
end process;
end Behavioral;