{ SIO2681_$INT - service a 2681's interrupt.

  Image addresses:
    sau2  0x00E1CEEC  SIO2681_$INT
    sau3  0x00E1C060  SIO2681_$INT
    sau8  0x03C1E690  SIO2681_$INT

  - Entered from the hand-written stubs with the chip's SIO2681_$PTRS
    entry.  Each pass handles the pending conditions in the order B
    receive, A receive, A transmit, B transmit, input change.
  - A receive goes to SIO_$I_RCV with its error bits; a transmit sends a
    blank when the channel's flags are set, else asks SIO_$I_XMIT_DONE
    (false masks the transmit interrupt).
  - An input change reports CTS and DCD changes of both channels.

  Status stored: none.
}

{ TODO(pascal) the loop invariants held in registers

  The addresses of chip^.imr_shadow and chan_b^.sio_desc are formed once
  before the loop and used from registers in it, while chan_a^.sio_desc
  is reached through its record at each use.  The Pascal names the
  fields; which references the compiler hoists is not known, and dpc
  hoists none. }

procedure sio2681_$int(in entry: sio2681_$ptrs_entry_t);
var
  ipcr: sio2681_$ports_t;
  sr: char;
  pending: sio2681_$int_bits_t;
  chan_a: sio2681_$channel_ptr_t;
  chan_b: sio2681_$channel_ptr_t;
  chip: sio2681_$chip_ptr_t;
begin
  chan_a := entry.chan_a;
  chan_b := entry.chan_b;
  chip := entry.chip;

  repeat
    pending.c := chip^.regs^.isr_imr;
    pending.s := pending.s * chip^.imr_shadow.s;
    if ord(pending.c) = 0 then return;

    { channel B receive }
    if 5 in pending.s then begin
      sr := chan_b^.regs^.sra_csra;
      sio_$i_rcv(chan_b^.sio_desc, chan_b^.regs^.rhra_thra,
                 error_table[rshft(ord(sr) & 16#F0, 4)]);
      if ord(pending.c) = 16#20 then next;
      pending.s := pending.s - [5];
    end;

    { channel A receive }
    if 1 in pending.s then begin
      sr := chan_a^.regs^.sra_csra;
      sio_$i_rcv(chan_a^.sio_desc, chan_a^.regs^.rhra_thra,
                 error_table[rshft(ord(sr) & 16#F0, 4)]);
      if ord(pending.c) = 2 then next;
      pending.s := pending.s - [1];
    end;

    { channel A transmit }
    if 0 in pending.s then begin
      if chan_a^.flags <> 0 then begin
        pchist_$interrupt(entry.saved_pc);
        sio2681_$xmit(chan_a^, ' ');
      end
      else if not sio_$i_xmit_done(chan_a^.sio_desc) then begin
        chip^.imr_shadow.s := chip^.imr_shadow.s - [0];
        chip^.regs^.isr_imr := chip^.imr_shadow.c;
      end;
      if ord(pending.c) = 1 then next;
      pending.s := pending.s - [0];
    end;

    { channel B transmit }
    if 4 in pending.s then begin
      if chan_b^.flags <> 0 then begin
        pchist_$interrupt(entry.saved_pc);
        sio2681_$xmit(chan_b^, ' ');
      end
      else if not sio_$i_xmit_done(chan_b^.sio_desc) then begin
        chip^.imr_shadow.s := chip^.imr_shadow.s - [4];
        chip^.regs^.isr_imr := chip^.imr_shadow.c;
      end;
      if ord(pending.c) = 16#10 then next;
      pending.s := pending.s - [4];
    end;

    { an input port change }
    if 7 in pending.s then begin
      ipcr.c := chip^.regs^.ipcr_acr;
      if ipcr.delta_cts_a then
        sio_$i_cts_change(chan_a^.sio_desc, not ipcr.cts_a);
      if ipcr.delta_cts_b then
        sio_$i_cts_change(chan_b^.sio_desc, not ipcr.cts_b);
      if ipcr.delta_dcd_a then
        sio_$i_dcd_change(chan_a^.sio_desc, not ipcr.dcd_a);
      if ipcr.delta_dcd_b then
        sio_$i_dcd_change(chan_b^.sio_desc, not ipcr.dcd_b);
    end;
  until false;
end;
