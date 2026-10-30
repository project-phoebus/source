{ SIO16550_$SET_LINE - set a channel's line parameters.

  Image addresses:
    sau9  0x3C41FDD4  SIO16550_$SET_LINE
    sau9  0x3C41FD70  set_baud (nested)

  - Under the driver's spin lock.
  - change_mask selects the speed (members 0, 1), the format (2 parity,
    3 stop bits, 4 size) and the modem outputs (5 RTS, 6 DTR).
  - A speed above the table's last, or one the divisor does not serve,
    is ignored; the transmit rate sets the divisor.
  - The character size goes through wls_codes, by the size's code.

  Status stored:
    status_$ok: always
}

procedure sio16550_$set_line(var chan: sio16550_$chan_t;
                             in params: sio_$params_t;
                             change_mask: sio_$flags_t;
                             out status: status_$t);
  options(val_param);
var
  rates: sio_$rates_t;
  mcr: sio16550_$mcr_t;
  lcr: sio16550_$lcr_t;
  token: integer;
  regs: sio16550_$regs_ptr_t;

  { set_baud - load the divisor latch for the transmit rate.

    The divisor is (16 * rate + TIME_$SYS_FREQ) div (32 * rate).  It
    reads the parent's rates and chan; the parent calls it with no
    link, so it reaches them through its dynamic link. }

  procedure set_baud;
  var
    latch_lcr: sio16550_$lcr_t;
    divisor: sio16550_$divisor_t;
    latch_regs: sio16550_$regs_ptr_t;
  begin
    divisor.w := (baud_rates[rates.tx] * 16 + time_$sys_freq)
                 div (baud_rates[rates.tx] * 32);
    latch_regs := chan.regs;
    latch_lcr.c := latch_regs^.lcr;
    latch_lcr.dlab := true;
    latch_regs^.lcr := latch_lcr.c;
    latch_regs^.rbr_thr := divisor.lo;
    latch_regs^.ier := divisor.hi;
    latch_lcr.dlab := false;
    latch_regs^.lcr := latch_lcr.c;
  end;

begin
  status.all := status_$ok;
  token := ml_$spin_lock(spin_lock);
  chan.chan_flags := chan.chan_flags - [0];
  regs := chan.regs;

  { the speed }
  if change_mask * [0, 1] <> [] then begin
    rates := params.baud_rate;
    if (rates.tx <= 16) and then (rates.rx <= 16)
       and then (rates.tx in rate_ok) then
      set_baud;
  end;

  { the character format }
  if change_mask * [2, 3, 4] <> [] then begin
    lcr.c := regs^.lcr;
    if 2 in change_mask then
      if params.parity = sio_$no_parity then
        lcr.pen := false
      else begin
        lcr.pen := true;
        lcr.eps := params.parity = sio_$even_parity;
      end;
    if 3 in change_mask then
      lcr.stb := params.stop_bits <> sio_$stop_1;
    if 4 in change_mask then
      case params.char_size of
        sio_$5bpc, sio_$7bpc, sio_$8bpc, sio_$6bpc: begin
          lcr.wls := wls_codes[params.char_size];
        end;
      end;
    regs^.lcr := lcr.c;
  end;

  { the modem outputs }
  if change_mask * [5, 6] <> [] then begin
    mcr.c := regs^.mcr;
    if 5 in change_mask then
      mcr.rts := 0 in params.flags1;
    if 6 in change_mask then
      mcr.dtr := 3 in params.flags1;
    regs^.mcr := mcr.c;
  end;

  ml_$spin_unlock(spin_lock, token);
end;
