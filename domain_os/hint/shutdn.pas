{ HINT_$SHUTDN - unmap and unlock the hint file.

  Image addresses:
    sau2  0x00E49908  HINT_$SHUTDN

  - If the hint file is published, HINT_$HINTFILE_PTR is cleared and
    the file's 32767 bytes unmapped and unlocked.

  Status stored: none.
}

procedure hint_$shutdn;
var
  saved_ptr: hint_$file_ptr_t;
  status: status_$t;
begin
  if hint_$hintfile_ptr = nil then return;
  saved_ptr := hint_$hintfile_ptr;
  hint_$hintfile_ptr := nil;

  mst_$unmap_privi(1, uid_$nil, integer32(saved_ptr), 32767, 0, status);
  discard(file_$unlock(hint_$hintfile_uid, 4, status));
end;
