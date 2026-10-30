{ TTY_$K_SIMULATE_TERMINAL_INPUT - feed one character to a line as if it
  had been received, for a caller of the kernel interface.

  Image addresses:
    sau2  0x00E1C148  TTY_$K_SIMULATE_TERMINAL_INPUT

  - A process other than process 0 must be in the line's process group.
    The character goes through TTY_$I_RCV with the spin lock held.

  Status stored:
    tty_$i_get_desc's status: the line has no descriptor
    proc2_$upgid_to_uid's status: the character was received, or the
      caller's group has no UID
    status_$tty_invalid_option: the caller is not in the line's process
      group
}

{ TODO(pascal) with upid_copy's slot, the frame lacks the usual 4 open
  bytes

  With upid_copy's slot, the SAU2 frame has none of the 4 unaddressed
  bytes that every other TTY_$K_ routine of this kind shows
  (tty/k_flush_input.pas); without the slot it would have them.  Whichever
  rule explains those bytes must also say which reading this frame is. }

[section(wired_proc, wired_data)]
procedure tty_$k_simulate_terminal_input(in line: integer; in ch: char;
                                         out status: status_$t);
var
  my_uid: uid_$t;
  tty: integer32;
  upgid: integer;
  uppid: integer;
  upid: integer;
  token: integer;
  upid_copy: integer;
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  { the caller's process ids and group UID }
  proc2_$get_my_upids(upid, uppid, upgid);
  upid_copy := upid;
  proc2_$upgid_to_uid(upgid, my_uid, status);
  if status.all <> status_$ok then
    return;

  { only the line's process group, or process 0 }
  if (upid_copy <> 0) and then (my_uid <> tty_$desc_ptr_t(tty)^.pgroup_uid) then begin
    status.all := status_$tty_invalid_option;
    return;
  end;

  { receive the character with the spin lock held }
  token := ml_$spin_lock(tty_$spin_lock);
  tty_$i_rcv(tty_$desc_ptr_t(tty)^, ch);
  ml_$spin_unlock(tty_$spin_lock, token);
end;
