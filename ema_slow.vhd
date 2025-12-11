----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/05/2025 09:25:16 PM
-- Design Name: 
-- Module Name: ema_slow - Behavioral
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

entity ema_slow is
port(
    clk : in std_logic;
    rst : in std_logic;
    price_sig : in std_logic_vector(15 downto 0);
    tick_sig :  std_logic;
    
    ema_slow_out : out std_logic_vector(31 downto 0);
    ema_slow_valid : out std_logic
);
end ema_slow;

architecture Behavioral of ema_slow is
signal ema_reg : signed(31 downto 0);
signal first_sample : std_logic := '1';

begin
process(clk, rst)
variable v_price_ext : signed(31 downto 0);
variable v_diff : signed(31 downto 0);
variable v_delta : signed(31 downto 0);
begin
    if (rst = '1') then
        ema_reg <= (others => '0');
        first_sample <= '1';
        ema_slow_valid <= '0';
    
    elsif (rising_edge(clk)) then
        ema_slow_valid <= '0';
        
        if (tick_sig = '1') then
            v_price_ext := shift_left(resize(signed(price_sig), 32), 8);
                if (first_sample = '1') then
                    ema_reg <= v_price_ext;
                    first_sample <= '0';
                else 
                    v_diff := v_price_ext - ema_reg;
                    v_delta := shift_right(v_diff, 4);
                    ema_reg <= ema_reg + v_delta;
                end if;
                ema_slow_valid <= '1';
        end if;                                             
    end if;
end process;
ema_slow_out <= std_logic_vector(ema_reg);
end Behavioral;






