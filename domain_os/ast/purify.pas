{ AST_$PURIFY - write an object's modified pages back.

  Image addresses:
    sau2  0x00E0567A  AST_$PURIFY
    sau8  0x03C05918  AST_$PURIFY
    sau9  0x3C406924  AST_$PURIFY

  - Inhibited and under the AST lock, each ASTE flags select (all, one
    segment with bit 0, the page list's with bit 4) is written back.
  - A remote object's, or with bit 1, go to PMAP_$FLUSH; else their
    modified pages are marked so in MMAP.
  - A modified object then gets new clocks and its attributes written.
    With bit 1, a local volume is flushed or a remote object purified at
    its node (unless bit 2).
  - Bit 3 stops after 64 pages are written.

  Status stored:
    status_$ok: the object was purified
    status_$ast_incompatible_request: flags has a bit of 5..14 set
    16#3EFFF: bit 3, and pages were written
    the callees' statuses: a flush, an update, the activation or the
      remote purify failed
}

procedure ast_$purify(uid: uid_$t; flags: integer; segment: integer;
                      in page_list: univ ast_$purify_list_t;
                      list_count: integer; out status: status_$t);
label
  20, 30, 40, 60, 90;
const
  ast_purify_more = 16#0003EFFF;
var
  net_node: ast_$net_info_t;
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
  local_status: status_$t;
  flush_flags: pmap_$flush_flags_t;
  list_idx: pinteger;
  written: pinteger;
  vol_idx: integer;
  need_clocks: boolean;
  rem_flags: pinteger;
  aste: ast_$aste_ptr_t;
  match: boolean;
  first_page: pinteger;
  run: integer;
  flushed: integer;
  any_modified: boolean;
  i: integer;
  is_remote: boolean;
  length: linteger;
  chunks: integer;
begin
  if (flags & 16#7FE0) <> 0 then begin
    status.all := status_$ast_incompatible_request;
    return;
  end;

  written := 0;
  local_status.all := status_$ok;
  need_clocks := false;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if aote <> nil then begin
    aote^.flags := aote^.flags + [7];
    aote^.flags := aote^.flags + [6];
    list_idx := 1;
    aste := aote^.aste_list;

    while aste <> nil do begin
      { does this ASTE take part? }
      if 4 in ast_$word_set_t(flags) then
        match := aste^.segment = rshft(page_list[list_idx], 5)
      else if 0 in ast_$word_set_t(flags) then
        match := aste^.segment = segment
      else
        match := true;

      if match then begin
        if 15 in aste^.flags then begin
          ast_$wait_for_ast_intrans;
          aste := aote^.aste_list;
          next;
        end;

        aste^.flags := aste^.flags + [15];
        ml_$unlock(ml_$ast_lock);

        if aote^.loc.remote or else (1 in ast_$word_set_t(flags)) then begin
          { which pages }
          if 4 in ast_$word_set_t(flags) then begin
            first_page := page_list[list_idx] & 16#1F;
            list_idx := list_idx + 1;
            run := 1;
            for i := list_idx to list_count do begin
              if rshft(page_list[i], 5) <> aste^.segment then
                exit;
              if (page_list[i] & 16#1F) <> first_page - 1 then
                exit;
              run := run + 1;
              first_page := first_page - 1;
              list_idx := list_idx + 1;
            end;
          end
          else begin
            first_page := 0;
            run := 32;
          end;

          flush_flags := [];
          if 15 in ast_$word_set_t(flags) then
            flush_flags := [2];
          flushed := pmap_$flush(aste^, ast_pmaps[aste^.seg_index],
                                 first_page, run, flush_flags,
                                 local_status);

          if local_status.all <> status_$ok then begin
            if (local_status.all & 16#7FFFFFFF) <>
               status_$ast_last_page_partially_written then
              goto 30;
            local_status.all := status_$ok;
          end;
          written := written + flushed;

          if 1 in ast_$word_set_t(flags) then begin
            ast_$update_aste(aste^, ast_pmaps[aste^.seg_index], false,
                             local_status);
            if local_status.all <> status_$ok then begin
30:
              ml_$lock(ml_$ast_lock);
              aste^.flags := aste^.flags - [15];
              goto 40;
            end;
          end;

          { the walk's stops }
          if (0 in ast_$word_set_t(flags)) or else
             ((3 in ast_$word_set_t(flags)) and then (written >= 64)) or else
             ((4 in ast_$word_set_t(flags)) and then
              (list_idx > list_count)) then begin
            ml_$lock(ml_$ast_lock);
            aste^.flags := aste^.flags - [15];
            ec_$advance(ast_$ast_in_trans_ec);
            goto 20;
          end;
        end
        else begin
          { the modified marks into the MMAP }
          ml_$lock(ml_$pmap_lock);
          if aste^.page_count <> chr(0) then begin
            any_modified := false;
            for i := 0 to 31 do begin
              while ast_$pmap_in_trans in
                    ast_pmaps[aste^.seg_index, i].flags do
                ast_$wait_for_page_transition;
%if pmmu_page_maps %then
              if (ast_$pmap_installed in
                  ast_pmaps[aste^.seg_index, i].flags) and then
                 (ast_$pmap_modified in
                  ast_pmaps[aste^.seg_index, i].flags) then begin
                ast_pmaps[aste^.seg_index, i].flags :=
                  ast_pmaps[aste^.seg_index, i].flags - [ast_$pmap_modified];
%else
              if (ast_$pmap_installed in
                  ast_pmaps[aste^.seg_index, i].flags) and then
                 (14 in ast_$word_set_t(
                          pft[ast_pmaps[aste^.seg_index, i].vpn].w_02)) then
                begin
                pft[ast_pmaps[aste^.seg_index, i].vpn].w_02 :=
                  pft[ast_pmaps[aste^.seg_index, i].vpn].w_02 & 16#BFFF;
%endif
                mmap[ast_pmaps[aste^.seg_index, i].vpn].modified := true;
                any_modified := true;
              end;
            end;
%if pmmu_page_maps %then
            { the descriptors' modified bits cleared: the cached
              translations flushed }
            if any_modified then begin
              mmu_$purge;
              need_clocks := true;
            end;
%else
            if any_modified then
              need_clocks := true;
%endif
          end;
          ml_$unlock(ml_$pmap_lock);
        end;

        { the ASTE leaves transition }
        ml_$lock(ml_$ast_lock);
        aste^.flags := aste^.flags - [15];
        ec_$advance(ast_$ast_in_trans_ec);
        if 4 in ast_$word_set_t(flags) then
          next;
      end;

      aste := aste^.next;
    end;

20:
    if need_clocks then begin
      ml_$lock(ml_$pmap_lock);
      time_$clock(aote^.dtm);
      aote^.dta := aote^.dtm;
      time_$abs_clock(aote^.dtv);
      ml_$unlock(ml_$pmap_lock);
      aote^.flags := aote^.flags + [5];
    end;

    ast_$purify_aote(aote^, false, local_status);

40:
    aote^.flags := aote^.flags - [7];
    ec_$advance(ast_$ast_in_trans_ec);
    vol_idx := aote^.vol_index;
  end
  else begin
    { not active }
    if not (1 in ast_$word_set_t(flags)) then
      goto 60;
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, local_status, false);
    if aote = nil then begin
      ml_$unlock(ml_$ast_lock);
      proc1_$inhibit_end;
      goto 90;
    end;
    vol_idx := aote^.vol_index;
  end;

  net_node.uid := aote^.obj_loc_addr;
  is_remote := aote^.loc.remote;
  length := aote^.length;

60:
  ml_$unlock(ml_$ast_lock);
  if (1 in ast_$word_set_t(flags)) and then
     (local_status.all = status_$ok) then
    if is_remote then begin
      if not (2 in ast_$word_set_t(flags)) then begin
        flags := flags & 16#7FFF;
        if 0 in ast_$word_set_t(flags) then begin
          rem_flags := flags & 16#7FFF;
          rem_file_$purify(net_node.addr, uid, rem_flags, segment,
                           local_status);
        end
        else begin
          chunks := rshft(length, 16) + 1;
          rem_flags := flags ! 8;
          repeat
            rem_file_$purify(net_node.addr, uid, rem_flags, segment,
                             local_status);
            chunks := chunks - 1;
            if ((chunks = 0) and then
                (local_status.all = ast_purify_more)) or else
               (local_status.all = status_$ast_incompatible_request) then
              rem_file_$purify(net_node.addr, uid, flags, segment,
                               local_status);
          until local_status.all <> ast_purify_more;
        end;
      end;
    end
    else
      dbuf_$update_vol(vol_idx, uid);

  proc1_$inhibit_end;
  if (3 in ast_$word_set_t(flags)) and then
     (local_status.all = status_$ok) and then (written <> 0) then
    local_status.all := ast_purify_more;

90:
  status := local_status;
end;
