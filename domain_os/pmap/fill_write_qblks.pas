{ pmap_$fill_write_qblks - fill a chain of disk requests for a batch of
  page writes.

  Image addresses:
    sau2  0x00E1327E  pmap_$fill_write_qblks
    sau9  0x3C4155DC  pmap_$fill_write_qblks

  - A page with no disk address gets one from BAT_$ALLOCATE, with every
    later page of the batch in its segment that has none.
  - The allocation's hint is the nearest disk address in the segment
    map (backward, then forward), else the segment's file-map block.
  - The PMAP lock is taken only while the hint is looked up; a failed
    allocation crashes the system.

  Status stored: none.
}

procedure pmap_$fill_write_qblks(in pages: pmap_$batch_t;
                                 qblk: disk_$io_req_ptr_t; count: integer);
  internal;
var
  blocks: array[1..16] of linteger;
  needs: array[1..16] of mmap_$mmape_ptr_t;
  seg_entry: ast_$pmap_entry_ptr_t;
  status: status_$t;
  qb: disk_$io_req_ptr_t;
  i: integer;
  page_idx: pinteger;
  vol: integer;
  is_area: boolean;
  n_needed: integer;
  daddr: linteger;
  p: ast_$pmap_entry_ptr_t;
  j: integer;
  k: integer;
begin
  qb := qblk;

  for i := 1 to count do begin
    { the header's object }
    is_area := mmap[pages[i]].flags2_7;
    page_idx := mmap[pages[i]].seg_offset;
    if not is_area then begin
      qb^.header.uid := ast[mmap[pages[i]].segment].aote^.uid;
      qb^.header.sub_type := ast[mmap[pages[i]].segment].aote^.sub_type;
      vol := ast[mmap[pages[i]].segment].aote^.vol_index;
    end
    else begin
      qb^.header.uid.high := anon_$uid.high;
      qb^.header.uid.low :=
        area_$entry_ptr_t(ast[mmap[pages[i]].segment].aote)^.area_id;
      qb^.header.sub_type := chr(0);
      vol := area_$entry_ptr_t(ast[mmap[pages[i]].segment].aote)^.volx;
    end;

    qb^.header.hint := page_idx +
                       lshft(ast[mmap[pages[i]].segment].segment, 5);
    qb^.header.written := time_$current_clockh;
    qb^.header.byte_10 := chr(0);
    for k := 1 to 10 do
      qb^.header.bytes_12[k] := chr(0);
    qb^.owner_op.all := vol;
    seg_entry := addr(ast_pmaps[mmap[pages[i]].segment][page_idx]);

    { a page without a disk address }
    if mmap[pages[i]].disk_addr.daddr = 0 then begin
      n_needed := 0;
      for j := i to count do
        if (mmap[pages[j]].segment = mmap[pages[i]].segment) and then
           (mmap[pages[j]].disk_addr.daddr = 0) then begin
          n_needed := n_needed + 1;
          needs[n_needed] := addr(mmap[pages[j]]);
        end;

      p := seg_entry;
      daddr := 0;
      ml_$lock(ml_$pmap_lock);
      for k := page_idx - 1 downto 0 do begin
        p := ast_$pmap_entry_ptr_t(integer32(p) - 4);
        if ast_$pmap_installed in p^.flags then
          daddr := mmap[p^.vpn].disk_addr.daddr
        else
          daddr := p^.dentry.daddr;
        if daddr <> 0 then
          exit;
      end;
      p := seg_entry;
      if daddr = 0 then begin
        for k := page_idx + 1 to 31 do begin
          p := ast_$pmap_entry_ptr_t(integer32(p) + 4);
          if ast_$pmap_installed in p^.flags then
            daddr := mmap[p^.vpn].disk_addr.daddr
          else
            daddr := p^.dentry.daddr;
          if daddr <> 0 then
            exit;
        end;
        if daddr = 0 then
          daddr := ast[mmap[pages[i]].segment].fm_block.block;
      end;

      ml_$unlock(ml_$pmap_lock);
      bat_$allocate(vol, daddr, n_needed, 1, blocks, status);
      if status.all <> status_$ok then
        crash_system(status);
      for k := 1 to n_needed do
        needs[k]^.disk_addr.daddr := blocks[k];
      ast[mmap[pages[i]].segment].flags :=
        ast[mmap[pages[i]].segment].flags + [13];
    end;

    qb^.daddr.daddr := mmap[pages[i]].disk_addr.daddr;
    qb^.ppn := pages[i];

    if netlog_$ok_to_log then
      netlog_$log_it(3, qb^.header.uid, rshft(qb^.header.hint, 5),
                     page_idx, pages[i], 0, 0, 0);
    qb := qb^.next;
%if pmmu_page_maps %then
    if disk_$do_chksum then begin
      seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
      mmu_$purge;
    end;
%else
    if disk_$do_chksum and then
       (ast_$pmap_resident in seg_entry^.flags) then begin
      seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
      mmu_$remove(pages[i]);
    end;
%endif
  end;
end;
