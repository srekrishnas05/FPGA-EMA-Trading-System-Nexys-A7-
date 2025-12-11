import serial
import csv
import time
from datetime import datetime
import statistics
import math

SERIAL_PORT = "COM4"  # use port on ur pc that fpga uses
BAUDRATE = 115200

CSV_FILE = r"C:\Users\sreks\Downloads\Stock CSV DSD FP\rr_intraday-1min_historical-data-12-02-2025.csv"  # change to the path of the stock csv

SEND_DELAY_SEC = 0.0001  

PRICE_SCALE = 100.0          
SHARES_PER_TRADE = 100       

def encode_u16(v: int):
    """Clamp to 0..65535 and return (hi, lo) bytes."""
    v = int(v)
    if v < 0:
        v = 0
    if v > 0xFFFF:
        v = 0xFFFF
    hi = (v >> 8) & 0xFF
    lo = v & 0xFF
    return hi, lo


def decode_status_byte(val: int):
    """
    Decode FPGA status byte according to your current stack:

      bit0 = tick_sig
      bit1 = golden_cross
      bit2 = death_cross
      bit3 = pos_long
      bit4 = pos_short
      bit5 = ema_slow_valid
      bit6 = ema_fast_valid
      bit7 = 0
    """
    tick        = (val & 0b00000001) != 0
    golden      = (val & 0b00000010) != 0
    death       = (val & 0b00000100) != 0
    pos_long    = (val & 0b00001000) != 0
    pos_short   = (val & 0b00010000) != 0
    slow_valid  = (val & 0b00100000) != 0
    fast_valid  = (val & 0b01000000) != 0
    return tick, golden, death, pos_long, pos_short, slow_valid, fast_valid


