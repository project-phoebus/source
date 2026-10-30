{ AST_$GET_SEG_MAP - build the bitmap of the pages an object has.

  Image addresses:
    sau2  0x00E06B1E  AST_$GET_SEG_MAP
    sau9  0x3C407DAC  AST_$GET_SEG_MAP

  - The output is eight longwords of bits, cleared first; each segment
    the range touches is activated and its pages looked at under the
    PMAP lock.
  - A page counts when flags member 0 is set, or it is installed and
    modified or not on disk yet, or it has a disk address with bit 22
    clear.  A remote object's map is REM_FILE_$GET_SEG_MAP's.
  - The bit-expansion loop runs only when seg_count is 0.

  Status stored:
    status_$ok: the map was built (also when a segment has no file map)
    the callees' statuses, with the fail bit for VTOCE_$LOOKUP_FM's: a
      segment could not be activated, or the remote call failed
}

procedure ast_$get_seg_map(in uid: uid_$t; start_offset: linteger;
                           location: integer32; seg_count: linteger;
                           map_size: linteger;
                           flags: ast_$seg_map_flags_t;
                           out output: ast_$seg_map_t;
                           out status: status_$t);
var
  reply: ast_$seg_map_t;
  node_addr: ast_node_addr_t;
  length: linteger;
  aote: ast_$aote_ptr_t;
  start_seg: linteger;
  aste: ast_$aste_ptr_t;
  entry: ast_$pmap_entry_ptr_t;
  seg_bytes: linteger;
  aligned_start: linteger;
  end_seg: linteger;
  alloc_count: integer32;
  fm_loc: fm_$block_addr_t;
  first_page: integer32;
  last_page: integer32;
  rel_off: linteger;
  bit: pinteger;
  word_idx: pinteger;
  seg: pinteger;
  page: integer;                          { not read }
  i: integer;
  is_remote: boolean;
  present: boolean;
  b: pinteger;
  j: integer;
