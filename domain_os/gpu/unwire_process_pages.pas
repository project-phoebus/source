{ gpu_$unwire_process_pages - release the current process's pages of
  the graphics processor's page table down to a limit.

  Image addresses:
    sau5  0x00E73902  gpu_$unwire_process_pages (module-local)
    sau6  0x7807A816  gpu_$unwire_process_pages (module-local)

  - The circular list is walked back from its head; each page is
    released by gpu_$unwire_page, told as tell says.

  Status stored: none.
}

procedure gpu_$unwire_process_pages(limit: integer; tell: boolean);
  internal;
var
  p: integer32;
  cur: integer32;
begin
  p := page_head;
  while pages_wired[proc1_$current] > limit do begin
    repeat
      cur := p;
      p := page_table^[cur].prev;
    until (page_table^[cur].info & 1023) = proc1_$current;
    gpu_$unwire_page(cur, tell);
  end;
end;
