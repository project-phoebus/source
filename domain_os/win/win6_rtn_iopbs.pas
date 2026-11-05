{ WIN6_$RTN_IOPBS - give a chain of command blocks back.

  Image addresses:
    sau6  0x7801A5D0  WIN6_$RTN_IOPBS

  - At IPL 7: the chain first..last of n blocks goes to the tail of the
    free list, its first block's state word cleared.  The head is set
    to first only when the count, with the n blocks added, is 0.

  Status stored: none.
}

procedure win6_$rtn_iopbs(n: integer; first: integer; last: integer);
var
  old_sr: pinteger;
  page: win6_$page_ptr_t;
begin
  old_sr := set_sr(16#2700);
  page := win6_page;
  win6_free_count := win6_free_count + n;
  page^.iopbs[first].state := 0;
  if win6_free_count = 0 then
    win6_free_head := first
  else
    page^.iopbs[win6_free_tail].link := first * win6_iopb_size;
  win6_free_tail := last;
  discard(set_sr(old_sr));
end;
