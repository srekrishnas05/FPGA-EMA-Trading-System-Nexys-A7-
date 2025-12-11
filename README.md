# FPGA Trading System
By Sre krishna Subrahamanian

This was my final project for CPE 487 DSD taught by Professor Yett! I'm using this github repo as a method of being able to show off how the system actually runs (from pyserial to the fpga and back to python) along with being able to submit it for credit 😁.

## Demonstration
[![Demonstration](https://img.youtube.com/vi/pj5wCKJ1094/maxresdefault.jpg)](https://youtu.be/pj5wCKJ1094)
[![Trade List](https://img.youtube.com/vi/LAT48-Oe1BA/maxresdefault.jpg)](https://youtu.be/LAT48-Oe1BA)

## Table of Contents
- System Architecture and Overview
- UART and PySerial
- FPGA Packet Retrieval and Assembly
- EMA Core
- Buy/Sell Signal and Long/Short/Flat Position Generator
- Packet Transmission and Python Analysis


## System Architecture and Overview
The goal of this system is inherently simple. Load up historic data of a stock for minute increments over a period of time such as 3 weeks (I got historic data for 15 of the most volatile stocks currently from Barchart. 
I can't put the CSV files in this repo or anywhere online since I needed to get a Barchart subscription to get them and it's against TOS to put them on the internet) and get python to be able to grab the price and a timestamp. From there, it sends the info using UART to the 
FPGA in the format of a timestamp and price. Since you can't just send a timestamp and price (example of timestamp 3542 and stock price 18.23) in just one message, you send each bit of it and FPGA then assembles the packet (hence why you'll see a module called "packet_assembler.vhd"
from which it's now in a usable format for the FPGA. 

With this, you can actually start calculating trajectory and decide whether to buy or sell. The first step is calculating the EMA, or both the EMAs I should say. Before going into how to calculate the EMAs (or why I even have 2 EMAs), we should talk about what an EMA is. 
An EMA, or Exponential Moving Average, is a method to calculate the trajectory of a stock/security. EMAs are a better way to calculate price/trajectory data since they give more importance to how a stock is currently behaving compared to how it was behaving months ago, because
its current behavior is what will dictate its next steps. Here's the formula for EMA. It calculates the EMA by using the EMA calculated for the previous price + ((the new price - previous EMA) / 2 ^ the smoothing ratio). The different alpha is what differentiates EMA slow and fast since it changes how they react. My fast EMA uses 2^3 and my slow EMA uses 2^4. 
<img width="544" height="192" alt="image" src="https://github.com/user-attachments/assets/bcf89054-f0cb-4c3c-9d09-76b143c4e6e9" />

The two EMAs work in conjunction to determine the trajectory of the stock. If fast > slow, then the stock is bullish or has a tendency to appreciate. If the inverse is true, then the stock is bearish and is moving downwards. The points at which both EMA functions intersect are
the golden and death crosses. Golden when fast > slow after and death when opposite is true. 

The FPGA uses these crosses and difference of EMA value to generate signals on buying, selling, and holding. When the stock is showing to be bearish, the FPGA continues to calculate EMAs until the slow EMA will overtake the fast EMA, and when that occurs, it generates a sell order.
When the stock is in a flat position, neither short nor long, the FPGA continues to calculate until it can determine the right position to stay in and the respective buying and selling order. My design uses FSMs that point from one state to another based on the calculations
that it detects.

Finally once the stock has had a buy or sell signal generated, the FPGA is responsible to return this info back to python. Using UART, the FPGA sends back info to python in which some code compiles the results (both in real-time every 1000 timestamped stock changes and at the end 
to show cumulative results) all through command prompt. Here's a diagram of what the whole system looks like start to finish. 

<img width="456" height="376" alt="image" src="https://github.com/user-attachments/assets/6b1bd382-dd9c-4f96-ab5f-0ab348528b63" />

## UART and PySerial / FPGA Packet Retrieval and Assembly
The first thing we need to do is get the stock data from python. I use these commands to go through the CSV file and get the latest price and associated time. Essentially all it's doing is just grabbing the value under time and latest and "prepping" it to be sent to FPGA. 

<img width="622" height="520" alt="image" src="https://github.com/user-attachments/assets/c3aa5164-0575-40c0-bc66-f86221ac7c63" />

From there, we have to understand how UART works before going further into the FPGA architecture. UART works by sending 8 bit "frames" surrounded by 1 start and stop bit. Usually RX is tied to 1, so when RX goes to 0, that's the queue that a frame is going to be incoming. 
The start bit is 0. The frame of 8 bits is sent, and the FPGA captures each bit and places it into an 8 bit slice of a sixteen bit vector that's for either timestamp or price. Following that, once all 32 bits are filled, the packet assembler has completed its job. 

I'm using an FSM to actually capture this. There's 12 states, 1 idle, 1 start state, 8 bit states, 1 stop state, and 1 done state. The FSM essentially repeats itself 4 times to fill up the 32 bit vector that gets generated with timestamp and price. 
<img width="448" height="414" alt="image" src="https://github.com/user-attachments/assets/c410abb8-2247-48fd-a77e-44ff94576be4" />

<img width="316" height="148" alt="image" src="https://github.com/user-attachments/assets/e107273c-86f3-4853-a043-202fa2000a19" />

7 more times then

<img width="310" height="216" alt="image" src="https://github.com/user-attachments/assets/2009f6f3-3d67-41ea-aff7-f200539c961a" />

Now that 8 bits have been stored, we can receive the next uart frame. A VERY KEY point of all this is it MUST happen within a clock cycle. Now what does this mean. FPGA is running at 100 MHz and Python is sending at 115200 baud rate. This gives us roughly 868 clocks per bit 
to work inside of. "clk_count" is essentially just a counter and when it gets to 867 is when everything can execute, in order to ensure it's matching with the recieving bits from python at that baud rate. This 868 clock is very crucial to the project actually working,
since beyond simulations on hardware, everything runs based on the clock cycles.

Packet assembly is really simple. Every 8 bits that go in, out of an FSM with four bit filling states, it fills half portions of each 16 bit vector leaving it in a 32 bit vector that the FPGA can use for everything after.

## EMA Core
Lets go a little deeper into how EMA works. 

<img width="1288" height="643" alt="image" src="https://github.com/user-attachments/assets/b8bcf21c-a5a2-4cfc-8eab-ab0ff4b47c42" />

When the fast EMA is > than the short EMA then it signifies the stock is bullish. The point at which EMA fast overtakes slow is the golden cross. Inversely, when EMA slow overtakes fast, that signifies the death cross. The EMA equation was also as follows as mentioned
above. Let's go in order of how the FPGA really processes everything. 

First off, we need the 16 bits representing price in the 32 bit assembled vector. From there, we want to make sure the number is accurate enough to detect changes which makes EMAs more accurate. We use Q24.8 arithmetic. Essentially out of a 32 bit long number, 
the first 24 are integers and the last 8 are decimal. Since our incoming price is 16 bits, we use this command to "resize it" to 32 bits in Q24.8 format. When "tick_sig" = '1' then it signifies a full packet has been assembled and only then can we start calculating EMA math.

~~~
v_price_ext := shift_left(resize(signed(price_sig), 32), 8); 
~~~

On the first sample, EMA is just the 32 bit price, but following that, the calculation can start to be processed. Here's the process to calculate:

~~~
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
~~~

Diff is Pn - EMAn-1. Delta is dividing that by 16 (16 since 2^4 and this is ema_slow). New EMA is just the old EMA + delta. 

## Buy/Sell Signal and Long/Short/Flat Position Generator
Now that we have a working EMA calculation, we can move on to identifying crosses. The way I chose to do this is within another module and setting up a signal diff_prev and variable (better than signal since it updates immediately) diff_now. diff_now is set as ema fast - ema slow and diff now's value gets passed on to diff prev. Let's talk about why using a variable is super crucial here. Variables update their value the second a statement is asserted while a signal updates at the end of the clock cycle. By using this setup of one variable and one signal, within one clock cycle we can use the diff now value and diff prev value. 

~~~
-- golden cross is when diff_prev </= to 0 and diff_now > 0
-- death cross is when diff_prev >/= 0 and diff_now < 0
if (diff_prev <= to_signed(0, diff_prev'length) AND diff_now > to_signed(0, diff_now'length)) then
            golden_cross <= '1';
elsif (diff_prev >= to_signed(0, diff_prev'length) AND diff_now < to_signed(0, diff_now'length)) then
            death_cross <= '1';
end if;
~~~

Big part of this is the syntax in comparing. We need the to_signed(0, diff_prev'length) and to_signed(0, diff_now'length) for the FPGA to compile it correctly since it's signed number compared to 0. But we can get the cross detection from this.

Now to generate positions, we need an FSM with states long, flat, short. I included take-profit and stop-loss to ensure that it doesn't run a risk of losing more than it needs to or losing potential gains. The way I set this up was using three integers. Scale_bps was 10000, stop was 150, and take 1as 650. 150/10000 is 1.5% and 650/10000 is 6.5%, decent numbers for take and stop. 

Here is the code to how the logic works behind this. 

~~~
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
~~~

The beginning case is flat and when it detects a golden cross it goes to long and if death cross it goes to short. It calculates stop and take based on that price and when price meets either it sells (if long or buys if short). Otherwise if it detects an opposing cross then it switches states to flat and waits for a new cross to shift on to.

## Packet Transmission and Python Analysis
For my uart_tx file (essentially rx but reversed to sent info back to python) it's a very similar process. However in all the learning I had in this beautiful very high speed integrated circuit hardware description language, I realized I only needed four states: idle, start, data_bits (plural for a reason), and a stop bit. 

~~~
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
~~~


I can just index the bits and drop it into the corresponding spot in the 8 bit vector.

Finally, in my top module, I just set signals of what I want to see transmitted.

~~~
trade_byte_reg(0) <= tick_sig;
trade_byte_reg(1) <= golden_sig;
trade_byte_reg(2) <= death_sig;
trade_byte_reg(3) <= pos_long_sig;
trade_byte_reg(4) <= pos_short_sig;
trade_byte_reg(5) <= ema_slow_valid_sig;
trade_byte_reg(6) <= ema_fast_valid_sig;
trade_byte_reg(7) <= '0';
~~~

Essentially these are the signals I'm sending to python. I had my previous code in python set up to display these signals at each timestamp and price in command prompt to debug to make sure trades were being executed, but now I have it setup to just run through the cmd prompt, make a list of all trades generated, and show final statements. 

A bit of technical analysis on my project showed the following. My alpha was 363.71%, my strategy return (the return from using this EMA) was 642.74%, and I had a sharpe ratio of around 0.6. What does this mean? Alpha is a measure of how your strategy performed against a benchmark. Essentially I did 3.64 times better than the benchmark. My returns were about 6.4x my investment, again really good! I had a sharpe ratio of around 0.6, not so good :(. Part of the reason for this is the risk I take on to take it. Sharpe also has a tendency to be lower in smaller timeframes, however, a shortcoming of my project is that I didn't measure risk, rather full-ported every buy opportunity. Essentially this isn't good, you want flexibility to be able to minimize losses and maximize gains. While my gains were maximized every time I made money, my loses were too, since it was the same amount of shares both times. However, there will be updates soon on this, it will be better!
