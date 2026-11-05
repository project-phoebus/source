{ AST_$FETCH_PMAP_PAGE - read one page of a remote object into a buffer.

  Image addresses:
    sau2  0x00E041A8  AST_$FETCH_PMAP_PAGE
    sau4  0x0F804580  AST_$FETCH_PMAP_PAGE
    sau6  0x7800487A  AST_$FETCH_PMAP_PAGE
    sau7  0x3C404CCA  AST_$FETCH_PMAP_PAGE
    sau8  0x03C044BE  AST_$FETCH_PMAP_PAGE
    sau9  0x3C4054CA  AST_$FETCH_PMAP_PAGE

  - A physical page is allocated and the diskless partner asked for the
    page.  On success its 1 KB is copied into the caller's buffer
    through AST_$ZERO_BUFF, and the page freed.
  - The caller is told nothing: the status is a value parameter.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

procedure ast_$fetch_pmap_page(var req: network_$page_request_t;
                               out page: univ ast_$page_t;
                               pkt_size: integer; status: status_$t);
  options(val_param);
var
  ppns: network_$ppn_list_t;
  buf_addr: integer32;
  clock: time_$clock_t;
  dat_va: integer32;
begin
  ml_$lock(ml_$pmap_lock);
  discard(ast_$allocate_pages(1, 1, ppns));
  ml_$unlock(ml_$pmap_lock);

  netbuf_$rtn_dat(ppns[0] * 16#400);

  discard(network_$read_ahead(area_$partner, req, ppns, pkt_size, 1,
                              false, false, clock, clock, clock, status));

  if status.all = status_$ok then begin
    ml_$lock(ml_$pmap_lock);
    mmu_$install(ppns[0], addr(ast_$zero_buff), 0, 16#16);

    page := ast_$zero_buff;

%if large_vm %then
    mmu_$remove(addr(ast_$zero_buff), 0);
%else
    mmu_$remove(ppns[0]);
%endif
    mmap_$free(ppns[0]);
    ml_$unlock(ml_$pmap_lock);
  end
  else begin
    netbuf_$get_dat(buf_addr);
    dat_va := buf_addr;
    mmap_$free(rshft(dat_va, 10));
  end;
end;
