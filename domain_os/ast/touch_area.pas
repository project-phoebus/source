{ AST_$TOUCH_AREA - make a page of an area's segment resident.

  Image addresses:
    sau2  0x00E03548  AST_$TOUCH_AREA
    sau9  0x3C404896  AST_$TOUCH_AREA

  Assume we're called with the PMAP lock held.

  - An installed entry is referenced and its page handed back; an entry
    with no disk address gets a fresh zeroed page.
  - Otherwise the page is read: from a diskless node's partner, else
    from the disk.  The pages got are installed, wired and put in the
    working set.
  - Both run loops stop after their first entry.

  Status stored:
    status_$ok: the page was made resident
    network_$read_ahead's or disk_$read_multi's status, with the fail
      bit: the read failed
}

procedure ast_$touch_area(area_id: pinteger; seg_index: pinteger;
                          page: integer; area_page: linteger;
                          var ppn_array: univ ast_$ppn_list_t;
                          out status: status_$t);
label
  20;
var
  req: network_$page_request_t;
  dat_addr: integer32;
  qblk_tail: disk_$io_req_ptr_t;
  qblk_head: disk_$io_req_ptr_t;
  clk: time_$clock_t;
  entry: area_$entry_ptr_t;
  pages_read: integer;
  log_op: integer;
  segmap: ast_$pmap_entry_ptr_t;
  out: ast_$ppn_ptr_t;
  qb: disk_$io_req_ptr_t;
  n: integer;
  alloc_count: integer;
  pages_marked: integer;
  pages_done: integer;
  i: integer;
begin
  status.all := status_$ok;
  entry := addr(areas[area_id]);
  segmap := addr(ast_pmaps[seg_index, page]);

  out := addr(ppn_array);
  n := 0;
  pages_marked := n;
  while ast_$pmap_in_trans in segmap^.flags do
    ast_$wait_for_page_transition;

  { an installed page }
  if ast_$pmap_installed in segmap^.flags then begin
    repeat
      segmap^.flags := segmap^.flags + [ast_$pmap_resident];
%if pmmu_page_maps %then
      segmap^.flags := segmap^.flags + [ast_$pmap_used];
%else
      pft[segmap^.vpn].w_02 := pft[segmap^.vpn].w_02 ! 16#2000;
%endif
      out^ := segmap^.vpn;
      out := ast_$ppn_ptr_t(integer32(out) + 4);
      n := n + 1;
      segmap := ast_$pmap_entry_ptr_t(integer32(segmap) + 4);
      if n > 0 then
        exit;
%if pmmu_page_maps %then
      if odd(segmap^.low) then
        exit;
%else
      if 13 in segmap^.flags then
        exit;
