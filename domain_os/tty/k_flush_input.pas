{ TTY_$K_FLUSH_INPUT - discard a line's buffered input, for a caller of
  the kernel interface.

  Image addresses:
    sau2  0x00E1C084  TTY_$K_FLUSH_INPUT

  - TTY_$I_FLUSH_INPUT, with the spin lock held.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

{ TODO(pascal) 4 frame bytes that nothing addresses (stand-in unused_c)

  The SAU2 frame has 4 bytes below tty and token that no instruction
  addresses; the stand-in unused_c holds the place.  The same open bytes
  are in the other TTY_$K_ routines (their stand-ins unused_8,
  unused_20 ..) and in many frames of other modules; no rule found fits
  them all.  What the source declared there is not known. }

[section(wired_proc, wired_data)]
procedure tty_$k_flush_input(in line: integer; out status: status_$t);
var
  tty: integer32;
  token: integer;
  unused_c: integer32;                    { stand-in, see TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  { flush with the spin lock held }
  token := ml_$spin_lock(tty_$spin_lock);
  tty_$i_flush_input(tty_$desc_ptr_t(tty)^);
  ml_$spin_unlock(tty_$spin_lock, token);
end;
