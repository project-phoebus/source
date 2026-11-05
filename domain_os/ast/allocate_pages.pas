{ ast_$allocate_pages - take physical pages for the caller's list.

  Image addresses:
    sau2  0x00E00D46  ast_$allocate_pages (module-local)
    sau2  0x00E00CAC  ast_$allocate_pages_log (nested)
    sau4  0x0F80114A  ast_$allocate_pages (module-local)
    sau4  0x0F8010AC  ast_$allocate_pages_log (nested)
    sau6  0x7800152A  ast_$allocate_pages (module-local)
    sau6  0x7800148C  ast_$allocate_pages_log (nested)
    sau7  0x3C40192A  ast_$allocate_pages (module-local)
    sau7  0x3C40188C  ast_$allocate_pages_log (nested)
    sau9  0x3C40212A  ast_$allocate_pages (module-local)
    sau9  0x3C40208C  ast_$allocate_pages_log (nested)

  Assume we're called with the PMAP lock held.

  - Pages come from MMAP's free pool, then its pure pool; a pure page is
    taken back from its segment, whose page-map entry must still name
    it (or the system crashes).
  - Until min_count pages are taken the purifier is woken and the
    routine tries again.  The result is the number of pages taken.
  - ast_$allocate_pages_log, nested, writes a NETLOG record.

  Status stored: none.
}

function ast_$allocate_pages(num_pages: pinteger; min_count: pinteger;
                             out ppn_array: univ ast_$ppn_list_t): pinteger;
  internal;
label
  10;
var
  allocated: pinteger;
  count: pinteger;
  i: integer;
  seg: pinteger;
  p: ast_$ppn_ptr_t;

  procedure ast_$allocate_pages_log(in pmape: mmap_$mmape_t; seg: pinteger;
                                    ppn: integer32);
  var
    log_uid: uid_$t;
  begin
    with ast[pmape.segment] do
      if pmape.flags2_7 then begin
        log_uid.high := anon_$uid.high;
        log_uid.low := ast_$clock_words_t(aote^.dtm)[2];
        netlog_$log_it(4, log_uid, segment, pmape.seg_offset, ppn,
                       allocated, min_count, 0);
      end
      else
        netlog_$log_it(4, aote^.uid, segment, pmape.seg_offset, ppn,
                       allocated, min_count, 0);
  end;

begin
  p := addr(ppn_array);
  ast_$alloc_cnt := ast_$alloc_cnt + 1;
  allocated := 0;

  repeat
    { the free pool }
    count := mmap_$alloc_free(p^, num_pages);
    if count <> 0 then begin
      allocated := allocated + count;
      num_pages := num_pages - count;
      if num_pages = 0 then
        goto 10;
      p := ast_$ppn_ptr_t(integer32(p) + count * 4);
    end;

    { the pure pool }
    count := mmap_$alloc_pure(p^, num_pages);
    num_pages := num_pages - count;

    { each pure page leaves its segment }
    for i := 1 to count do begin
      with mmap[p^] do begin
        seg := segment;
        with ast_pmaps[seg, seg_offset] do begin
          if (vpn <> p^) or else (ast_$pmap_in_trans in flags) or else
             not (ast_$pmap_installed in flags) or else
             (ast_$pmap_resident in flags) then
            crash_system(status_$pmap_mismatch);
          flags := flags - [ast_$pmap_installed];
%if pmmu_page_maps %then
          vpn := disk_addr.all;
%else
          fentry.fm_daddr := linteger(disk_addr.all);
%endif
        end;
        ast[seg].page_count := pred(ast[seg].page_count);
        if netlog_$ok_to_log then
          ast_$allocate_pages_log(mmap[p^], seg, p^);
      end;
      allocated := allocated + 1;
      p := ast_$ppn_ptr_t(integer32(p) + 4);
    end;

    if allocated >= min_count then
      exit;
    pmap_$wake_purifier(true);
  until false;

  if num_pages <> 0 then
    ast_$alloc_too_few_cnt := ast_$alloc_too_few_cnt + 1;

10:
  if mmap_$wsl[0].page_count + mmap_$wsl[1].page_count +
     mmap_$wsl[2].page_count < pmap_$low_thresh then
    pmap_$wake_purifier(false);

  ast_$allocate_pages := allocated;
end;
