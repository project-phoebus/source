{ TERM_$PCHIST_ENABLE - turn the PC history sampling on the serial line
  on or off.

  Image addresses:
    sau2  0x00E72450  TERM_$PCHIST_ENABLE
    sau3  0x00E73B3C  TERM_$PCHIST_ENABLE
    sau9  0x3C479E48  TERM_$PCHIST_ENABLE

  - The word goes into the flags of the second SIO2681 channel record,
    which the SIO2681 interrupt routine tests before PCHIST_$INTERRUPT.
  - With `sio16550_lines' it goes into the flags of the 16550 channel of
    the fourth DTTE's SIO descriptor, which the 16550 interrupt routine
    tests the same way; a line without one is refused.

  Status stored:
    status_$ok: the flags were set
    status_$requested_line_or_operation_not_implemented: the fourth
      DTTE has no SIO descriptor (`sio16550_lines')
}

{ TODO(pascal) TERM_$PCHIST_ENABLE's `sio16550_lines' frame has 8 bytes
  no object accounts for

  The SAU9 image's frame is 8 bytes that no instruction reaches (the
  other SAUs' copies have none): the stand-in unused_8 below.  Two
  `with' statements over the two pointers (the SIO descriptor, then its
  channel) would fit if the compiler gives a pointer's `with' temporary
  a frame slot, which is not known. }

[section(procedure$, data$)]
procedure term_$pchist_enable(in count: integer; out status: status_$t);
%if sio16550_lines %then
var
  unused_8: array[1..2] of integer32;     { see the TODO }
%endif
begin
  status.all := status_$ok;
%if sio16550_lines %then
  if dtte[3].tty_handler = nil then
    status.all := status_$requested_line_or_operation_not_implemented
  else
    sio16550_$chan_ptr_t(
      sio_$desc_ptr_t(dtte[3].tty_handler)^.context)^.flags := count;
%else
  term_$serial_chan_b.flags := count;
%endif
end;
