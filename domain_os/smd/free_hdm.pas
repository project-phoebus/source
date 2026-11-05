{ SMD_$FREE_HDM - return space to hidden display memory.

  Image addresses:
    sau2  0x00E6DA3A  SMD_$FREE_HDM
    sau4  0x0F878126  SMD_$FREE_HDM
    sau5  0x00E6FDCA  SMD_$FREE_HDM
    sau6  0x780771A6  SMD_$FREE_HDM
    sau7  0x3C481034  SMD_$FREE_HDM
    sau9  0x3C474754  SMD_$FREE_HDM

  - The position is turned back into an offset, SMD_$ALLOC_HDM's inverse
    (its color arms too); the space merges with the block before, after,
    both or neither.
  - For a display type the `case' does not name, the offset is not
    assigned.
  - With `display_devices' (base/config.ins.pas) a 1280x1024 display's
    hidden memory is three strips of 1024 lines (SMD_$ALLOC_HDM), and a
    merge with a neighbor is made there only within one strip; the other
    device types' is a landscape display's.

  Status stored:
    status_$ok: the space was returned
    smd_$illegal_caller: the process has no display unit
    smd_$invalid_pos: the position is not in the hidden memory
    smd_$hdmt_unload_err: the space overlaps a free block, or the list
      is full
}

{ TODO(pascal) frame of SMD_$FREE_HDM not accounted

  The frame is 0x2C bytes; the code addresses only ret_size's copy.  The
  declared locals (unit 2, hdm_list 4, hw 4, off 2, next_start 2,
  prev_end 2, block_end 4, insert_idx 2, i 2) and three `with' slots (4
  each) give 36 bytes with ret_size's copy; 8 are not explained.  The
  copy lies below 14 bytes of other objects (a place seen in 34
  routines); dpc puts a copy at the top, which does not fit here. }

procedure smd_$free_hdm(ret_size: integer; in pos: smd_$pos_t;
                        out status: status_$t);
var
  unit: integer;
  hdm_list: smd_hdm_list_ptr_t;
  hw: smd_display_hw_ptr_t;
  off: integer;
  next_start: integer;
  prev_end: integer;
  block_end: integer32;
  insert_idx: integer;
  i: integer;
%if display_devices %then
  hdm_end: integer;
%endif
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  hdm_list := smd_$wired_data.unit[unit].hdm_list;
  hw := smd_$wired_data.unit[unit].hw;

  { the position as an offset in the hidden memory }
  case hw^.display_type of
%if display_devices %then
    smd_$bw4_1280x1024: begin
      off := (pos.column - 1280) div 224 * 1024 + pos.line;
      hdm_end := 3073;
      if ((pos.column - 1280) mod 224 <> 0) or else (pos.column > 1728)
         or else (pos.line > 1023) or else (off < 41)
         or else (pos.column < 1280) then begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
    smd_$color4_display, smd_$color5_display, smd_$bw5_1024x800: begin
      off := pos.column + pos.line - 800;
      hdm_end := 1025;
      if (pos.column mod 224 <> 0) or else (pos.line < 800)
         or else (off < 0) or else (off > 983) then begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
%else
    smd_$bw_15p: begin
      if (pos.line <= 1023) and then (pos.column = 800)
         and then (pos.line >= 49) then
        off := pos.line
      else begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
    smd_$bw_19l: begin
      off := pos.column + pos.line - 800;
      if (pos.column mod 224 <> 0) or else (pos.line < 800)
         or else (off < 0) or else (off > 983) then begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
%if color_board %then
    smd_$color_display, smd_$800_color: begin
      if (pos.line <= 2047) and then (pos.column = 800)
         and then (pos.line >= 1073) then
        off := pos.line - 1024
      else begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
%endif
%if gpu_driver %then
    smd_$color2_display: begin
      if (pos.line <= 1023) and then (pos.column = 1280)
         and then (pos.line >= 49) then
        off := pos.line
      else begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
    smd_$color3_display: begin
      off := pos.line - 805 + (pos.column div 224) * 219;
      if (pos.column mod 224 <> 0) or else (pos.line < 805)
         or else (off < 0) or else (off > 983) then begin
        status.all := smd_$invalid_pos;
        return;
      end;
    end;
%endif
%endif
  end;

  { the first free block after the space }
  insert_idx := 1;
  repeat
    if insert_idx > hdm_list^.count then
%if display_devices %then
      next_start := hdm_end
%else
      next_start := 1025
%endif
    else
      next_start := hdm_list^.blocks[insert_idx].offset;

    if off < next_start then begin
      if insert_idx > 1 then
        prev_end := hdm_list^.blocks[insert_idx - 1].offset
                    + hdm_list^.blocks[insert_idx - 1].size
      else
        prev_end := -1;
      block_end := off + ret_size;

      { the space must not overlap the free blocks }
      if (block_end > next_start) or else (off < prev_end) then begin
        status.all := smd_$hdmt_unload_err;
        return;
      end;

%if display_devices %then
      { a merge only within one strip of a 1280x1024 display }
      if (off = prev_end)
         and then ((integer32(prev_end) = off div 1024)
                   or else (hw^.display_type <> smd_$bw4_1280x1024)) then
        with hdm_list^.blocks[insert_idx - 1] do
          if (block_end = next_start)
             and then ((off div 1024 = next_start div 1024)
                       or else (hw^.display_type
                                <> smd_$bw4_1280x1024)) then begin
%else
      if off = prev_end then
        with hdm_list^.blocks[insert_idx - 1] do
          if block_end = next_start then begin
%endif
            { both neighbors: the three become one }
            size := size + ret_size
                    + hdm_list^.blocks[insert_idx].size;
            hdm_list^.count := hdm_list^.count - 1;
            for i := insert_idx to hdm_list^.count do
              hdm_list^.blocks[i] := hdm_list^.blocks[i + 1];
          end
          else
            size := size + ret_size
%if display_devices %then
      else if (block_end = next_start)
              and then ((off div 1024 = next_start div 1024)
                        or else (hw^.display_type
                                 <> smd_$bw4_1280x1024)) then
%else
      else if block_end = next_start then
%endif
        with hdm_list^.blocks[insert_idx] do begin
          offset := off;
          size := size + ret_size;
        end
      else
        with hdm_list^.blocks[insert_idx] do begin
          if hdm_list^.count >= 25 then begin
            status.all := smd_$hdmt_unload_err;
            return;
          end;
          for i := hdm_list^.count downto insert_idx do
            hdm_list^.blocks[i + 1] := hdm_list^.blocks[i];
          hdm_list^.count := hdm_list^.count + 1;
          offset := off;
          size := ret_size;
        end;

      status.all := status_$ok;
      return;
    end;

    insert_idx := insert_idx + 1;
  until false;
end;
