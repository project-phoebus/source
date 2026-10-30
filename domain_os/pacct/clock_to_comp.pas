{ pacct_$clock_to_comp - a 48-bit clock in accounting ticks, compressed.

  Image addresses:
    sau2  0x00E5AA28  pacct_$clock_to_comp (module-local)

  - The clock divided by 4167 in two steps (the high longword, then the
    remainder with the low word), compressed by pacct_$compress.

  Status stored: none.
}

function pacct_$clock_to_comp(clock: time_$clock_t): comp_t; internal;
var
  combined: linteger;
begin
  combined := lshft(clock.high div pacct_tick_divisor, 16)
              + (lshft(clock.high mod pacct_tick_divisor, 16) + clock.low)
                div pacct_tick_divisor;

  pacct_$clock_to_comp := pacct_$compress(combined);
end;
