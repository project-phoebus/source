{ SMD_$NOP_LOCK - the default for a device's display lock.

  Image addresses:
    sau7  0x3C480C56  SMD_$NOP_LOCK
    sau9  0x3C474376  SMD_$NOP_LOCK

  - Returns true: the display is the caller's.

  Status stored: none.
}

function smd_$nop_lock(dcte: univ_ptr; var hw: smd_display_hw_t;
                       kind: integer): boolean;
  options(val_param);
begin
  smd_$nop_lock := true;
end;
