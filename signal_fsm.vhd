----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/07/2025 04:06:46 PM
-- Design Name: 
-- Module Name: signal_fsm - Behavioral
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

entity signal_fsm is
generic (
    stop_bps : integer := 150;
    take_bps : integer := 650;
    scale_bps : integer := 10000
);
port (
    clk : in std_logic;
    rst : in std_logic;
    tick_sig : in std_logic;
    price_sig : in std_logic_vector(15 downto 0);
    golden_cross : in std_logic;
    death_cross : in std_logic;
    buy_sig : out std_logic;
    sell_sig : out std_logic;
    pos_long : out std_logic;
    pos_short : out std_logic
);
    
end signal_fsm;

architecture Behavioral of signal_fsm is
type state_type is (flat, long, short);
signal state_reg : state_type := flat;
signal entry_price_reg : unsigned(15 downto 0) := (others => '0');
signal buy_reg : std_logic := '0';
signal sell_reg : std_logic := '0';
signal pos_long_r : std_logic := '0';
signal pos_short_r : std_logic := '0';

begin
process(clk, rst)
    variable current_price : integer;
    variable entry_price : integer;
    variable stop_level : integer;
    variable take_level : integer;
begin
    if (rst = '1') then
        state_reg <= flat;
        entry_price_reg <= (others => '0');
        buy_reg <= '0';
        sell_reg <= '0';
        pos_long_r <= '0';
        pos_short_r <= '0';
    elsif (rising_edge(clk)) then
        buy_reg <= '0';
        sell_reg <= '0';
        
        case state_reg is
            when flat =>
                pos_long_r <= '0';
                pos_short_r <= '0';
            when long =>
                pos_long_r <= '1';
                pos_short_r <= '0';
            when short =>
                pos_long_r <= '0';
                pos_short_r <= '1';
        end case;
        
        if (tick_sig = '1') then
            current_price := to_integer(unsigned(price_sig));
            entry_price := to_integer(entry_price_reg);
            
            case state_reg is
                when flat =>
                    if (golden_cross = '1') then
                        state_reg <= long;
                        buy_reg <= '1';
                        entry_price_reg <= unsigned(price_sig);
                    elsif (death_cross = '1') then
                        state_reg <= short;
                        sell_reg <= '1';
                        entry_price_reg <= unsigned(price_sig);                
                    end if;
               
                when long =>
                    stop_level := (entry_price * (scale_bps - stop_bps)) / scale_bps;
                    take_level := (entry_price * (scale_bps + take_bps)) / scale_bps;                   
                    if (current_price <= stop_level) then
                        state_reg <= flat;
                        sell_reg <= '1';
                    elsif (current_price >= take_level) then
                        state_reg <= flat;
                        sell_reg <= '1';
                    elsif (death_cross = '1') then 
                        state_reg <= flat;
                        sell_reg <= '1';
                    end if;
                
                when short => 
                    stop_level := (entry_price * (scale_bps + stop_bps)) / scale_bps;
                    take_level := (entry_price * (scale_bps - take_bps)) / scale_bps;     
                    if (current_price >= stop_level) then
                        state_reg <= flat;
                        buy_reg <= '1';
                    elsif (current_price <= take_level) then
                        state_reg <= flat;
                        buy_reg <= '1';
                    elsif (golden_cross = '1') then
                        state_reg <= flat;
                        buy_reg <= '1';
                    end if;
            end case;            
        end if;
    end if;
end process;
buy_sig <= buy_reg;
sell_sig <= sell_reg;
pos_long <= pos_long_r;
pos_short <= pos_short_r;
end Behavioral;


















