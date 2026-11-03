{ SIO2681_$XMIT - send a character on a channel.

  Image addresses:
    sau2  0x00E1D4FC  SIO2681_$XMIT
    sau3  0x00E1C670  SIO2681_$XMIT

  - The character goes to the transmit holding register; the channel's
    transmit interrupt is added to the chip's mask shadow (and the mask
    written) if it is not there yet.

  Status stored: none.
}

procedure sio2681_$xmit(in channel: sio2681_$channel_t; ch: char);
  options(val_param);
var
  chip: sio2681_$chip_ptr_t;
begin
  chip := channel.chip;
  channel.regs^.rhra_thra := ch;

  if chip^.imr_shadow.s * [channel.int_bit] = [] then begin
    chip^.imr_shadow.s := chip^.imr_shadow.s + [channel.int_bit];
    chip^.regs^.isr_imr := chip^.imr_shadow.c;
  end;
end;
