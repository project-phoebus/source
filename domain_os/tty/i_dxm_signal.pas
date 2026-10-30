{ TTY_$I_DXM_SIGNAL - send a queued line signal to the line's process
  group.

  Image addresses:
    sau2  0x00E671DC  TTY_$I_DXM_SIGNAL

  - The DXM helper process calls it for each callback TTY_$I_SIGNAL
    queued, with a pointer to its copy of the signal entry.
  - PROC2_$SIGNAL_PGROUP_OS's status is ignored.

  Status stored: none.
}

{ TODO(pascal) 12 frame bytes no instruction addresses (stand-in unused_18)

  The SAU2 frame holds 12 bytes more than the three locals need, which
  no instruction addresses (the survey of tty/k_flush_input.pas leaves them
  unexplained too).  12 is the size of a signal entry
  (tty_$signal_entry_t), but no copy of the entry is made.  The stand-in
  unused_18 holds the place; what the source declared is not known. }

procedure tty_$i_dxm_signal(in entry_ptr: tty_$signal_entry_ptr_t);
var
  status: status_$t;
  entry: tty_$signal_entry_ptr_t;
  tty: tty_$desc_ptr_t;
  unused_18: array[1..3] of integer32;    { stand-in, see TODO }
begin
  entry := entry_ptr;
  tty := entry^.tty_desc;
  proc2_$signal_pgroup_os(tty^.pgroup_uid, entry^.signal_num,
                          entry^.fault_status, status);
end;
