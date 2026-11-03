{ AST_$TOUCH - make a run of a segment's pages resident and wire them.

  Image addresses:
    sau2  0x00E030C0  AST_$TOUCH
    sau4  0x0F8034EE  AST_$TOUCH
    sau8  0x03C03408  AST_$TOUCH
    sau9  0x3C404414  AST_$TOUCH

  Assume we're called with the PMAP lock held.

  - The run is clipped to the segment's 32 pages and to count.  An
    installed run is wired and handed back; a "no disk copy" run gets
    zeroed pages (ast_$count_valid_pages, nested).
  - Otherwise the run, clipped to the object's length, gets disk blocks
    and fresh pages, or is read from the network or the disk.
  - The pages got are installed, wired and put in the working set; the
    result is their number (0 on a refusal).

  Status stored:
    status_$ok: the pages were made resident
    status_$ast_only_local_access_allowed: a type-8 process and an
      OS-only local object
    status_$pmap_read_concurrency_violation: another concurrency mode
    status_$ast_eof: the run lies beyond the object's length
    status_$pmap_page_null: only existing pages wanted (flags member 1)
    the callees' statuses, with the fail bit when no page was got
}

function ast_$touch(var aste: ast_$aste_t; mode: integer32; page: pinteger;
                    count: pinteger; var ppn_array: univ ast_$ppn_ulist_t;
                    out status: status_$t; flags: pinteger): pinteger;
label
  10;
var
  aote: ast_$aote_view_ptr_t;
  kind: integer;
  concurrency: integer32;
  avail: pinteger;
  entry: ast_$pmap_entry_ptr_t;
  ent: ast_$pmap_entry_ptr_t;
  out: ast_$ppn_ptr_t;
  touched: pinteger;
  run: pinteger;
  page_no: linteger;
  in_file: integer32;
  ppn: linteger;
  p: ast_$ppn_ptr_t;
  i: integer;

%include 'ast/count_valid_pages.pas';       { ast_$count_valid_pages
                                              (nested) }

