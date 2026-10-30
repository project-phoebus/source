{ VOLX_$REC_ENTRY - record a volume's entry directory.

  Image addresses:
    sau2  0x00E6B6B2  VOLX_$REC_ENTRY

  - The index is not checked.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes that nothing addresses

  The SAU2 image's frame has 4 bytes in a global routine with no result
  and no frame operand; vol_idx is held in a register (a value parameter
  held in a register would explain a slot, as for FIM_$FREE_ASID).
  Stand-in `unused_4'. }

procedure volx_$rec_entry(in vol_idx: integer; in dir_uid: uid_$t);
var
  unused_4: integer32;                    { see the TODO }
begin
  volx_$table[vol_idx].e_dir_uid := dir_uid;
end;
