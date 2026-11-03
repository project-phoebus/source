{ KBD_$RESET - reset the keyboard.

  Image addresses:
    sau2  0x00E1AB28  KBD_$RESET
    sau3  0x00E1A190  KBD_$RESET
    sau8  0x03C1C0C8  KBD_$RESET
    sau9  0x3C41D660  KBD_$RESET

  - An empty procedure but with `kbd_tone'.  With it, the two reset
    bytes go to the keyboard's serial channel, if it has one, each once
    the transmitter can take it: the 16550's (`sio16550_lines') or the
    SIO2681's channel A (`console_sio2681').
  - A fragment of the OS_TERM_INIT module, not of KBD: the first symbol
    of that module's WIRED_PROC segment (term/os_term_init.pas includes
    it).

  Status stored: none.
}

{ TODO(sau) KBD_$RESET's form on the SAU6 and SAU7

  Their KBD_$RESET sends the same two bytes on an SIO2681 channel, the
  SAU8's form (`console_sio2681'), the SAU7's with its block's offsets;
  the SAU6's tests a display register first. }

{ TODO(pascal) KBD_$RESET's frame has 4 bytes no object accounts for

  The SAU9 image's frame is 8 bytes, the line status's copy at its top;
  the loop index is held in a register and its slot, and 4 bytes below
  it, are reached by no instruction (the SAU6, SAU7 and SAU8 copies have
  the same frame): the stand-in unused_8 below. }

[section(wired_proc, wired_data)]
procedure kbd_$reset;
%if sio16550_lines %then
var
  lsr: sio16550_$bits_t;
  i: integer;
  unused_8: integer32;                    { see the TODO }
%elseif console_sio2681 %then
const
  sr_txrdy = 2;                           { the status register's TxRDY }
var
  sr: sio2681_$int_bits_t;                { the status register's copy }
  i: integer;
  unused_8: integer32;                    { see the TODO }
%endif
begin
%if console_sio2681 %then
  if term_$console_chan_ptr <> nil then
    for i := 1 to 2 do begin
      repeat
        sr.c := term_$console_chan_ptr^.regs^.sra_csra;
      until sr_txrdy in sr.s;
      term_$console_chan_ptr^.regs^.rhra_thra := chr(kbd_$reset_bytes[i]);
    end;
%endif
%if sio16550_lines %then
  if term_$console_chan_ptr <> nil then
    for i := 1 to 2 do begin
      repeat
        lsr.c := term_$console_chan_ptr^.regs^.lsr;
      until sio16550_$lsr_thre in lsr.s;
      term_$console_chan_ptr^.regs^.rbr_thr := chr(kbd_$reset_bytes[i]);
    end;
%endif
end;
