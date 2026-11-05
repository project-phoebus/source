{ ast_$setup_page_read - give a run of fresh pages their disk blocks.

  Image addresses:
    sau2  0x00E02898  ast_$setup_page_read (module-local)
    sau4  0x0F802CC6  ast_$setup_page_read (module-local)
    sau6  0x78003018  ast_$setup_page_read (module-local)
    sau7  0x3C40340E  ast_$setup_page_read (module-local)
    sau9  0x3C403C0E  ast_$setup_page_read (module-local)

  Assume we're called with the PMAP lock held.

  - For count entries with no page and no disk address: an AREA object's
    blocks are allocated at once (BAT_$ALLOCATE, hinted from the
    previous entry); any other object's only reserved (BAT_$RESERVE).
  - The ASTE is dirtied, the object's length extended to cover the run
    (or the AOTE marked touched), and its block count grown.
  - Nothing is done for an object whose attribute flags have member 1.

  Status stored:
    status_$ok: the blocks were set up, or nothing was to be done
    bat_$allocate's or bat_$reserve's status, with the fail bit: the BAT
      failed (the map left alone)
}

procedure ast_$setup_page_read(var aste: ast_$aste_t;
                               var segmap: univ ast_$pmap_t;
                               start_page: pinteger; count: pinteger;
                               flags: ast_$word_set_t;
                               out status_ret: status_$t);
  internal;
var
  blocks: array[0..31] of linteger;
  hint: linteger;
  aote: ast_$aote_view_ptr_t;
  prev: ast_$pmap_entry_ptr_t;
  i: integer;
  end_offset: integer32;
begin
  aote := ast_$aote_view_ptr_t(aste.aote);
  if 1 in aote^.attrs.attr_set then begin
    status_ret.all := status_$ok;
    return;
  end;

  if 12 in aote^.attrs.attr_set then begin
    { the hint }
    prev := ast_$pmap_entry_ptr_t(integer32(addr(segmap)) - 4);
    if (start_page = 0) or else (prev^.dentry.daddr = 0) then
      hint := aste.fm_block.block
    else if ast_$pmap_installed in prev^.flags then
      hint := mmap[prev^.vpn].disk_addr.daddr
    else
      hint := prev^.dentry.daddr;

    ml_$unlock(ml_$pmap_lock);
    bat_$allocate(aote^.aote.vol_index, hint, count, 0, blocks, status_ret);
    ml_$lock(ml_$pmap_lock);
    if status_ret.all <> status_$ok then begin
      status_ret.fail := true;
      return;
    end;

    for i := 0 to count - 1 do
      with segmap[i] do begin
%if pmmu_page_maps %then
        hi_flags := hi_flags + [15];
%else
        flags := flags + [6];
%endif
        dentry.daddr := blocks[i];
      end;

    if netlog_$ok_to_log then
      for i := 0 to count - 1 do
        netlog_$log_it(9, aote^.aote.uid, aste.segment, start_page + i,
                       rshft(blocks[i], 16), blocks[i], 1, 0);
  end
  else begin
    ml_$unlock(ml_$pmap_lock);
    bat_$reserve(aote^.aote.vol_index, count, status_ret);
    ml_$lock(ml_$pmap_lock);
    if status_ret.all <> status_$ok then begin
      status_ret.fail := true;
      return;
    end;

    for i := 0 to count - 1 do
      with segmap[i] do begin
%if pmmu_page_maps %then
        hi_flags := hi_flags + [15];
%else
        flags := flags + [6];
%endif
        dentry.daddr := 0;
      end;

    if netlog_$ok_to_log then
      netlog_$log_it(9, aote^.aote.uid, aste.segment, start_page, 0, 0,
                     count, 0);
  end;

  aste.flags := aste.flags + [13];

  end_offset := (start_page + count - 1 + aste.segment * 32) * 1024;
  if end_offset >= integer32(aote^.aote.length) then begin
    aote^.aote.length := end_offset + 16#400;
    time_$clock(aote^.aote.dta);
    aote^.aote.dtm := aote^.aote.dta;
  end
  else if not (6 in flags) then
    aote^.aote.flags := aote^.aote.flags + [4];

  aote^.aote.unknown_24 := aote^.aote.unknown_24 + count;
  aote^.aote.flags := aote^.aote.flags + [5];
end;
