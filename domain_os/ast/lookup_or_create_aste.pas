{ ast_$lookup_or_create_aste - find, or build, the ASTE of an object's
  segment.

  Image addresses:
    sau2  0x00E0255C  ast_$lookup_or_create_aste (module-local)
    sau4  0x0F802974  ast_$lookup_or_create_aste (module-local)
    sau6  0x78002CDE  ast_$lookup_or_create_aste (module-local)
    sau7  0x3C4030F4  ast_$lookup_or_create_aste (module-local)
    sau9  0x3C4038F4  ast_$lookup_or_create_aste (module-local)

  Assume we're called with the AST lock held.

  - A fresh ASTE goes into the AOTE's list unless the segment's exists
    (then given back, the existing one the result).
  - A new ASTE's segment map row is zeroed for a remote object, else
    read from the segment's file map with the lock released.
  - On failure the ASTE is given back and the result is nil.  The last
    activation of a dismounting volume wakes its dismount.

  Status stored:
    status_$ok: the ASTE was found or built
    ast_$validate_uid's result: a dismounting volume, or "UID not found"
    vtoce_$lookup_fm's or fm_$read's status: the file map failed
}

function ast_$lookup_or_create_aste(var aote: univ ast_$aote_view_t;
                                    segment: pinteger;
                                    out status_ret: status_$t):
                                    ast_$aste_ptr_t;
  internal;
label
  10, 20, 30, 40;
var
  alloc_count: integer32;
  vol_idx: integer;
  aste: ast_$aste_ptr_t;
  cur: ast_$aste_ptr_t;
  segmap: ast_$segmap_view_ptr_t;
  prev: ast_$aste_ptr_t;
  i: integer;
begin
  { a local object's volume }
  if not aote.aote.loc.remote then begin
    vol_idx := aote.aote.vol_index;
    if vol_idx in ast_$vol_info_count then begin
      status_ret.all := ast_$validate_uid(aote.aote.uid, 16#30F00);
      ast_$lookup_or_create_aste := nil;
      return;
    end;
    ast_$vol_indices[vol_idx] := ast_$vol_indices[vol_idx] + 1;
  end;

  { the fresh ASTE }
  aote.ref_count := aote.ref_count + 1;
  aste := ast_$allocate_aste;
  aste^.flag_bits.in_trans := true;
  aste^.flag_bits.locked := false;
  aste^.flag_bits.dirty := false;
  aste^.flag_bits.area := false;
  aste^.flag_bits.remote := aote.aote.loc.remote;
  if aote.aote.loc.remote then
    ast_$aste_r_cnt := ast_$aste_r_cnt + 1
  else
    ast_$aste_l_cnt := ast_$aste_l_cnt + 1;
  aste^.page_count := chr(0);
  aste^.wire_count := 0;
  aste^.aote := addr(aote);
  aste^.segment := segment;
%if pmap_threads %then
  aste^.pmap_link.asid := -1;
%endif

  if netlog_$ok_to_log then
    netlog_$log_it(0, aote.aote.uid, segment, 0, aste^.seg_index, 0, 0,
                   0);

  { into the list, by descending segment }
10:
  cur := aote.aote.aste_list;
  if (cur = nil) or else (segment > cur^.segment) then begin
    aote.aote.aste_list := aste;
    aste^.next := cur;
  end
  else begin
    repeat
      if segment = cur^.segment then
        goto 40;
      if (cur^.next = nil) or else (segment > cur^.next^.segment) then
        exit;
      cur := cur^.next;
    until false;
    aste^.next := cur^.next;
    cur^.next := aste;
    goto 30;
40:
    if 15 in cur^.flags then begin
      ast_$wait_for_ast_intrans;
      goto 10;
    end;
    ast_$free_aste(aste^);
    status_ret.all := status_$ok;
    aste := cur;
    goto 20;
  end;

30:
  aote.aote.status_flags := aote.aote.status_flags + 1;
  segmap := ast_$segmap_view_ptr_t(addr(ast_pmaps[aste^.seg_index]));

  { the segment map }
  if not aote.aote.loc.remote then begin
    ml_$unlock(ml_$ast_lock);
    vtoce_$lookup_fm(aote.obj_loc.vtoc, segment, true,
                     ast_$aste_view_ptr_t(aste)^.fm_loc, alloc_count,
                     status_ret);
    if status_ret.all = status_$ok then begin
      if alloc_count <> 0 then begin
        ml_$lock(ml_$pmap_lock);
        aote.aote.unknown_24 := aote.aote.unknown_24 + alloc_count;
        aote.aote.flags := aote.aote.flags + [5];
        ml_$unlock(ml_$pmap_lock);
      end;
      fm_$read(aote.obj_loc.fm, ast_$aste_view_ptr_t(aste)^.fm_loc,
               segment, segmap^.fm, status_ret);
    end;
    ml_$lock(ml_$ast_lock);
    if status_ret.all = status_$ok then
      for i := 0 to 31 do
        with segmap^.pmap[i] do begin
%if pmmu_page_maps %then
          { the file map's disk address into the descriptor's address
            field, the flags cleared }
          dentry.daddr := fm_daddr;
          flags := flags - [0..9];
%elseif region_mmu %then
          { the file map's no-disk-copy bit into member 6, the flags
            cleared one by one }
          if 15 in flags then begin
            flags := flags - [15];
            flags := flags + [6];
          end;
          flags := flags - [ast_$pmap_resident];
          flags := flags - [ast_$pmap_used];
          flags := flags - [ast_$pmap_modified];
          flags := flags - [12];
          flags := flags - [11];
          flags := flags - [ast_$pmap_in_trans];
          flags := flags - [ast_$pmap_installed];
          flags := flags - [7..8];
%else
          if 15 in flags then begin
            flags := flags - [15];
            flags := flags + [6];
          end;
          flags := flags - [13];
          flags := flags - [15];
          flags := flags - [14];
          flags := flags - [7..12];
%endif
        end;
  end
  else begin
    for i := 0 to 31 do
      segmap^.pmap[i].all := 0;
    status_ret.all := status_$ok;
  end;

  { failed, or the transition ended }
  if status_ret.all <> status_$ok then begin
    if status_ret.all = 16#20006 then
      status_ret.all := ast_$validate_uid(aote.aote.uid, status_ret.all);
    if aote.aote.aste_list = aste then
      aote.aote.aste_list := aste^.next
    else begin
      prev := aote.aote.aste_list;
      while prev^.next <> aste do
        prev := prev^.next;
      prev^.next := aste^.next;
    end;
    aote.aote.status_flags := aote.aote.status_flags - 1;
    ast_$free_aste(aste^);
    aste := nil;
  end
  else begin
    aste^.flag_bits.in_trans := false;
    ec_$advance(ast_$ast_in_trans_ec);
  end;

  { the holds dropped }
20:
  if not aote.aote.loc.remote then begin
    ast_$vol_indices[vol_idx] := ast_$vol_indices[vol_idx] - 1;
    if (ast_$vol_indices[vol_idx] = 0) and then
       (vol_idx in ast_$vol_info_count) then
      ec_$advance(ast_$dism_ec);
  end;
  aote.ref_count := aote.ref_count - 1;
  ast_$lookup_or_create_aste := aste;
end;
