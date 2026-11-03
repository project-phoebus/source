{ SIO2681_$TONE - switch the tone output of a channel's chip.

  Image addresses:
    sau2  0x00E1D172  SIO2681_$TONE
    sau3  0x00E1C2E6  SIO2681_$TONE
    sau4  0x0F81E386  SIO2681_$TONE

  - Under the driver's spin lock bit 7 of the chip's output port shadow
    becomes the complement of enable; the shadow goes to the
    set-output-bits register, its complement to the reset-output-bits
    register.

  Status stored: none.
}

procedure sio2681_$tone(in channel: univ_ptr; in enable: boolean;
                        out status_unused: status_$t);
var
  chan: sio2681_$channel_ptr_t;
  token: integer;
  chip: sio2681_$chip_ptr_t;
  unused_10: integer32;                   { stand-in }
begin
  chan := channel;
  token := ml_$spin_lock(spin_lock);

  chip := chan^.chip;
  chip^.config2.op7 := not enable;
  chip^.regs^.sopbc := chip^.config2.opr;
  chip^.regs^.ropbc := chr(xor(ord(chip^.config2.opr), 16#FF));

  ml_$spin_unlock(spin_lock, token);
end;
