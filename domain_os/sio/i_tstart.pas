{ SIO_$I_TSTART - start or continue the transmission of a serial line.

  Image addresses:
    sau2  0x00E1C7A8  SIO_$I_TSTART
    sau4  0x0F81D9BC  SIO_$I_TSTART

  - Nothing is sent while a state member 0..4 is set; a pending
    handshake sends XOFF (16#13) or XON (16#11).
  - Else the next character: 16#FE then 0 delays by the next two bytes'
    milliseconds (TIME_$Q_ADD_CALLBACK, SIO_DELAY_RESTART, run at once
    if not queued), 16#FE then another byte sends that byte.
  - With exactly 16 or no characters left the drain handler is called.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_tstart(desc: sio_$desc_ptr_t);
  options(val_param);
var
  zero_interval: static time_$clock_t := [high := 0, low := 0];
                                          { WIRED_DATA +0x0, then the
                                            block's 2 bytes of rounding }
  cell: sio_$desc_ptr_t;
  now: time_$clock_t;
  delay: time_$clock_t;
  status: status_$t;
  txbuf: sio_$txbuf_ptr_t;
  pos: integer;
  ch: char;
  i: integer;
  pending: integer;
begin
  { transmitting, blocked, inhibited, a break or
    a delay }
  if desc^.state * [0..4] <> [] then
    return;

  { the XON/XOFF handshake }
  if desc^.state * [5, 6] <> [] then begin
    if 6 in desc^.state then begin
      sio_$output_char_t(desc^.driver.output_char)^(desc^.context,
                                                    chr(16#13));
      desc^.state := desc^.state + [7];
      desc^.state := desc^.state - [6];
    end
    else begin
      sio_$output_char_t(desc^.driver.output_char)^(desc^.context,
                                                    chr(16#11));
      desc^.state := desc^.state - [5, 7];
    end;
    return;
  end;

  { the next character }
  txbuf := desc^.txbuf;
  pos := txbuf^.head;
  if pos = txbuf^.tail then
    return;
  desc^.state := desc^.state + [0];
  ch := txbuf^.data[pos];
  if pos = txbuf^.size then
    txbuf^.head := 1
  else
    txbuf^.head := txbuf^.head + 1;

  { the escape }
  if ch = chr(16#FE) then begin
    pos := txbuf^.head;
    ch := txbuf^.data[pos];
    if pos = txbuf^.size then
      txbuf^.head := 1
    else
      txbuf^.head := txbuf^.head + 1;

    if ch = chr(0) then begin
      { the delay, two bytes of milliseconds }
      delay.high := 0;
      delay.low := 0;
      for i := 1 to 2 do begin
        pos := txbuf^.head;
        delay.low32 := lshft(delay.low32, 8) + ord(txbuf^.data[pos]);
        if pos = txbuf^.size then
          txbuf^.head := 1
        else
          txbuf^.head := txbuf^.head + 1;
      end;
      delay.low32 := delay.low32 * 250;

      { the delay queued }
      desc^.state := desc^.state - [0] + [4];
      time_$abs_clock(now);
      time_$q_add_callback(time_$rteq, delay, time_$relative, now,
                           addr(sio_delay_restart), desc, [3],
                           zero_interval, desc^.delay_qelem, status);

      { not queued, so restart at once }
      if status.all <> status_$ok then begin
        cell := desc;
        sio_delay_restart(addr(cell));
      end;
      return;
    end;
  end;

  { an ordinary character }
  sio_$output_char_t(desc^.driver.output_char)^(desc^.context, ch);

  { the writer woken at 16 or none left }
  pending := txbuf^.tail - txbuf^.head;
  if pending < 0 then
    pending := pending + txbuf^.size;
  if (pending = 16#10) or else (pending = 0) then
    sio_$owner_proc_t(desc^.handlers.drain_handler)^(desc^.owner);
end;
