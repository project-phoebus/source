{ pmap_$update_seg_map, pmap_$flush_write_batch, PMAP_$FLUSH - write a
  segment's dirty pages back.

  Image addresses:
    sau2  0x00E1376C  PMAP_$FLUSH
    sau2  0x00E1359C  pmap_$update_seg_map (nested)
    sau2  0x00E1360C  pmap_$flush_write_batch (nested)
    sau8  0x03C14986  PMAP_$FLUSH
    sau8  0x03C147B8  pmap_$update_seg_map (nested)
    sau8  0x03C14828  pmap_$flush_write_batch (nested)
    sau9  0x3C415A9A  PMAP_$FLUSH
    sau9  0x3C4158CC  pmap_$update_seg_map (nested)
    sau9  0x3C41593C  pmap_$flush_write_batch (nested)

  - The PMAP lock is held throughout, except while pages are written or
    waited for.
  - With page-descriptor page maps the translations are flushed
    (MMU_$PURGE) before each write and batch, and after a page is
    invalidated.
  - flags bit 0 invalidates the pages (their translations removed), else
    they are made available again; bit 1 drops modified pages unwritten;
    bit 2 writes remote pages asynchronously.
  - Local pages are written in batches of 16, remote ones one at a time;
    the walk is repeated while pages were found in transit.
  - A page whose MMAP entry names another offset, or a failed batch
    write, crashes the system.

  Status stored:
    status_$ok: the pages were flushed
    status_$pmap_pages_wired: a page is wired or outside the pageable
      range
    pmap_$write_page's status: a remote page's write failed
    a batched page's status: a local page's write failed (a status of -1
      is not stored)
}

function pmap_$flush(var aste: ast_$aste_t; var segmap: ast_$pmap_t;
                     start_page: integer; count: integer;
                     flags: pmap_$flush_flags_t;
                     out status: status_$t): integer;
var
  batch_vpns: pmap_$batch_t;
  n_batch: integer;
  is_area: boolean;
  was_dirty: boolean;
  batched: boolean;
  dirty_seen: boolean;
  waited: boolean;
  written: integer;
  remote: boolean;
  page: integer;
  vpn: linteger;
label
  10;

  procedure pmap_$update_seg_map(var entry: ast_$pmap_entry_t;
                                 vpn: linteger; page_idx: integer);
  begin
    if 0 in flags then begin
      ast_$invalidate_page(aste, entry, vpn);
      if netlog_$ok_to_log then
        netlog_$log_it(5, aste.aote^.uid, aste.segment, page_idx, vpn,
                       0, 0, 0);
    end
    else
      mmap_$avail(vpn);
  end;

  procedure pmap_$flush_write_batch;
  var
    wstatus: status_$t;
    qtail: disk_$io_req_ptr_t;
    qhead: disk_$io_req_ptr_t;
    first: disk_$io_req_ptr_t;
    q: disk_$io_req_ptr_t;
    i: integer;
    vpn: linteger;
    seg_offset: integer;
  begin
    ml_$unlock(ml_$pmap_lock);
    disk_$get_qblks(n_batch, qhead, qtail);
    first := qhead;
    pmap_$fill_write_qblks(batch_vpns, first, n_batch);
    disk_$write_multi(true, first, wstatus);
    if wstatus.all <> status_$ok then
      crash_system(wstatus);
    ml_$lock(ml_$pmap_lock);

    q := first;
    for i := 1 to n_batch do begin
      vpn := q^.ppn;
      pmap_$write_complete(vpn, q^.status);
      if q^.status.all = status_$ok then begin
        proc1_$stats[proc1_$current].stat[3] :=
          proc1_$stats[proc1_$current].stat[3] + 1;
        seg_offset := mmap[vpn].seg_offset;
        if netlog_$ok_to_log then
          netlog_$log_it(3, q^.header.uid, rshft(q^.header.hint, 5),
                         seg_offset, vpn, 0, 0, 0);
        pmap_$update_seg_map(segmap[seg_offset], vpn, seg_offset);
      end
      else if q^.status.all <> -1 then
        status.all := q^.status.all;
      q := q^.free_next;
    end;

    ec_$advance(ast_$pmap_in_trans_ec);
    disk_$rtn_qblks(n_batch, first, qtail);
    n_batch := 0;
  end;

