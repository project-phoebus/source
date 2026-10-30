{ dir_$old_find_free_inline_slot - find a free slot among page 0's.

  Image addresses:
    sau2  0x00E54DCC  dir_$old_find_free_inline_slot (module-local)

  - The result is true with the first free slot's number (type byte 0)
    among the first count; false leaves the number unwritten.

  Status stored: none.
}

function dir_$old_find_free_inline_slot(dir: dir_$old_dir_ptr_t;
                                        count: pinteger;
                                        out slot_out: pinteger): boolean;
  internal;
var
  i: pinteger;
begin
  dir_$old_find_free_inline_slot := true;

  for i := 1 to count do
    if dir^.slots[i].slot_type = 0 then begin
      slot_out := i;
      return;
    end;

  dir_$old_find_free_inline_slot := false;
end;
