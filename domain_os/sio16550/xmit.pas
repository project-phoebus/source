{ SIO16550_$XMIT - send a character on a channel.

  Image addresses:
    sau9  0x3C41FC28  SIO16550_$XMIT

  - The character goes to the transmit holding register; the transmit
    interrupt is enabled if it is not.

  Status stored: none.
}

procedure sio16550_$xmit(in chan: sio16550_$chan_t; ch: char);
  options(val_param);
var
  ier: sio16550_$bits_t;
  regs: sio16550_$regs_ptr_t;
begin
  regs := chan.regs;
  regs^.rbr_thr := ch;
  ier.c := regs^.ier;
  if not (sio16550_$ier_thre in ier.s) then begin
    ier.s := ier.s + [sio16550_$ier_thre];
    regs^.ier := ier.c;
  end;
end;
