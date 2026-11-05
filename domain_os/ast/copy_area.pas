{ AST_$COPY_AREA - copy a segment's pages into another segment of an
  area.

  Image addresses:
    sau2  0x00E03A30  AST_$COPY_AREA
    sau4  0x0F803E3C  AST_$COPY_AREA
    sau6  0x78004152  AST_$COPY_AREA
    sau7  0x3C404586  AST_$COPY_AREA
    sau8  0x03C03D7A  AST_$COPY_AREA
    sau9  0x3C404D86  AST_$COPY_AREA

  - The source segment's 32 pages are walked under the PMAP lock, each
    entry waited out of any transition.
  - A run of installed source pages is copied into fresh pages through
    the zero buffer's window; the fresh pages become the destination's.
  - A run of on-disk source pages is read into fresh pages, from the
    partner for a diskless node's area, else from the disk.
  - After each run the destination's pages enter the process's working
    set and the segment is marked dirty; an error ends the walk.

  Status stored:
    status_$ok: the pages were copied
    disk_$read_multi's or the head queue block's status, with the fail
      bit: a disk read failed
    network_$read_ahead's status: a read from the partner failed
}

procedure ast_$copy_area(partner_index: pinteger; pid: integer;
                         var src_aste: ast_$aste_t;
                         var dst_aste: ast_$aste_t; start_seg: pinteger;
                         buffer: integer32; out status: status_$t);
var
  new_ppns: array[1..32] of integer32;
  wired_ppns: array[1..32] of integer32;
  page_req: network_$page_request_t;
  start_off: linteger;
  buf_addr: integer32;
  clk: time_$clock_t;
  qblk_tail: disk_$io_req_ptr_t;
  qblk_head: disk_$io_req_ptr_t;
  buffer_va: integer32;
  temp_va: ast_$page_ptr_t;
  dst_row: ast_$pmap_entry_ptr_t;
  src_row: ast_$pmap_entry_ptr_t;
  pages_read: integer;
  dst_seg: pinteger;
  is_remote: boolean;
  pending: boolean;
  page: pinteger;
  got: pinteger;
  run: pinteger;
  p: pinteger;
  ent: ast_$pmap_entry_ptr_t;
  w: ast_$ppn_ptr_t;
  ppn: linteger;
  page_base: linteger;
  req: disk_$io_req_ptr_t;
  i: integer;
begin
  status.all := status_$ok;
  src_row := addr(ast_pmaps[src_aste.seg_index, 0]);
  dst_row := addr(ast_pmaps[dst_aste.seg_index, 0]);
  buffer_va := buffer;
  is_remote := areas[partner_index].remote_volx <> 0;
  pending := false;
  dst_seg := dst_aste.seg_index;
  start_off := start_seg * 32;

  ml_$lock(ml_$pmap_lock);
  page := 0;
  while page < 16#20 do begin
    while ast_$pmap_in_trans in src_row^.flags do begin
      if pending then begin
        ec_$advance(ast_$pmap_in_trans_ec);
        pending := false;
      end;
      ast_$wait_for_page_transition;
    end;

    if ast_$pmap_installed in src_row^.flags then begin
      { the installed source pages, wired }
      got := 0;
      w := addr(wired_ppns);
      ent := src_row;
      p := page;
      repeat
        ppn := ent^.vpn;
        w^ := ppn;
        w := ast_$ppn_ptr_t(integer32(w) + 4);
        mmap_$wire(ppn);
        ent^.flags := ent^.flags + [ast_$pmap_resident];
        ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
        got := got + 1;
        p := p + 1;
        if p > 16#1F then
          exit;
      until not (ast_$pmap_installed in ent^.flags) or else (ast_$pmap_in_trans in ent^.flags);

%if not (pmmu_page_maps or region_mmu) %then
      mmu_$install_list(got, wired_ppns, buffer_va, proc1_$as_id, 7);