def main():
    rows = []

    with open(CSV_FILE, "r", newline="") as f:
        reader = csv.DictReader(f)

        for r in reader:
            t_str = r["Time"].strip().replace('"', "")

            if not t_str or "Downloaded from" in t_str:
                continue

            try:
                dt = datetime.strptime(t_str, "%Y-%m-%d %H:%M")
            except ValueError:
                print(f"Skipping row with weird Time value: {t_str!r}")
                continue

            latest_str = r["Latest"].strip()
            try:
                price_f = float(latest_str)
            except ValueError:
                print(f"Skipping row with weird Latest value: {latest_str!r}")
                continue

            price_i = int(price_f * PRICE_SCALE)
            rows.append((dt, price_i))

    if not rows:
        print("No valid data rows found in CSV.")
        return

    rows.sort(key=lambda x: x[0])

    data = []
    for idx, (dt, price_i) in enumerate(rows):
        ts_int = idx
        data.append((ts_int, price_i))

    first_price = data[0][1]
    last_price = data[-1][1]

    print(f"Loaded {len(data)} rows from CSV")

    ser = serial.Serial(
        port=SERIAL_PORT,
        baudrate=BAUDRATE,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.05,
        write_timeout=0.05,
    )

    print(f"Opened {SERIAL_PORT} at {BAUDRATE} baud")

    pos_state = "flat"         
    entry_price = None          
    entry_idx = None
    trades = []                
    trade_returns = []          
    cum_pnl_price_units = 0     

    try:
        for idx, (ts_int, price_int) in enumerate(data):
            ts_hi, ts_lo = encode_u16(ts_int)
            pr_hi, pr_lo = encode_u16(price_int)
            packet = bytes([ts_hi, ts_lo, pr_hi, pr_lo])

            ser.write(packet)

            resp = ser.read(1)
            if not resp:
                continue

            status_val = resp[0]
            tick, golden, death, pos_long_flag, pos_short_flag, slowV, fastV = decode_status_byte(status_val)

            if pos_long_flag and not pos_short_flag:
                fpga_pos = "long"
            elif pos_short_flag and not pos_long_flag:
                fpga_pos = "short"
            elif not pos_long_flag and not pos_short_flag:
                fpga_pos = "flat"
            else:
                fpga_pos = "flat" 

            price_float = price_int / PRICE_SCALE

            if pos_state == "flat" and fpga_pos == "long":
                pos_state = "long"
                entry_price = price_int
                entry_idx = idx

            elif pos_state == "flat" and fpga_pos == "short":
                pos_state = "short"
                entry_price = price_int
                entry_idx = idx

            elif pos_state == "long" and fpga_pos == "flat":
                pnl_per_share = price_int - entry_price           
                trade_pnl_units = pnl_per_share * SHARES_PER_TRADE
                cum_pnl_price_units += trade_pnl_units

                notional_units = entry_price * SHARES_PER_TRADE
                if notional_units != 0:
                    trade_ret = trade_pnl_units / notional_units   
                    trade_returns.append(trade_ret)

                trades.append({
                    "side": "LONG",
                    "shares": SHARES_PER_TRADE,
                    "entry_idx": entry_idx,
                    "exit_idx": idx,
                    "entry_price": entry_price / PRICE_SCALE,
                    "exit_price": price_float,
                    "pnl": trade_pnl_units / PRICE_SCALE,
                })
                pos_state = "flat"
                entry_price = None
                entry_idx = None

            elif pos_state == "short" and fpga_pos == "flat":
                pnl_per_share = entry_price - price_int              
                trade_pnl_units = pnl_per_share * SHARES_PER_TRADE
                cum_pnl_price_units += trade_pnl_units

                notional_units = entry_price * SHARES_PER_TRADE
                if notional_units != 0:
                    trade_ret = trade_pnl_units / notional_units
                    trade_returns.append(trade_ret)

                trades.append({
                    "side": "SHORT",
                    "shares": SHARES_PER_TRADE,
                    "entry_idx": entry_idx,
                    "exit_idx": idx,
                    "entry_price": entry_price / PRICE_SCALE,
                    "exit_price": price_float,
                    "pnl": trade_pnl_units / PRICE_SCALE,
                })
                pos_state = "flat"
                entry_price = None
                entry_idx = None

            if idx % 1000 == 0:
                print(
                    f"ts={ts_int:5d}, price={price_float:6.2f} | "
                    f"pos={fpga_pos:5s} cumPnL={cum_pnl_price_units/PRICE_SCALE:8.2f} "
                    f"(raw=0x{status_val:02X})"
                )

            time.sleep(SEND_DELAY_SEC)

    finally:
        ser.close()
        print("Serial port closed.")

    if pos_state in ("long", "short") and entry_price is not None:
        final_price_int = last_price
        final_price_float = final_price_int / PRICE_SCALE
        if pos_state == "long":
            pnl_per_share = final_price_int - entry_price
            side = "LONG*"
        else:
            pnl_per_share = entry_price - final_price_int
            side = "SHORT*"

        trade_pnl_units = pnl_per_share * SHARES_PER_TRADE
        cum_pnl_price_units += trade_pnl_units

        notional_units = entry_price * SHARES_PER_TRADE
        if notional_units != 0:
            trade_ret = trade_pnl_units / notional_units
            trade_returns.append(trade_ret)

        trades.append({
            "side": side,
            "shares": SHARES_PER_TRADE,
            "entry_idx": entry_idx,
            "exit_idx": len(data) - 1,
            "entry_price": entry_price / PRICE_SCALE,
            "exit_price": final_price_float,
            "pnl": trade_pnl_units / PRICE_SCALE,
        })

    print("\n=== Trade List ===")
    for i, tr in enumerate(trades):
        print(
            f"{i:2d}: {tr['side']:6s}  "
            f"shares={tr['shares']:4d}  "
            f"[{tr['entry_idx']:5d} → {tr['exit_idx']:5d}]  "
            f"{tr['entry_price']:6.2f} → {tr['exit_price']:6.2f}  "
            f"P&L = {tr['pnl']:9.2f}"
        )

    strategy_pnl = cum_pnl_price_units / PRICE_SCALE

    buyhold_pnl = (last_price - first_price) * SHARES_PER_TRADE / PRICE_SCALE
    initial_price_float = first_price / PRICE_SCALE
    initial_capital = initial_price_float * SHARES_PER_TRADE

    if initial_capital != 0:
        strategy_ret = strategy_pnl / initial_capital
        buyhold_ret = buyhold_pnl / initial_capital
        alpha = strategy_ret - buyhold_ret
    else:
        strategy_ret = buyhold_ret = alpha = 0.0

    if len(trade_returns) > 1:
        mean_r = statistics.mean(trade_returns)
        std_r = statistics.stdev(trade_returns)
        sharpe = (mean_r / std_r) * math.sqrt(len(trade_returns))
    else:
        sharpe = float('nan')

    print("\n=== Summary ===")
    print(f"Shares per trade  : {SHARES_PER_TRADE}")
    print(f"Initial price     : {initial_price_float:8.2f}")
    print(f"Final price       : {last_price/PRICE_SCALE:8.2f}")
    print(f"Buy & Hold PnL    : {buyhold_pnl:9.2f}")
    print(f"Strategy PnL      : {strategy_pnl:9.2f}")
    print(f"Buy & Hold Return : {buyhold_ret*100:7.2f}%")
    print(f"Strategy Return   : {strategy_ret*100:7.2f}%")
    print(f"Alpha (pct points): {alpha*100:7.2f}%")
    print(f"Sharpe (per-trade): {sharpe:7.3f}  "
          f"(N={len(trade_returns)} trades with returns)")

if __name__ == "__main__":
    main()