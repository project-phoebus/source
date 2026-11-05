{ ast_$deactivate_segment - deactivate one segment.

  Image addresses:
    sau2  0x00E01950  ast_$deactivate_segment (module-local)
    sau2  0x00E01872  ast_$deactivate_segment_log (nested)
    sau4  0x0F801D58  ast_$deactivate_segment (module-local)
    sau4  0x0F801C82  ast_$deactivate_segment_log (nested)
    sau6  0x780020E8  ast_$deactivate_segment (module-local)
    sau6  0x78002012  ast_$deactivate_segment_log (nested)
    sau7  0x3C4024FE  ast_$deactivate_segment (module-local)
    sau7  0x3C402426  ast_$deactivate_segment_log (nested)
    sau9  0x3C402CFE  ast_$deactivate_segment (module-local)
    sau9  0x3C402C26  ast_$deactivate_segment_log (nested)

  - With the AST lock released, the segment's pages are flushed and,
    unless purge and keep are both set, its map written back.
  - A segment that is not an area's is then unlinked from its AOTE.
  - ast_$deactivate_segment_log, nested, writes a NETLOG record of the
    segment's pages.

  Status stored:
    status_$ok: the segment was deactivated
    status_$ast_segment_not_deactivatable: in transition, wired, or
      dirty and remote for a type-8 or 9 process
    pmap_$flush's, area_$deactivate_aste's or ast_$update_aste's status,
      with the fail bit: a step failed
}

procedure ast_$deactivate_segment(var aste: ast_$aste_t; purge: boolean;
                                  keep: boolean; out status_ret: status_$t);
  internal;
label
  10;
var
  mode: pmap_$flush_flags_t;
  p: ast_$aste_ptr_t;

  procedure ast_$deactivate_segment_log(var segmap: ast_$pmap_t);
  var
    log_uid: uid_$t;
    marked: integer;
    i: integer;
  begin
    marked := 0;
    if aste.page_count <> chr(0) then begin
      ml_$lock(ml_$pmap_lock);
      for i := 0 to 31 do
%if pmmu_page_maps or region_mmu %then
        if (ast_$pmap_installed in segmap[i].flags) and then
           (ast_$pmap_used in segmap[i].flags) then
%else
        if (ast_$pmap_installed in segmap[i].flags) and then
           (13 in ast_$word_set_t(pft[segmap[i].vpn].w_02)) then
%endif
          marked := marked + 1;
      ml_$unlock(ml_$pmap_lock);
    end;

    if 12 in aste.flags then begin
      log_uid.high := anon_$uid.high;
      log_uid.low := ast_$clock_words_t(aste.aote^.dtm)[2];
    end
    else
      log_uid := aste.aote^.obj_loc_uid;

%if pmap_threads %then
    netlog_$log_it(1, log_uid, aste.segment, ord(aste.page_count),
                   aste.seg_index, aste.pmap_link.asid, aste.pmap_link.seg,
                   marked);
%else
    netlog_$log_it(1, log_uid, aste.segment, ord(aste.page_count),
                   aste.seg_index, 0, 0, marked);
%endif
  end;

begin
  if (15 in aste.flags) or else (aste.wire_count <> 0) or else
     (((13 in aste.flags) and (11 in aste.flags)) and then
      ((proc1_$type[proc1_$current] = 8) or else
       (proc1_$type[proc1_$current] = 9))) then begin
    status_ret.all := status_$ast_segment_not_deactivatable;
    return;
  end;

  aste.flags := aste.flags + [15];
  if netlog_$ok_to_log then
    ast_$deactivate_segment_log(ast_pmaps[aste.seg_index]);
  ml_$unlock(ml_$ast_lock);

  mode := [0];
  if purge then
    mode := [0, 1];
  discard(pmap_$flush(aste, ast_pmaps[aste.seg_index], 0, 32, mode,
                      status_ret));
  if status_ret.all <> status_$ok then
    goto 10;

  if not (purge and keep) then begin
    if 12 in aste.flags then
      area_$deactivate_aste(aste, status_ret)
    else
      ast_$update_aste(aste, ast_pmaps[aste.seg_index], false, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  ml_$lock(ml_$ast_lock);
  if not (12 in aste.flags) then
    with aste.aote^ do begin
%if pmap_threads %then
      mst_$unthread_pmap(aste.pmap_link);
%endif
      if aste_list = addr(aste) then
        aste_list := aste.next
      else begin
        p := aste_list;
        while p^.next <> addr(aste) do
          p := p^.next;
        p^.next := aste.next;
      end;
      status_flags := status_flags - 1;
    end;
  return;

10:
  status_ret.fail := true;
  ml_$lock(ml_$ast_lock);
  aste.flags := aste.flags - [15];
  ec_$advance(ast_$ast_in_trans_ec);
end;
