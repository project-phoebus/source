{ gpu_$unwire_page - release one page of the graphics processor's page
  table.

  Image addresses:
    sau5  0x00E73806  gpu_$unwire_page (module-local)
    sau6  0x7807A71A  gpu_$unwire_page (module-local)

  - The processor is told to drop the page's mapping only when tell is
    set and the page's owner holds the processor.

  Status stored: none.
}

procedure gpu_$unwire_page(page: integer32; tell: boolean); internal;
var
  owner: integer;
  next: integer32;
  prev: integer32;
  cmd: gpu_cmd_t;
  done: integer;
  gpu_stat: pinteger;
  status: status_$t;
begin
  owner := page_table^[page].info & 1023;
  if tell and then (owner = gpu_$user_pid) then begin
    cmd.op := 16#41E1;
    cmd.len := 2;
    cmd.arg1 := page_table^[page].info & 16#FFFFFC00;
    gpu_$pio_write(cmd, 4, done, gpu_stat, status);
  end;
  wp_$unwire(page);
  page_table^[page].info := 0;
  pages_wired[owner] := pages_wired[owner] - 1;
  page_count := page_count - 1;
  if page_count <> 0 then begin
    next := page_table^[page].next;
    prev := page_table^[page].prev;
    page_table^[next].prev := prev;
    page_table^[prev].next := next;
    if page_head = page then
      page_head := prev;
  end;
end;
