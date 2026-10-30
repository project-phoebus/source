{ ct_touch_pages - check a transfer's buffers and touch each one.

  Image addresses:
    sau5  0x00E76EAC  ct_touch_pages (module-local, at CT_$PROC_START)
    sau9  0x3C4771F8  ct_touch_pages (module-local, at CT_$PROC_START)

  - Each of the first npages buffers is touched so its page is present
    before it is wired: its first word written back when reading, read
    otherwise.

  Returns:
    0: every buffer passed
    status_$ct_invalid_buffer_address: one at or above OS_LOW (the walk
      stopped)

  Status stored: none.
}

function ct_touch_pages(in pages: univ ct_$page_list_t; npages: integer;
                        reading: boolean): integer32; internal;
type
  word_ptr_t = ^integer;
var
  status: integer32;
  i: integer;
  p: word_ptr_t;
  dummy: integer;
begin
  status := 0;
  for i := 1 to npages do begin
    if linteger(pages[i]) >= linteger(addr(os_low)) then begin
      status := status_$ct_invalid_buffer_address;
      exit;
    end;
    p := word_ptr_t(pages[i]);
    if reading then
      p^ := p^
    else
      dummy := p^;
  end;
  ct_touch_pages := status;
end;