begin
  status.all := status_$ok;
  for i := 0 to 7 do
    output[i] := [];

  seg_bytes := seg_count * 32 * 1024;
  aligned_start := start_offset & 16#FFFFFC00;
  start_seg := rshft(aligned_start, 15);
  if map_size <= 32 then
    end_seg := start_seg
  else
    end_seg := rshft(lshft(map_size, 10), 15) + start_seg - 1;

  for seg := start_seg to end_seg do begin
    proc1_$inhibit_begin;
    ml_$lock(ml_$ast_lock);

    aote := ast_$lookup_aote_by_uid(uid);
    if aote = nil then begin
      location := 0;
      { location is the reviewed heading's integer32; the callee's formal
        (ast/force_activate_segment.pas) is ast_$loc_word_t, the same 4
        bytes: a type transfer (ref p. 4-197). }
      aote := ast_$force_activate_segment(uid, ast_$loc_word_t(location),
                                          status, false);
      if aote = nil then begin
        ml_$unlock(ml_$ast_lock);
        proc1_$inhibit_end;
        return;
      end;
    end
    else
      aote^.flags := aote^.flags + [6];

    length := aote^.length;
    aste := ast_$lookup_aste(aote^, seg);
    if (aste = nil) and then not aote^.loc.remote then begin
      ast_$aote_view_ptr_t(aote)^.ref_count :=
        ast_$aote_view_ptr_t(aote)^.ref_count + 1;
      ml_$unlock(ml_$ast_lock);
      vtoce_$lookup_fm(ast_$aote_view_ptr_t(aote)^.obj_loc.vtoc, seg,
                       false, fm_loc, alloc_count, status);
      if status.all <> status_$ok then begin
        if status.all = status_$vtoc_no_file_map then
          status.all := status_$ok
        else
          status.fail := true;
        ast_$aote_view_ptr_t(aote)^.ref_count :=
          ast_$aote_view_ptr_t(aote)^.ref_count - 1;
        proc1_$inhibit_end;
        return;
      end;
      ml_$lock(ml_$ast_lock);
      ast_$aote_view_ptr_t(aote)^.ref_count :=
        ast_$aote_view_ptr_t(aote)^.ref_count - 1;
      aste := ast_$lookup_aste(aote^, seg);
      if aste = nil then begin
        aste := ast_$lookup_or_create_aste(aote^, seg, status);
        if aste = nil then begin
          ml_$unlock(ml_$ast_lock);
          proc1_$inhibit_end;
          return;
        end;
      end;
    end;

    node_addr := ast_aote_addr_view_ptr_t(aote)^.node_addr;
    is_remote := aote^.loc.remote;

    if aste <> nil then begin
      aste^.wire_count := aste^.wire_count + 1;
      ml_$unlock(ml_$ast_lock);
      ml_$lock(ml_$pmap_lock);

      if seg = start_seg then
        first_page := rshft(aligned_start & 16#7FFF, 10)
      else
        first_page := 0;
      rel_off := lshft(seg, 15) + lshft(first_page, 10) - aligned_start;
      entry := addr(ast_pmaps[aste^.seg_index][first_page]);

      if map_size >= 32 then begin
        last_page := (length - seg * 16#8000) div 1024;
        if last_page > 31 then
          last_page := 31;
      end
      else
        last_page := first_page + map_size - 1;

      if aligned_start <= length then
        for page := first_page to last_page do begin
          present := false;
          while ast_$pmap_in_trans in entry^.flags do
            ast_$wait_for_page_transition;
          if ast_$pmap_installed in entry^.flags then begin
            if (ast_$seg_map_all_pages in flags) or else
               not mmap[entry^.vpn].disk_addr.aste_dirty or else
               mmap[entry^.vpn].modified or else
%if pmmu_page_maps %then
               (ast_$pmap_modified in entry^.flags) then
%else
               (14 in ast_$word_set_t(pft[entry^.vpn].w_02)) then
%endif
              present := true;
          end
          else if (entry^.dentry.daddr <> 0) and then
                  ((ast_$seg_map_all_pages in flags) or else
%if pmmu_page_maps %then
                   not (15 in entry^.hi_flags)) then
%else
                   not (6 in entry^.flags)) then
%endif
            present := true;

          if present then begin
            word_idx := rel_off div seg_bytes;
            bit := rshft(rel_off mod seg_bytes, 10) div seg_count;
            output[word_idx] := output[word_idx] + [bit];
          end;

          entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
          rel_off := rel_off + 16#400;
        end;

      ml_$unlock(ml_$pmap_lock);
      aste^.wire_count := aste^.wire_count - 1;
    end
    else
      ml_$unlock(ml_$ast_lock);
    proc1_$inhibit_end;

    if is_remote then begin
      rem_file_$get_seg_map(node_addr.net, uid, start_offset, length,
                            ast_$seg_map_all_pages in flags,
                            reply, status);
      for i := 0 to 7 do
        if status.all <> status_$ok then
          output[i] := []
        else
          output[i] := reply[i];
    end
    else if seg_count = 0 then
      for i := 0 to 7 do
        if output[i] <> [] then
          for b := 0 to 31 do
            if b in output[i] then
              for j := b + 1 to (1 div seg_count) + b - 1 do
                output[i] := output[i] + [j];
  end;
end;

{ TODO(pascal) AST_$GET_SEG_MAP: the register-held locals' homes

  (The closing pass settled the other two points this block had:
  seg_count is linteger and flags a set, ast/ast.ins.pas's heading,
  every caller changed to match.)

  The register-held locals' homes: the declaration order
  above fills the SAU2 frame's holes as dpc lays out locals (every
  addressed local at the image's offset), but which local the original
  had where is not known, and the compiler's four temporaries in the
  image are not dpc's, so dpc's frame is smaller. }
