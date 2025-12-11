----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/08/2025 12:30:22 AM
-- Design Name: 
-- Module Name: uart_tx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_tx is
generic (
    clk_per_bit : natural := 868
    );
port (
    clk : in std_logic;
    rst : in std_logic;
    tx_start : in std_logic;
    tx_data : in std_logic_vector(7 downto 0);
    tx : out std_logic;
    tx_busy : out std_logic
    );    
end uart_tx;

architecture Behavioral of uart_tx is
type state_type is (idle, start_bit, data_bits, stop_bit);
signal state : state_type := idle;
signal clk_count : integer := 0;
signal bit_index : integer range 0 to 7 := 0;
signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
signal tx_reg : std_logic := '1';
signal busy_reg : std_logic := '0';
begin
process(clk, rst)
begin
    if (rst = '1') then
        state <= idle;
        clk_count <= 0;
        bit_index <=  0;
        shift_reg <= (others => '0');
        tx_reg <= '1';
        busy_reg <= '0';
    elsif (rising_edge(clk)) then
        case state is 
            when idle =>
                tx_reg <= '1';
                busy_reg <= '0';
                clk_count <= 0;
                bit_index <= 0;
                
                if (tx_start = '1') then
                    shift_reg <= tx_data;
                    busy_reg <= '1';
                    state <= start_bit;
                end if;
            when start_bit =>
                tx_reg <= '0';
                if (clk_count = clk_per_bit - 1) then
                    clk_count <= 0;
                    state <= data_bits;
                    bit_index <= 0;
                else 
                    clk_count <= clk_count + 1;
                end if;
            when data_bits =>
                tx_reg <= shift_reg(bit_index);
                if (clk_count = clk_per_bit - 1) then
                    clk_count <= 0;
                    if (bit_index = 7) then
                        state <= stop_bit;
                    else 
                        bit_index <= bit_index + 1;
                    end if;
                else 
                    clk_count <= clk_count + 1;
                end if;
            when stop_bit =>
                tx_reg <= '1';
                if (clk_count = clk_per_bit - 1) then
                    clk_count <= 0;
                    state <= idle;
                else 
                    clk_count <= clk_count + 1;
                end if;    
        end case;
    end if;                             
end process;
tx <= tx_reg;
tx_busy <= busy_reg;
end Behavioral;








