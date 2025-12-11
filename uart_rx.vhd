

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_rx is
Generic (
    clk_per_bit : natural := 868); -- its just 100MHz / 115200 (baud rate)
Port (
    clk : IN std_logic;
    rst : IN std_logic;
    rx: IN std_logic;
    data_out : OUT std_logic_vector(7 downto 0);
    data_valid : OUT std_logic);
end uart_rx;

architecture Behavioral of uart_rx is

type state_type is (IDLE, start_bit, data_bit_0, data_bit_1, data_bit_2, data_bit_3, data_bit_4, data_bit_5, data_bit_6, data_bit_7, stop_bit, DONE);
signal state: state_type := IDLE;
signal clk_count : integer := 0;
signal rx_stored : std_logic_vector(7 downto 0) := (others => '0'); -- this is just the rx bits actually stored into a vector and it can get passed onto data out at the end

begin

    clkandrst: process(clk, rst)
        begin
        if (rst = '1') THEN 
            state <= IDLE;
            clk_count <= 0;
            rx_stored <= (others => '0');
            data_valid <= '0';
        elsif (rising_edge(clk)) then 
            data_valid <= '0';       
            Case state is
                when IDLE =>
                    data_valid <= '0';
                    if (rx = '0') THEN 
                        state <= start_bit;
                        clk_count <= 0;
                    else state <= IDLE;
                    end if;
            
                when start_bit =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;                        
                        data_valid <= '0';
                        state <= data_bit_0;
                    end if;
            
                when data_bit_0 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(0) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_1;
                    end if;
            
                when data_bit_1 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(1) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_2;
                    end if;
                   
                when data_bit_2 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(2) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_3;
                    end if;            

                when data_bit_3 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(3) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_4;
                    end if;
                
                when data_bit_4 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(4) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_5;
                    end if;
                    
                when data_bit_5 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(5) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_6;
                    end if;                       

                when data_bit_6 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(6) <= rx;                        
                        data_valid <= '0';
                        state <= data_bit_7;
                    end if;   
                    
                    
                when data_bit_7 =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;
                        rx_stored(7) <= rx;                        
                        data_valid <= '0';
                        state <= stop_bit;
                    end if;   
                    
                when stop_bit =>
                    clk_count <= clk_count + 1;
                    if (clk_count = clk_per_bit-1) then
                        clk_count <= 0;                       
                        data_valid <= '0';
                        state <= DONE;
                    end if;       

                when DONE =>       
                    data_valid <= '1';
                    data_out <= rx_stored;
                    state <= IDLE;
            end case;
        end if;
    end process;            
end behavioral;