%endif
      if ast_$pmap_in_trans in segmap^.flags then
        exit;
    until not (ast_$pmap_installed in segmap^.flags);
    mmap_$reclaim(ppn_array, n, false);
    ast_$ws_flt_cnt := ast_$ws_flt_cnt + n;
    return;
  end;

  { no disk copy: a zeroed page }
  if segmap^.dentry.daddr = 0 then begin
    segmap^.flags := segmap^.flags + [ast_$pmap_in_trans];
    discard(ast_$allocate_pages(1, 1, ppn_array));
    zero_page(ppn_array[1]);
    log_op := 8;
    req.uid.high := anon_$uid.high;
    req.uid.low := area_id;
    pages_done := 1;
    pages_marked := pages_done;
    goto 20;
  end;

  { the page read }
  log_op := 2;
  if entry^.remote_volx <> 0 then begin
    { from the diskless node's partner }
    segmap^.flags := segmap^.flags + [ast_$pmap_in_trans];
    pages_marked := 1;
    req.page_num := area_page + (area_page + 16#100) div 16#100;
    req.uid.high := anon_$uid.high;
    req.uid.low := entry^.remote_volx;
    discard(ast_$allocate_pages(pages_marked, pages_marked, ppn_array));
    netbuf_$rtn_dat(ppn_array[1] * 16#400);
    ml_$unlock(ml_$pmap_lock);
    pages_done := network_$read_ahead(area_$partner, req, ppn_array,
                                      area_$partner_pkt_size, pages_marked,
                                      false, false, clk, clk, clk, status);
    if pages_done = 0 then begin
      netbuf_$get_dat(dat_addr);
      mmap_$free(rshft(dat_addr, 10));
    end;
    ml_$lock(ml_$pmap_lock);
    proc1_$stats[proc1_$current].stat[4] :=
      proc1_$stats[proc1_$current].stat[4] + pages_done;
  end
  else begin
    { from the disk }
    repeat
      segmap^.flags := segmap^.flags + [ast_$pmap_in_trans];
      pages_marked := pages_marked + 1;
      segmap := ast_$pmap_entry_ptr_t(integer32(segmap) + 4);
      if pages_marked > 0 then
        exit;
%if pmmu_page_maps %then
      if odd(segmap^.low) then
        exit;
%else
      if 13 in segmap^.flags then
        exit;
%endif
      if ast_$pmap_in_trans in segmap^.flags then
        exit;
      if segmap^.dentry.daddr = 0 then
        exit;
    until ast_$pmap_installed in segmap^.flags;
    alloc_count := ast_$allocate_pages(pages_marked, 1, ppn_array);
    ml_$unlock(ml_$pmap_lock);
    disk_$get_qblks(alloc_count, qblk_head, qblk_tail);
    qb := qblk_head;
    qb^.header.hint := area_page;
    qb^.header.uid.high := anon_$uid.high;
    qb^.header.uid.low := area_id;
    qb^.header.byte_10 := chr(0);
    segmap := addr(ast_pmaps[seg_index, page]);
    for i := 1 to alloc_count do begin
      qb^.ppn := ppn_array[i];
      qb^.daddr.daddr := segmap^.dentry.daddr;
      segmap := ast_$pmap_entry_ptr_t(integer32(segmap) + 4);
      qb := disk_$io_req_ptr_t(qb^.free_next);
    end;
    disk_$read_multi(entry^.volx, true, true, qblk_head, qblk_tail,
                     pages_read, status);
    pages_done := pages_read;
    ml_$lock(ml_$pmap_lock);
    disk_$rtn_qblks(alloc_count, qblk_head, qblk_tail);
    if pages_done < alloc_count then
      for i := pages_done + 1 to alloc_count do
        mmap_$free(ppn_array[i]);
    proc1_$stats[proc1_$current].stat[3] :=
      proc1_$stats[proc1_$current].stat[3] + pages_done;
  end;

  if status.all <> status_$ok then
    status.fail := true;
  with proc1_$stats[proc1_$current] do
    stat[1] := stat[1] + pages_done;

  { the entries left in transition }
20:
  segmap := addr(ast_pmaps[seg_index, page]);
  if pages_done < pages_marked then
    ast_$clear_transition_bits(ast_pmaps[seg_index, pages_done + page],
                               pages_marked - pages_done);

  { install the pages }
  if status.all = status_$ok then begin
    for i := 1 to pages_done do begin
      with mmap[ppn_array[i]] do begin
        if in_wsl then
          crash_system(status_$mmap_bad_install);
        wire_count := 0;
        modified := false;
        impure := true;
        flags2_7 := true;
        seg_offset := i + page - 1;
        segment := seg_index;
%if pmmu_page_maps %then
        disk_addr.all := segmap^.vpn;
%else
        disk_addr.all := segmap^.all & 16#7FFFFF;
%endif
      end;
      segmap^.vpn := ppn_array[i];
      segmap^.flags := segmap^.flags + [ast_$pmap_resident];
%if pmmu_page_maps %then
      segmap^.flags := segmap^.flags + [ast_$pmap_used];
      segmap^.flags := segmap^.flags - [ast_$pmap_modified];
%else
      pft[segmap^.vpn].w_02 := (pft[segmap^.vpn].w_02 & 16#BFFF) ! 16#2000;
%endif
      segmap^.flags := segmap^.flags + [ast_$pmap_installed];
      segmap^.flags := segmap^.flags - [ast_$pmap_in_trans];
      segmap := ast_$pmap_entry_ptr_t(integer32(segmap) + 4);
    end;
    mmap_$install_list(ppn_array, pages_done, false);
    ast[seg_index].page_count := chr(ord(ast[seg_index].page_count) +
                                     pages_done);
  end;

  ast_$page_flt_cnt := ast_$page_flt_cnt + 1;
  if netlog_$ok_to_log then
    if entry^.remote_volx <> 0 then
      netlog_$log_it(log_op, req.uid, area_page div 32, page, ppn_array[1],
                     pages_done, 1, 0)
    else
      netlog_$log_it(log_op, req.uid, area_page div 32, page, ppn_array[1],
                     pages_done, 0, 0);

  ec_$advance(ast_$pmap_in_trans_ec);
end;
