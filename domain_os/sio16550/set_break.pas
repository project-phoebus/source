{ SIO16550_$SET_BREAK - start or stop a break on a channel.

  Image addresses:
    sau9  0x3C41FF0E  SIO16550_$SET_BREAK

  - Under the driver's spin lock the line control's break bit takes
    enable; a stopped break restarts the line's output (SIO_$I_TSTART).

  Status stored: none.
}

procedure sio16550_$set_break(in chan: sio16550_$chan_t; enable: boolean);
  options(val_param);
var
  lcr: sio16550_$lcr_t;
  token: integer;
begin
  token := ml_$spin_lock(spin_lock);
  lcr.c := chan.regs^.lcr;
  lcr.brk := enable;
  chan.regs^.lcr := lcr.c;
  if not enable then
    sio_$i_tstart(chan.sio_desc);
  ml_$spin_unlock(spin_lock, token);
end;
