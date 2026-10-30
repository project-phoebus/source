{ SIO16550_$INT - service a 16550's interrupt.

  Image addresses:
    sau9  0x3C41FC56  SIO16550_$INT

  - Takes the pending interrupts until the identification shows none,
    and returns true.
  - A modem status change reports DCD and CTS changes; a transmit
    holding register empty sends a blank when the channel's flags are
    set (after PCHIST_$INTERRUPT), else asks SIO_$I_XMIT_DONE (false
    disables the transmit interrupt); received data and a timeout go to
    SIO_$I_RCV; a line status condition goes to SIO_$I_RCV as a zero
    character with its error flags.

  Status stored: none.
}

{ TODO(pascal) 4 unaddressed frame bytes (stand-in unused_18)

  The frame has 4 bytes more than the locals the code shows (chan and
  regs, held in registers, the four register copies and the result),
  and no instruction reaches them.  The other SAUs have no 16550
  driver.  The stand-in holds the place. }

function sio16550_$int(arg: integer32): boolean;
  options(val_param);
var
  chan: sio16550_$chan_ptr_t;
  lsr: sio16550_$bits_t;
  ier: sio16550_$bits_t;
  msr: sio16550_$bits_t;
  iir: sio16550_$bits_t;
  regs: sio16550_$regs_ptr_t;
  unused_18: integer32;                   { the stand-in (TODO) }
begin
  chan := sio16550_$chan_ptr_t(arg);
  regs := chan^.regs;
  repeat
    iir.c := regs^.iir_fcr;
    if sio16550_$iir_no_int in iir.s then
      exit;
    case iir.code of
      sio16550_$int_modem: begin
        msr.c := regs^.msr;
        if sio16550_$msr_ddcd in msr.s then
          sio_$i_dcd_change(chan^.sio_desc,
                            not (sio16550_$msr_dcd in msr.s));
        if sio16550_$msr_dcts in msr.s then
          sio_$i_cts_change(chan^.sio_desc,
                            not (sio16550_$msr_cts in msr.s));
      end;
      sio16550_$int_thre: begin
        if chan^.flags <> 0 then begin
          pchist_$interrupt(histogram_address);
          sio16550_$xmit(chan^, ' ');
        end
        else if not sio_$i_xmit_done(chan^.sio_desc) then begin
          ier.c := regs^.ier;
          ier.s := ier.s - [sio16550_$ier_thre];
          regs^.ier := ier.c;
        end;
      end;
      sio16550_$int_rda, sio16550_$int_timeout: begin
        sio_$i_rcv(chan^.sio_desc, regs^.rbr_thr, 0);
      end;
      sio16550_$int_rls: begin
        lsr.c := regs^.lsr;
        sio_$i_rcv(chan^.sio_desc, chr(0), error_table[lsr.code]);
      end;
      4, 5, 7: { codes the 16550 does not give };
    end;
  until false;
  sio16550_$int := true;
end;