begin
  status.all := status_$ok;
  n_batch := 0;
  written := 0;
  is_area := 12 in aste.flags;
  remote := 11 in aste.flags;
  dirty_seen := false;
  ml_$lock(ml_$pmap_lock);

  while aste.page_count <> chr(0) do begin
    waited := false;
    batched := false;
    for page := start_page to start_page + count - 1 do begin
      if ast_$pmap_in_trans in segmap[page].flags then
        waited := true
      else if ast_$pmap_installed in segmap[page].flags then begin
        { in a shutdown, only pageable pages }
        if pmap_$shutting_down_flag then
          if (segmap[page].vpn < mmap_$first_ppn) or else
             (segmap[page].vpn > mmap_$last_ppn) then
            next;

        vpn := segmap[page].vpn;
        if (vpn < mmap_$first_ppn) or else (vpn > mmap_$last_ppn) or else
           (mmap[vpn].wire_count <> 0) then begin
          if n_batch > 0 then begin
%if pmmu_page_maps %then
            mmu_$purge;
%endif
            pmap_$flush_write_batch;
          end;
          status.all := status_$pmap_pages_wired;
          goto 10;
        end;

        if mmap[vpn].seg_offset <> page then
          crash_system(status_$pmap_mismatch);
        mmap_$unavail_remov(vpn, true);
%if pmmu_page_maps %then
        { a resident descriptor is made invalid, and the translations
          flushed }
        if (0 in flags) and then odd(segmap[page].low) then begin
          segmap[page].flags := segmap[page].flags - [ast_$pmap_resident];
          mmu_$purge;
        end;

        if (ast_$pmap_modified in segmap[page].flags) or else
           mmap[vpn].modified then begin
          if ast_$pmap_modified in segmap[page].flags then
            dirty_seen := true;
          segmap[page].flags := segmap[page].flags - [ast_$pmap_modified];
%else
        if (0 in flags) and then
           (ast_$pmap_resident in segmap[page].flags) then begin
          segmap[page].flags := segmap[page].flags - [ast_$pmap_resident];
          mmu_$remove(vpn);
        end;

        if ((pft[vpn].w_02 & 16#4000) <> 0) or else
           mmap[vpn].modified then begin
          if (pft[vpn].w_02 & 16#4000) <> 0 then
            dirty_seen := true;
          pft[vpn].w_02 := pft[vpn].w_02 & ~16#4000;
%endif
          was_dirty := true;
          mmap[vpn].modified := false;
          if not (1 in flags) then begin
            batched := true;
            written := written + 1;
            if remote then begin
%if pmmu_page_maps %then
              mmu_$purge;
%endif
              pmap_$write_page(vpn, status, not (2 in flags));
              if status.all <> status_$ok then
                goto 10;
              pmap_$update_seg_map(segmap[page], vpn, page);
            end
            else begin
              segmap[page].flags :=
                segmap[page].flags + [ast_$pmap_in_trans];
              n_batch := n_batch + 1;
              batch_vpns[n_batch] := vpn;
              if n_batch = 16 then begin
%if pmmu_page_maps %then
                mmu_$purge;
%endif
                pmap_$flush_write_batch;
                if status.all <> status_$ok then
                  goto 10;
              end;
            end;
          end;
        end
        else
          was_dirty := false;

        if not was_dirty or else (1 in flags) then
          pmap_$update_seg_map(segmap[page], vpn, page);
      end;
    end;

    if n_batch > 0 then begin
%if pmmu_page_maps %then
      mmu_$purge;
%endif
      pmap_$flush_write_batch;
      if status.all <> status_$ok then
        goto 10;
    end;
    if not waited then
      goto 10;
    if not batched then
      pmap_$wait_in_transit;
  end;

  { stamp the object once its pages are written }
10:
  if dirty_seen and then not remote and then not is_area then
    with aste.aote^ do begin
      time_$abs_clock(dtv);
      time_$clock(dtm);
      dta := dtm;
      flags := flags + [5];
    end;

  ml_$unlock(ml_$pmap_lock);
  pmap_$flush := written;
end;
