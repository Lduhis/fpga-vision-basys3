library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.register_address_gen_pkg.all; 


entity ov7670_controller is
Port(Clk_25MHz          : in std_logic;
    Resend              : in std_logic;
    Siod                : inout std_logic;
    Sioc                : out std_logic;
    Config_finished     : out std_logic;
    Reset               : out std_logic;
    Pwdn                : out std_logic);
end ov7670_controller;

architecture Behavioral of ov7670_controller is

type state_type is (IDLE, START, SEND_BIT, WAIT_ACK, STOP, DONE);
signal state : state_type := IDLE;

signal bit_count : integer range 0 to 7 := 0;
signal config_index : integer range 0 to ov7670_regs_array'length-1 := 0;
signal send_byte_index : integer range 0 to 2 := 0;
signal current_command : std_logic_vector(23 downto 0);
signal scl_int : std_logic := '1';
signal sda_int : std_logic := '1';
signal ack_bit : std_logic;

signal clk_div_cnt : integer range 0 to 32; 

signal retry_cnt : integer range 0 to 3 := 0;
signal error_flag : std_logic := '0';

begin
--SIOC CLOCK PROCESS
process(Clk_25MHz) 
begin
    if rising_edge(Clk_25MHz) then
        if clk_div_cnt = 32 then
            clk_div_cnt <= 0;
            scl_int <= not scl_int;
        else
            clk_div_cnt <= clk_div_cnt + 1;
        end if;
    end if;
end process;
--MAIN PROCESS
process(Clk_25MHz)
begin
    if rising_edge(Clk_25MHz) then
        case state is 
            when IDLE =>
                sda_int     <= '1';
                retry_cnt <= 0;
                error_flag <= '0';
                if Resend = '1' then
                    config_index <= 0;
                    send_byte_index <= 0;
                    bit_count <= 7;
                    Config_finished <= '0';
                    current_command <= ov7670_regs_array(0);
                    state <= START;
                end if;
                
            when START =>
                sda_int         <= '0';
                bit_count       <= 7;
                state           <= SEND_BIT;

            when SEND_BIT =>
                if scl_int = '0' then
                    sda_int <= current_command(23 - send_byte_index*8 - bit_count);
                elsif scl_int = '1' then
                    if bit_count = 0 then
                        state <= WAIT_ACK;
                    else
                        bit_count <= bit_count - 1;
                    end if;
                end if;

            when WAIT_ACK =>
                -- Release SDA for ACK
                sda_int <= 'Z'; 
                if scl_int = '1' then
                    ack_bit <= Siod;
                    if ack_bit = '0' then
                        retry_cnt <= 0;
                        if send_byte_index = 2 then
                            state <= STOP;
                        else
                            send_byte_index <= send_byte_index + 1;
                            bit_count <= 7;
                            state <= SEND_BIT;
                        end if;
                    else
                        if retry_cnt < 3 then
                            retry_cnt <= retry_cnt + 1;
                            bit_count <= 7;
                            state <= SEND_BIT; -- Retry sending the byte
                        else
                            error_flag <= '1'; -- Error: No ACK received after retries
                            state <= STOP; 
                        end if;
                    end if;
                end if;

            when STOP =>
                if scl_int = '0' then
                    sda_int <= '0';
                elsif scl_int = '1' then
                    sda_int <= '1';
                    if error_flag = '1' then
                        Config_finished <= '0'; -- Indicate error in configuration
                        state <= DONE;
                    elsif config_index = ov7670_regs_array'length - 1 then
                        Config_finished <= '1'; -- All commands sent successfully
                        state <= DONE;
                    else
                        config_index <= config_index + 1;
                        current_command <= ov7670_regs_array(config_index + 1);
                        send_byte_index <= 0;
                        bit_count <= 7;
                        error_flag <= '0';
                        state <= START;
                    end if;
                end if;

            when DONE =>
                Config_finished <= '1';
                state <= IDLE;

            when others =>
                state <= IDLE;
        end case;
    end if;
end process;
Sioc <= scl_int;
Siod <= sda_int when sda_int /= 'Z' else 'Z';
end Behavioral;