%endif
      discard(ast_$allocate_pages(got, got, new_ppns));

      { each page copied into a fresh one }
      for i := 1 to got do begin
        with mmap[new_ppns[i]] do begin
          temp_va := addr(ast_$zero_buff);
          if in_wsl then
            crash_system(status_$mmap_bad_install);
          wire_count := 0;
          modified := true;
          impure := true;
          flags2_7 := true;
          segment := dst_seg;
          seg_offset := page;
          disk_addr.all := 0;
        end;
        dst_row^.vpn := new_ppns[i];
        dst_row^.flags := dst_row^.flags + [ast_$pmap_installed];
        dst_row^.flags := dst_row^.flags + [ast_$pmap_resident];
        mmu_$install(new_ppns[i], temp_va, proc1_$as_id, 16#16);
%if pmmu_page_maps or region_mmu %then
        dst_row^.flags := dst_row^.flags + [ast_$pmap_used];
        dst_row^.flags := dst_row^.flags + [ast_$pmap_modified];
        os_$data_copy(ast_$page_ptr_t(buffer_va)^, temp_va^, 16#400);
        dst_row^.flags := dst_row^.flags - [ast_$pmap_resident];
%else
        pft[new_ppns[i]].w_02 := pft[new_ppns[i]].w_02 ! 16#6000;
        os_$data_copy(ast_$page_ptr_t(buffer_va)^, temp_va^, 16#400);
        mmu_$remove(new_ppns[i]);
%endif
        mmap_$unwire(wired_ppns[i]);
        page := page + 1;
        dst_row := ast_$pmap_entry_ptr_t(integer32(dst_row) + 4);
        src_row := ast_$pmap_entry_ptr_t(integer32(src_row) + 4);
        buffer_va := buffer_va + 16#400;
      end;
    end
%if pmmu_page_maps %then
    else if src_row^.vpn <> 0 then begin
%else
    else if src_row^.fentry.fm_daddr <> 0 then begin
%endif
      { a run of on-disk source pages }
      run := 0;
      ent := src_row;
      p := page;
      repeat
        ent^.flags := ent^.flags + [ast_$pmap_in_trans];
        ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
        run := run + 1;
        p := p + 1;
        if p > 16#1F then
          exit;
        if run >= 16#20 then
          exit;
        if ast_$pmap_installed in ent^.flags then
          exit;
        if ast_$pmap_in_trans in ent^.flags then
          exit;
%if pmmu_page_maps %then
      until ent^.vpn = 0;
%else
      until ent^.fentry.fm_daddr = 0;
%endif

      discard(ast_$allocate_pages(run, run, new_ppns));
      page_req.uid.high := anon_$uid.high;
      ml_$unlock(ml_$pmap_lock);

      if is_remote then begin
        { from the partner, a page at a time }
        page_req.uid.low := areas[partner_index].remote_volx;
        page_base := page + start_off + (start_off + 16#100) div 16#100;
        got := 0;
        for i := 1 to run do begin
          netbuf_$rtn_dat(new_ppns[i] * 16#400);
          page_req.page_num := i + page_base - 1;
          discard(network_$read_ahead(area_$partner, page_req, new_ppns[i],
                                      area_$partner_pkt_size, 1, false,
                                      false, clk, clk, clk, status));
          if status.all <> status_$ok then begin
            netbuf_$get_dat(buf_addr);
            new_ppns[i] := rshft(buf_addr, 10);
            exit;
          end;
          got := got + 1;
        end;
        proc1_$stats[proc1_$current].stat[4] :=
          proc1_$stats[proc1_$current].stat[4] + got;
      end
      else begin
        { from the disk }
        page_req.uid.low := partner_index;
        page_req.page_num := page + start_off;
        disk_$get_qblks(run, qblk_head, qblk_tail);
        req := qblk_head;
        ast_$id12_ptr_t(addr(req^.header))^ :=
          ast_$id12_ptr_t(addr(page_req))^;
        req^.header.byte_10 := chr(0);
        ent := src_row;
        for i := 1 to run do begin
          req^.daddr.daddr := ent^.dentry.daddr;
          if req^.daddr.daddr = 0 then
            crash_system(status_$area_internal_error);
          req^.ppn := new_ppns[i];
          ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
          req := disk_$io_req_ptr_t(req^.free_next);
        end;
        disk_$read_multi(areas[partner_index].volx, true, true, qblk_head,
                         qblk_tail, pages_read, status);
        got := pages_read;
        if status.all = status_$ok then
          status := qblk_head^.status;
        if status.all <> status_$ok then
          status.fail := true;
        disk_$rtn_qblks(run, qblk_head, qblk_tail);
        proc1_$stats[proc1_$current].stat[3] :=
          proc1_$stats[proc1_$current].stat[3] + got;
      end;

      { install the pages read }
      ml_$lock(ml_$pmap_lock);
      for i := 1 to got do begin
        with mmap[new_ppns[i]] do begin
          if in_wsl then
            crash_system(status_$mmap_bad_install);
          wire_count := 0;
          modified := true;
          impure := true;
          flags2_7 := true;
          segment := dst_seg;
          seg_offset := page;
          disk_addr.all := 0;
        end;
        dst_row^.vpn := new_ppns[i];
        dst_row^.flags := dst_row^.flags + [ast_$pmap_installed];
%if pmmu_page_maps or region_mmu %then
        dst_row^.flags := dst_row^.flags + [ast_$pmap_used];
        dst_row^.flags := dst_row^.flags + [ast_$pmap_modified];
%else
        pft[new_ppns[i]].w_02 := pft[new_ppns[i]].w_02 ! 16#6000;
%endif
        src_row^.flags := src_row^.flags - [ast_$pmap_in_trans];
        page := page + 1;
        dst_row := ast_$pmap_entry_ptr_t(integer32(dst_row) + 4);
        src_row := ast_$pmap_entry_ptr_t(integer32(src_row) + 4);
      end;

      { the pages not read }
      if got <> run then begin
        ent := src_row;
        for i := got + 1 to run do begin
          mmap_$free(new_ppns[i]);
          ent^.flags := ent^.flags - [ast_$pmap_in_trans];
          ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
        end;
      end;
      buffer_va := buffer_va + got * 16#400;
      pending := true;
    end
    else begin
      { no source page: an empty entry }
      dst_row^.all := 0;
      dst_row := ast_$pmap_entry_ptr_t(integer32(dst_row) + 4);
      src_row := ast_$pmap_entry_ptr_t(integer32(src_row) + 4);
      buffer_va := buffer_va + 16#400;
      page := page + 1;
      next;
    end;

    if got <> 0 then begin
      mmap_$install_pages(new_ppns, got, pid);
      dst_aste.flags := dst_aste.flags + [13];
      dst_aste.page_count := chr(ord(dst_aste.page_count) + got);
    end;
    if status.all <> status_$ok then
      exit;
  end;

  ml_$unlock(ml_$pmap_lock);
  if pending then
    ec_$advance(ast_$pmap_in_trans_ec);
end;
