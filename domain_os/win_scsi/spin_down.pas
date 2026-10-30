{ WIN_SCSI_$SPIN_DOWN - the spin down entry: nothing to do.

  Image addresses:
    sau9  0x3C41C784  WIN_SCSI_$SPIN_DOWN

  - Returns 0.
}

function win_scsi_$spin_down(in ctlr: pinteger): integer;
begin
  win_scsi_$spin_down := 0;
end;
