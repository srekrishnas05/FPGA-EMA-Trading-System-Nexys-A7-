----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/25/2025 03:24:13 PM
-- Design Name: 
-- Module Name: uart - Behavioral
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

entity uart is
    Port (
    clk : IN std_logic;
    rst : IN std_logic;
    rx: IN std_logic;
    tx: OUT std_logic;
    LED : OUT std_logic_vector(15 downto 0));
end uart;

architecture Behavioral of uart is
signal rx_byte : std_logic_vector(7 downto 0);
signal rx_valid : std_logic;
signal rx_led_reg: std_logic := '0';
signal byte_led : std_logic := '0';
signal ts_sig : std_logic_vector(15 downto 0);
signal price_sig : std_logic_vector(15 downto 0);
signal tick_sig : std_logic;
signal counter : unsigned(25 downto 0) := (others => '0');
signal show_ts : std_logic := '0';
signal ema_slow_sig : std_logic_vector(31 downto 0);
signal ema_slow_valid_sig : std_logic;
signal ema_fast_sig : std_logic_vector(31 downto 0);
signal ema_fast_valid_sig : std_logic;
signal golden_sig : std_logic;
signal death_sig : std_logic;
signal buy_sig : std_logic;
signal sell_sig : std_logic;
signal pos_long_sig : std_logic;
signal pos_short_sig : std_logic;
signal tx_data_sig : std_logic_vector(7 downto 0);
signal tx_start_sig : std_logic := '0';
signal tx_busy_sig : std_logic;
signal trade_byte_reg : std_logic_vector(7 downto 0) := (others => '0');

begin
uart_rx_inst : entity work.uart_rx
    generic map (
        clk_per_bit => 868
    )
    port map (
    clk => clk,
    rst => '0',
    rx => rx,
    data_out => rx_byte,
    data_valid => rx_valid
    );
packetassembler_inst : entity work.packetassembler
    port map (
    clk => clk,
    rst => '0',
    rx_byte => rx_byte,
    rx_valid => rx_valid,
    timestamp_out => ts_sig,
    price_out => price_sig,
    tick_valid => tick_sig
    );
emaslow_inst : entity work.ema_slow
    port map (
    clk => clk,
    rst => '0',
    tick_sig => tick_sig,
    price_sig => price_sig,
    ema_slow_out => ema_slow_sig,
    ema_slow_valid => ema_slow_valid_sig
    );
emafast_inst : entity work.ema_fast
    port map (
    clk => clk,
    rst => '0',
    tick_sig => tick_sig,
    price_sig => price_sig,
    ema_fast_out => ema_fast_sig,
    ema_fast_valid => ema_fast_valid_sig
    );
crossdetector_inst : entity work.cross_detector
    port map (
    clk => clk,
    rst => '0',
    tick_sig => tick_sig,
    ema_fast => ema_fast_sig,
    ema_slow => ema_slow_sig,
    golden_cross => golden_sig,
    death_cross => death_sig
    );
signalfsm : entity work.signal_fsm
    port map (
    clk => clk,
    rst => '0',
    tick_sig => tick_sig,
    price_sig => price_sig,
    golden_cross => golden_sig,
    death_cross => death_sig,
    buy_sig => buy_sig,  
    sell_sig => sell_sig,
    pos_long => pos_long_sig,
    pos_short => pos_short_sig
    );
uart_tx_inst : entity work.uart_tx
    port map (
    clk => clk,
    rst => '0',
    tx_start => tx_start_sig,
    tx_data => tx_data_sig,
    tx => tx,
    tx_busy => tx_busy_sig
    );     
process (clk)
begin
    if (rising_edge(clk)) then
    tx_start_sig <= '0';
    
        if ((tick_sig = '1') and (tx_busy_sig = '0')) then 
        -- this is bit layout 
        -- bit0 is buy_sig
        -- bit1 is sell
        -- bit2 is pos_long
        -- bit3 is pos_short
        -- bits 7,6,5,4 aren't used right now but are versatile i guess
            trade_byte_reg(0) <= tick_sig;
            trade_byte_reg(1) <= golden_sig;
            trade_byte_reg(2) <= death_sig;
            trade_byte_reg(3) <= pos_long_sig;
            trade_byte_reg(4) <= pos_short_sig;
            trade_byte_reg(5) <= ema_slow_valid_sig;
            trade_byte_reg(6) <= ema_fast_valid_sig;
            trade_byte_reg(7) <= '0';
           -- trade_byte_reg(7 downto 5) <= (others => '0');
            tx_start_sig <= '1';
        end if;        
    end if;
end process;
tx_data_sig <= trade_byte_reg;
end behavioral;
