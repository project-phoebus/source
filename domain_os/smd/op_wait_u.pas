{ SMD_$OP_WAIT_U - wait for the display's current scroll or BLT to end.

  Image addresses:
    sau2  0x00E6FB96  SMD_$OP_WAIT_U
    sau4  0x0F87A456  SMD_$OP_WAIT_U
    sau5  0x00E7204C  SMD_$OP_WAIT_U
    sau9  0x3C476070  SMD_$OP_WAIT_U

  - Only for a caller with a display unit: acquiring the display waits
    for the operation in progress, and it is released at once.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of SMD_$OP_WAIT_U not accounted

  The frame has 4 bytes of locals, which nothing addresses (the saved
  A5 is below them).  The source above has no local; dpc's layout
  (`--dump-locals') gives the routine none.  The other SMD callers that
  discard SMD_$ACQ_DISPLAY's result have unexplained frame bytes too
  (smd/invert_s.pas, smd/soft_scroll.pas; the README's TODO list), which
  may point at a temporary for the discarded result. }

procedure smd_$op_wait_u;
begin
  if asid_to_unit[proc1_$as_id] <> 0 then begin
    discard(smd_$acq_display(0));
    smd_$rel_display;
  end;
end;
