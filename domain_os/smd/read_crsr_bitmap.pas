{ SMD_$READ_CRSR_BITMAP - return the bitmap of one of the four cursors.

  Image addresses:
    sau2  0x00E6FD16  SMD_$READ_CRSR_BITMAP
    sau4  0x0F87A618  SMD_$READ_CRSR_BITMAP
    sau5  0x00E7223C  SMD_$READ_CRSR_BITMAP
    sau6  0x7807951C  SMD_$READ_CRSR_BITMAP
    sau7  0x3C482B1C  SMD_$READ_CRSR_BITMAP
    sau9  0x3C47623C  SMD_$READ_CRSR_BITMAP

  - yorg is counted from the top again (height - 1 - the stored value);
    unit is not read.
  - The heading is Apollo's (smdu.ins.pas of SR10.2), unit and cnum
    `in'.

  Status stored:
    status_$ok: the cursor's pattern was returned
    smd_$invalid_crsr_number: cnum is above 3; nothing else is written
}

{ TODO(pascal) 8 frame bytes of SMD_$READ_CRSR_BITMAP not accounted

  The frame has 8 bytes of locals, which nothing addresses (pattern is
  held in a register).  dpc's layout (`--dump-locals') gives the source
  above 4 bytes, pattern's; the other 4, and why pattern's slot is not
  used, are not known. }

procedure smd_$read_crsr_bitmap(in unit: integer; in cnum: integer;
                                out width: integer; out height: integer;
                                out xorg: integer; out yorg: integer;
                                out bitmap: smd_$cursor_bitmap_t;
                                out status: status_$t);
var
  pattern: smd_cursor_pattern_ptr_t;
begin
  if cnum > 3 then begin
    status.all := smd_$invalid_crsr_number;
    return;
  end;

  pattern := smd_$cursor_ptable[cnum];

  width := pattern^.width;
  height := pattern^.height;
  xorg := pattern^.hot_x;
  yorg := pattern^.height - 1 - pattern^.hot_y_adj;

  bitmap := pattern^.bitmap;
  status.all := status_$ok;
end;
