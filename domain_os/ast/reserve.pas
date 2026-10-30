{ AST_$RESERVE - make sure a run of an object's pages has disk blocks.

  Image addresses:
    sau2  0x00E0677E  AST_$RESERVE
    sau9  0x3C407A02  AST_$RESERVE

  - Inhibited and under the AST lock, the object's AOTE is found (marked
    busy) or activated.  A remote object's request goes to its node
    (REM_FILE_$RESERVE).
  - A local object's segments holding the run are visited from the last
    down; under the PMAP lock each run of entries with neither a page
    nor a disk address gets its blocks (ast_$setup_page_read).

  Status stored:
    status_$ok: the blocks were reserved
    the callees' statuses: the activation, a segment's ASTE, a block
      allocation or the remote call failed
}

procedure ast_$reserve(in uid: uid_$t; start_page: integer32;
                       page_count: integer32; out status: status_$t);
label
  10, 20, 30, 40, 50, 60, 70;
var
  node_addr: ast_node_addr_t;
  aste: ast_$aste_ptr_t;
  page: integer32;
  entry: ast_$pmap_entry_ptr_t;
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
  ent: ast_$pmap_entry_ptr_t;
  last_in_seg: pinteger;
  cur: pinteger;
  seg: pinteger;
  run: pinteger;
  i: integer;
begin
  status.all := status_$ok;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, status, false);
    if aote = nil then goto 20;
  end
  else
    aote^.flags := aote^.flags + [6];

  if aote^.loc.remote then goto 40;

  { the last page, its segment and offset }
  aote^.flags := aote^.flags + [7];
  page := start_page + page_count - 1;
  seg := rshft(page, 5);
  last_in_seg := page & 16#1F;

  { the segment's ASTE }
50:
  aste := ast_$lookup_aste(aote^, seg);
  if aste <> nil then goto 60;
  aste := ast_$lookup_or_create_aste(aote^, seg, status);
  if aste <> nil then goto 60;

10:
  aote^.flags := aote^.flags - [7];
  ec_$advance(ast_$ast_in_trans_ec);
20:
  ml_$unlock(ml_$ast_lock);
  goto 30;

  { the segment's first page to do }
60:
  page := page - last_in_seg;
  if page < start_page then page := start_page;

  aste^.flag_bits.in_trans := true;
  aste^.flag_bits.locked := true;
  ml_$unlock(ml_$ast_lock);
  ml_$lock(ml_$pmap_lock);

  cur := page & 16#1F;
  entry := addr(ast_pmaps[aste^.seg_index][cur]);

  { pages cur .. last_in_seg }
  repeat
    while ast_$pmap_in_trans in entry^.flags do
      ast_$wait_for_page_transition;
%if pmmu_page_maps %then
    if (ast_$pmap_installed in entry^.flags) or else (entry^.vpn <> 0) then
    begin
%else
    if (ast_$pmap_installed in entry^.flags) or else
       ((entry^.all & 16#7FFFFF) <> 0) then
    begin
%endif
      entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
      cur := cur + 1;
    end
    else begin
      { mark the run in transition }
      run := 0;
      ent := entry;
      repeat
        ent^.flags := ent^.flags + [ast_$pmap_in_trans];
        ent := ast_$pmap_entry_ptr_t(integer32(ent) + 4);
        run := run + 1;
%if pmmu_page_maps %then
      until (last_in_seg - cur < run) or else
            (ast_$pmap_in_trans in ent^.flags) or else
            (ast_$pmap_installed in ent^.flags) or else (ent^.vpn <> 0);
%else
      until (last_in_seg - cur < run) or else
            (ast_$pmap_in_trans in ent^.flags) or else
            (ast_$pmap_installed in ent^.flags) or else
            ((ent^.all & 16#7FFFFF) <> 0);
%endif

      ast_$setup_page_read(aste^, entry^, cur, run, [6], status);
      for i := 1 to run do begin
        entry^.flags := entry^.flags - [ast_$pmap_in_trans];
        entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
      end;

      if status.all <> status_$ok then goto 70;
      cur := cur + run;
    end;
  until cur > last_in_seg;

  { the locks back, wake the waiters }
70:
  ml_$unlock(ml_$pmap_lock);
  ml_$lock(ml_$ast_lock);
  aste^.flag_bits.in_trans := false;
  ec_$advance(ast_$ast_in_trans_ec);

  { the previous segment, all of it }
  if status.all <> status_$ok then goto 10;
  if linteger(page) <= linteger(start_page) then goto 10;
  page := page - 1;
  last_in_seg := 16#1F;
  seg := seg - 1;
  goto 50;

  { a remote object }
40:
  node_addr := ast_aote_addr_view_ptr_t(aote)^.node_addr;
  ml_$unlock(ml_$ast_lock);
  rem_file_$reserve(node_addr.net, uid, start_page, page_count, status);

30:
  proc1_$inhibit_end;
end;

{ TODO(pascal) AST_$RESERVE's two compares of page with start_page

  The SAU2 image compares the same two longwords signed the first time
  and unsigned the second (start_page the heading's integer32, its
  evidence the first compare).  The second is written
  with linteger type transfers, which may not be the original's
  construct (another local's type, or another expression); not
  settled. }
