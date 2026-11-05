{ SIO2681_$SET_LINE - set a channel's line parameters.

  Image addresses:
    sau2  0x00E1D250  SIO2681_$SET_LINE
    sau3  0x00E1C3C4  SIO2681_$SET_LINE
    sau4  0x0F81E464  SIO2681_$SET_LINE
    sau6  0x7801F334  SIO2681_$SET_LINE
    sau7  0x3C4215B8  SIO2681_$SET_LINE
    sau8  0x03C1E970  SIO2681_$SET_LINE

  - Under the driver's spin lock the channel is disabled and reset, then
    set by the change mask: members 0 or 1 the speed, 2, 3, 4 or 10 the
    format (MR1 and MR2), 5 or 6 the modem outputs.  It is re-enabled.
  - A speed the peer channel's rates rule out is refused unless member
    1 is set; the peer then gets the default rates when the chip's set
    changes.

  Status stored:
    status_$ok: the parameters were set
    status_$sio_incompatible_speed: a rate index above 16, a rate with
      no support bits, or one that does not meet the peer's
}

{ TODO(pascal) the even-parity arm's one `andi'

  The even arm clears bits 4..2 of MR1 in one instruction: the odd and
  no-parity arms treat bits 4..3 (the parity mode) and bit 2 (odd) as
  separate fields, so a single 3-bit field does not fit all three arms.
  Read as two constant stores, parity_mode := 0 and parity_odd := false,
  merged into one `andi' (merged constant stores, here of two packed
  fields of one byte; not a known form).  dpc would give two. }

procedure sio2681_$set_line(var channel: sio2681_$channel_t;
                            in params: sio_$params_t;
                            change_mask: sio2681_$mask_t;
                            out status: status_$t);
  options(val_param);
var
  line_status: status_$t;
  rates: sio2681_$rates_t;
  token: integer;
  mr2: sio2681_$mr2_t;
  mr1: sio2681_$mr1_t;
  chip: sio2681_$chip_ptr_t;
  peer: sio2681_$channel_ptr_t;
  unused_1c: integer32;                   { stand-in }
begin
  line_status.all := status_$ok;
  token := ml_$spin_lock(spin_lock);

  channel.regs^.cra := cmd_disable_rx_tx;
  channel.regs^.cra := cmd_reset_rx;
  channel.regs^.cra := cmd_reset_tx;
  channel.chan_flags := channel.chan_flags - [0];

  { the speed }
  if change_mask * [0, 1] <> [] then begin
    rates := sio2681_$rates_t(params.baud_rate);
    if (rates.rx <= 16) and then (rates.tx <= 16) then begin
      peer := channel.peer;
      if (baud_bits[rates.tx] = 0) or else
         ((not (1 in change_mask)) and then
          ((baud_bits[rates.tx] & peer^.baud_support) = 0)) then
        line_status.all := status_$sio_incompatible_speed
      else begin
        chip := channel.chip;
        sio2681_set_baud_rate(channel, rates,
          ((baud_masks[chip^.config1.w < 0] & baud_bits[rates.tx]) <> 0)
            = (chip^.config1.w < 0));
        if (peer^.baud_support & baud_masks[chip^.config1.w < 0]) = 0 then
          sio2681_set_baud_rate(peer^, default_baud, chip^.config1.w < 0);
      end;
    end;
  end;

  { the character format }
  if change_mask * [2, 3, 4, 10] <> [] then begin
    mr1 := mr1_template;
    case params.parity of
      sio_$even_parity: begin
        mr1.parity_mode := 0;
        mr1.parity_odd := false;
      end;
      sio_$odd_parity: begin
        mr1.parity_mode := 0;
        mr1.parity_odd := true;
      end;
      sio_$no_parity: begin
        mr1.parity_mode := 2;
      end;
    end;
    case params.char_size of
      sio_$5bpc: mr1.bits := 0;
      sio_$6bpc: mr1.bits := 1;
      sio_$7bpc: mr1.bits := 2;
      sio_$8bpc: mr1.bits := 3;
    end;

    mr2 := mr2_template;
    mr2.cts_tx := 1 in params.flags2;
    case params.stop_bits of
      sio_$stop_1: mr2.stop := 7;
      sio_$stop_1_point_5: mr2.stop := 8;
      sio_$stop_2: mr2.stop := 15;
    end;

    channel.regs^.cra := cmd_reset_mr_ptr;
    channel.regs^.mra := mr1.c;
    channel.regs^.mra := mr2.c;
  end;

  { the modem outputs }
  if change_mask * [5, 6] <> [] then
    with channel.chip^ do begin
      if 1 in channel.chan_flags then begin
%if sio2681_modem_op3_op0 %then
        config2.op3 := 3 in params.flags1;
%else
        config2.op2 := 3 in params.flags1;
%endif
        config2.op0 := 0 in params.flags1;
      end
      else begin
%if sio2681_modem_op3_op0 %then
        config2.op2 := 3 in params.flags1;
%else
        config2.op3 := 3 in params.flags1;
%endif
        config2.op1 := 0 in params.flags1;
      end;
      regs^.sopbc := config2.opr;
      regs^.ropbc := chr(xor(ord(config2.opr), 16#FF));
    end;

  channel.regs^.cra := cmd_reset_err_enable;
  ml_$spin_unlock(spin_lock, token);
  status := line_status;
end;