begin
  status.all := status_$ok;
  aote := ast_$aote_view_ptr_t(aste.aote);

  { a local object's refusals }
  if not aote^.aote.loc.remote then begin
    if aote^.attrs.fattr.ext.ext_7 and then
       (proc1_$type[proc1_$current] = 8) then begin
      status.all := status_$ast_only_local_access_allowed;
      ast_$touch := 0;
      return;
    end;
    concurrency := aote^.attrs.fattr.acl_checksum;
    if (concurrency <> 0) and then (concurrency <> mode) and then
       (concurrency <> 1) and then
       not (11 in aote^.attrs.attr_set) then begin
      status.all := status_$pmap_read_concurrency_violation;
      ast_$touch := 0;
      return;
    end;
  end;

  aote^.aote.flags := aote^.aote.flags + [6];
  aste.flags := aste.flags + [14];
  avail := 32 - page;
  if avail > count then
    avail := count;

  entry := addr(ast_pmaps[aste.seg_index, page]);
  while ast_$pmap_in_trans in entry^.flags do
    ast_$wait_for_page_transition;

  { installed pages }
  if ast_$pmap_installed in entry^.flags then begin
    ent := entry;
    out := addr(ppn_array);
    touched := 0;
    repeat
      ent^.flags := ent^.flags + [ast_$pmap_resident];
      out^ := ent^.vpn;
      out := ast_$ppn_ptr_t(integer32(out) + 4);
      touched := touched + 1;
      ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
      if touched >= avail then
        exit;
%if pmmu_page_maps %then
      if odd(ent^.low) then
        exit;
%else
      if ast_$pmap_resident in ent^.flags then
        exit;
%endif
      if ast_$pmap_in_trans in ent^.flags then
        exit;
    until not (ast_$pmap_installed in ent^.flags);
    if (ppn_array[1] >= mmap_$first_ppn) and then
       (ppn_array[1] <= mmap_$last_ppn) then
      mmap_$reclaim(ppn_array, touched, 5 in ast_$word_set_t(flags));
    ast_$ws_flt_cnt := ast_$ws_flt_cnt + touched;
    aote^.aote.flags := aote^.aote.flags + [4];
    ast_$touch := touched;
    return;
  end;

  { pages with no disk copy }
  kind := 8;
%if pmmu_page_maps %then
  if 15 in entry^.hi_flags then begin
%else
  if 6 in entry^.flags then begin
%endif
    run := 0;
    ent := entry;
    repeat
      ent^.flags := ent^.flags + [ast_$pmap_in_trans];
      run := run + 1;
      ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
      if run >= avail then
        exit;
      if ast_$pmap_in_trans in ent^.flags then
        exit;
      if ast_$pmap_installed in ent^.flags then
        exit;
%if pmmu_page_maps %then
    until not (15 in ent^.hi_flags);
%else
    until not (6 in ent^.flags);
%endif
    touched := ast_$count_valid_pages(entry^, run);
    aote^.aote.flags := aote^.aote.flags + [4];
    goto 10;
  end;

  { the run against the object's length }
  page_no := aste.segment * 32 + page;
  if (aote^.aote.length <> 0) and then
     ((aote^.aote.length - 1) div 16#400 >= page_no) then begin
    in_file := (aote^.aote.length - 1) div 16#400 - page_no + 1;
    if avail > in_file then
      avail := in_file;
  end
  else begin
    if not (0 in ast_$word_set_t(flags)) then begin
      status.all := status_$ast_eof;
      ast_$touch := 0;
      return;
    end;
    if not (1 in ast_$word_set_t(flags)) then
      if count = 32 then begin
        if avail > pinteger(ast_$grow_ahead_cnt) then
          avail := ast_$grow_ahead_cnt;
      end
      else
        avail := 1;
  end;

  { a local run with no disk blocks }
%if pmmu_page_maps %then
  if (entry^.vpn = 0) and then
%else
  if ((entry^.all & 16#7FFFFF) = 0) and then
%endif
     not aote^.aote.loc.remote then begin
    run := 0;
    ent := entry;
    repeat
      ent^.flags := ent^.flags + [ast_$pmap_in_trans];
      run := run + 1;
      ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
      if run >= avail then
        exit;
      if ast_$pmap_in_trans in ent^.flags then
        exit;
      if ast_$pmap_installed in ent^.flags then
        exit;
%if pmmu_page_maps %then
    until ent^.vpn <> 0;
%else
    until (ent^.all & 16#7FFFFF) <> 0;
%endif
    ast_$setup_page_read(aste, entry^, page, run, ast_$word_set_t(flags),
                         status);
    touched := 0;
    if status.all = status_$ok then
      touched := ast_$count_valid_pages(entry^, run);
    goto 10;
  end;

  { a run to read }
  kind := 2;
  run := 0;
  ent := entry;
  repeat
    ent^.flags := ent^.flags + [ast_$pmap_in_trans];
    run := run + 1;
    ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
    if run >= avail then
      exit;
    if ast_$pmap_in_trans in ent^.flags then
      exit;
    if ast_$pmap_installed in ent^.flags then
      exit;
%if pmmu_page_maps %then
    if 15 in ent^.hi_flags then
      exit;
%else
    if 6 in ent^.flags then
      exit;
%endif
  until not aote^.aote.loc.remote and then (ent^.dentry.daddr = 0);

  if aote^.aote.loc.remote then
    touched := ast_$read_area_pages_network(aste, entry^, ppn_array, page,
                                            run,
                                            0 in ast_$word_set_t(flags),
                                            status)
  else begin
    aote^.aote.flags := aote^.aote.flags + [4];
    touched := ast_$read_area_pages(aste, entry^, ppn_array, page, run,
                                    status);
  end;
  with proc1_$stats[proc1_$current] do
    if 3 in ast_$word_set_t(flags) then
      stat[2] := stat[2] + touched
    else
      stat[1] := stat[1] + touched;

  { the entries left in transition }
10:
  if touched < run then
    ast_$clear_transition_bits(ast_pmaps[aste.seg_index, touched + page],
                               run - touched);

  if touched <> 0 then begin
    if status.all = status_$ok then begin
      { install each page }
      p := addr(ppn_array);
      ent := entry;
      for i := 0 to touched - 1 do begin
        ppn := p^;
        p := ast_$ppn_ptr_t(integer32(p) + 4);
        if ppn = 0 then
          crash_system(status_$pmap_mismatch);
        with mmap[ppn] do begin
          if in_wsl then
            crash_system(status_$mmap_bad_install);
          wire_count := 0;
          modified := false;
          impure := false;
          if 3 in ast_$word_set_t(flags) then
            impure := true;
          flags2_7 := false;
          seg_offset := i + page;
          segment := aste.seg_index;
%if pmmu_page_maps %then
          disk_addr.all := ent^.vpn;
%else
          disk_addr.all := ent^.all & 16#7FFFFF;
%endif
        end;
        ent^.vpn := ppn;
%if pmmu_page_maps or region_mmu %then
        { the descriptor used and not modified }
        ent^.flags := ent^.flags + [ast_$pmap_used];
        ent^.flags := ent^.flags - [ast_$pmap_modified];
%else
        pft[ppn].w_02 := (pft[ppn].w_02 & 16#BFFF) ! 16#2000;
%endif
        ent^.flags := ent^.flags + [ast_$pmap_resident];
        ent^.flags := ent^.flags + [ast_$pmap_installed];
        ent^.flags := ent^.flags - [ast_$pmap_in_trans];
        ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
      end;

      mmap_$install_list(ppn_array, touched, 5 in ast_$word_set_t(flags));
      aste.page_count := chr(ord(aste.page_count) + touched);
      ec_$advance(ast_$pmap_in_trans_ec);
    end;

    ast_$page_flt_cnt := ast_$page_flt_cnt + touched;
    if netlog_$ok_to_log then
      if aote^.aote.loc.remote then
        netlog_$log_it(kind, aote^.aote.uid, aste.segment, page,
                       ppn_array[1], touched, 1, 0)
      else
        netlog_$log_it(kind, aote^.aote.uid, aste.segment, page,
                       ppn_array[1], touched, 0, 0);
  end
  else
    status.fail := true;

  ast_$touch := touched;
end;
