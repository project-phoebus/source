{ WIN6_$GET_IOPBS - hand out a chain of command blocks.

  Image addresses:
    sau6  0x7801A538  WIN6_$GET_IOPBS

  - At IPL 7: n blocks from the head of the free list, their chain cut
    after the last; the first block's state word is set to handed out.
  - The result is 1, nothing handed out, when the list has fewer than n;
    else 0, with the first and last blocks' numbers.

  Status stored: none.
}

function win6_$get_iopbs(n: integer; out first: integer;
                         out last: integer): integer32;
var
  old_sr: pinteger;
  page: win6_$page_ptr_t;
  i: integer;
begin
  win6_$get_iopbs := 0;
  old_sr := set_sr(16#2700);
  if n > win6_free_count then begin
    discard(set_sr(old_sr));
    win6_$get_iopbs := 1;
  end
  else begin
    win6_free_count := win6_free_count - n;
    first := win6_free_head;
    last := win6_free_head;
    page := win6_page;
    for i := 2 to n do
      last := page^.iopbs[last].link div win6_iopb_size;
    win6_free_head := page^.iopbs[last].link div win6_iopb_size;
    page^.iopbs[last].link := win6_end_of_chain;
    page^.iopbs[first].state := win6_state_used;
    discard(set_sr(old_sr));
  end;
end;
