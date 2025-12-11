----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/03/2025 12:27:22 AM
-- Design Name: 
-- Module Name: packetassembler - Behavioral
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
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity packetassembler is
Port (
    clk : IN std_logic;
    rst : IN std_logic;
    rx_valid : IN std_logic;
    rx_byte : IN std_logic_vector(7 downto 0);
    
    timestamp_out : out std_logic_vector(15 downto 0);
    price_out : out std_logic_vector(15 downto 0);
    tick_valid : out std_logic
    );

end packetassembler;

architecture Behavioral of packetassembler is
signal byte_count : unsigned(1 downto 0);
signal ts_reg : std_logic_vector(15 downto 0);
signal price_reg : std_logic_vector(15 downto 0);
signal ts_out_reg : std_logic_vector(15 downto 0);
signal price_out_reg : std_logic_vector(15 downto 0);
begin
process(clk, rst)
begin
if (rst = '1') then
    byte_count <= (others => '0');
    ts_reg <= (others => '0');
    price_reg <= (others => '0');
    ts_out_reg <= (others => '0');
    price_out_reg <= (others => '0');
    tick_valid <= '0';

elsif (rising_edge(clk)) then 
    tick_valid <= '0';
    
    if (rx_valid = '1') then
        case byte_count is
            when "00" =>
                ts_reg(15 downto 8) <= rx_byte;
                byte_count <= "01"; 
            when "01" =>
                ts_reg(7 downto 0) <= rx_byte;
                byte_count <= "10";
            when "10" =>
                price_reg(15 downto 8) <= rx_byte;
                byte_count <= "11";
            when "11" =>
                price_reg(7 downto 0) <= rx_byte;
                tick_valid <= '1';
                byte_count <= "00";
        end case; 
    end if;            
end if;
end process;
timestamp_out <= ts_reg;
price_out <= price_reg;
end Behavioral;

























