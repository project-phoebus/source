{ MST_$WIRE_AREA - wire every page of an address range and list their
  page numbers.

  Image addresses:
    sau2  0x00E44BA4  MST_$WIRE_AREA
    sau9  0x3C44C352  MST_$WIRE_AREA

  - Each page from start_va's to end_va's is wired by MST_$WIRE and its
    number stored in page_list, page_count counting them.
  - More pages than max_pages ("ppn list overflow") or a failed wire
    crash the system.

  Status stored: none.
}

procedure mst_$wire_area(in start_va: univ_ptr; in end_va: univ_ptr;
                         out page_list: univ mst_$page_list_t;
                         in max_pages: integer;
                         out page_count: integer);
var
  status: status_$t;
  va: linteger;
  n: linteger;
  k: linteger;
begin
  va := linteger(start_va);
  page_count := 0;
  n := rshft(linteger(end_va), 10) - rshft(va, 10) + 1;
  for k := 1 to n do begin
    page_count := page_count + 1;
    if page_count > max_pages then
      crash_system(status_$ppn_list_overflow);
    page_list[page_count] := mst_$wire(va, status);
    if status.all <> status_$ok then
      crash_system(status);
    va := va + 16#400;
  end;
end;
