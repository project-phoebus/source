{ TTY_$K_RESET - reset a line's buffers, process group and delays, for a
  caller of the kernel interface.

  Image addresses:
    sau2  0x00E672DE  TTY_$K_RESET
    sau9  0x3C46E072  TTY_$K_RESET

  - Under the TTY lock both buffers are emptied, the column, the pending
    errors, the process group, the session, the state and the five
    delays cleared.
  - The line's xon/xoff and flow control handlers are told the output
    and the input flow.
  - The adjacent constant word stores are merged into longword stores
    (TTY_$I_INIT makes the same buffer stores one word at a time).

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

{ TODO(pascal) 8 frame bytes that nothing addresses (stand-ins unused_c
  and unused_10)

  The SAU2 frame is 16 bytes for tty (4), d (2) and xon_xoff (2): 8
  bytes that no instruction addresses, where the other TTY_$K_ routines
  have 4 (tty/k_flush_input.pas).  No object of 8 bytes or more is needed
  here, and none of the survey's factors explains the second 4.  The
  stand-ins unused_c and unused_10 hold the place. }

procedure tty_$k_reset(in line: integer; out status: status_$t);
var
  tty: integer32;
  d: tty_$delay_t;
  xon_xoff: boolean;
  unused_c: integer32;                    { stand-in, see TODO }
  unused_10: integer32;                   { stand-in }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  tty_$i_lock(tty_$desc_ptr_t(tty)^);
  xon_xoff := tty_$if_ixoff in tty_$desc_ptr_t(tty)^.input_flags;

  { both buffers empty }
  tty_$desc_ptr_t(tty)^.input_head := 1;
  tty_$desc_ptr_t(tty)^.input.head := 1;
  tty_$desc_ptr_t(tty)^.input.tail := 1;
  tty_$desc_ptr_t(tty)^.input.size := tty_$buf_size;
  tty_$desc_ptr_t(tty)^.output.head := 1;
  tty_$desc_ptr_t(tty)^.output.tail := 1;
  tty_$desc_ptr_t(tty)^.output.size := tty_$buf_size;

  tty_$desc_ptr_t(tty)^.saved_input_flags := 0;
  tty_$desc_ptr_t(tty)^.column := 0;
  tty_$desc_ptr_t(tty)^.pending_signal := [];
  tty_$desc_ptr_t(tty)^.pgroup_uid := uid_$nil;
  tty_$desc_ptr_t(tty)^.session_id := 0;
  tty_$desc_ptr_t(tty)^.state_flags := [];

  for d := tty_$delay_nl to tty_$delay_ff do
    tty_$desc_ptr_t(tty)^.delay[d] := 0;

  { let the line's output and input flow }
  if tty_$desc_ptr_t(tty)^.xon_xoff_handler <> nil then
    tty_$desc_ptr_t(tty)^.xon_xoff_handler^(tty_$desc_ptr_t(tty)^.line_id, false);
  if tty_$desc_ptr_t(tty)^.flow_ctrl_handler <> nil then
    tty_$desc_ptr_t(tty)^.flow_ctrl_handler^(tty_$desc_ptr_t(tty)^.line_id, false, xon_xoff);

  tty_$i_unlock(tty_$desc_ptr_t(tty)^);
end;
