----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/06/2025 01:33:50 AM
-- Design Name: 
-- Module Name: cross_detector - Behavioral
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

entity cross_detector is
Port (
    clk : in std_logic;
    rst : in std_logic;
    tick_sig : in std_logic;
    ema_fast : in std_logic_vector(31 downto 0);
    ema_slow : in std_logic_vector(31 downto 0);
    golden_cross : out std_logic;
    death_cross : out std_logic
    );
end cross_detector;

architecture Behavioral of cross_detector is
signal diff_prev : signed(31 downto 0);
signal first_tick : std_logic := '1';
-- golden cross is when diff_prev </= to 0 and diff_now > 0
-- death cross is when diff_prev >/= 0 and diff_now < 0

begin
process(clk, rst)
    variable diff_now : signed(31 downto 0);
begin    
    if (rst = '1') then 
        diff_prev <= (others => '0');
        first_tick <= '1';
        golden_cross <= '0';
        death_cross <= '0';
        
    elsif (rising_edge(clk)) then
        if (tick_sig = '1') then 
            golden_cross <= '0';
            death_cross <= '0';
            diff_now := (signed(ema_fast) - signed(ema_slow)); 
-- when ema fast is > slow trend is bullish and if fast < slow then bearish. u can just do fast - slow and based on value u can determine bull/bear
            
            if (first_tick = '1') then
                diff_prev <= diff_now;
                first_tick <= '0';
            else 
                if (diff_prev <= to_signed(0, diff_prev'length) AND diff_now > to_signed(0, diff_now'length)) then
                    golden_cross <= '1';
                elsif (diff_prev >= to_signed(0, diff_prev'length) AND diff_now < to_signed(0, diff_now'length)) then
                    death_cross <= '1';
                end if;
            diff_prev <= diff_now;
            end if;    
        end if;        
    end if;   
end process;     
end Behavioral;







