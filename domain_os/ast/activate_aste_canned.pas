{ AST_$ACTIVATE_ASTE_CANNED - activate one segment of an object at boot.

  Image addresses:
    sau2  0x00E2F1D4  AST_$ACTIVATE_ASTE_CANNED
    sau9  0x3C434DD0  AST_$ACTIVATE_ASTE_CANNED

  - Under the AST lock the UID's AOTE is found (none crashes the
    system).  The result is the segment's ASTE.
  - A canned object (its UID's first byte zero) gets a fresh ASTE, its
    32 segment-map entries "no disk block"; any other UID's is looked up
    or created (a failure crashes the system) and gets one reference.
  - The fresh ASTE's reference count is set to 1.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
{ seg pinteger (was integer): its two unsigned word compares with the
  ASTE's segment word (ast/ast.ins.pas, the heading's evidence). }
function ast_$activate_aste_canned(in uid: uid_$t; seg: pinteger):
  ast_$aste_ptr_t;
  options(val_param);
label
  10;
var
  status: status_$t;
  aote: ast_$aote_ptr_t;
  aste: ast_$aste_ptr_t;
  cur: ast_$aste_ptr_t;
  i: integer;
begin
  ml_$lock(ml_$ast_lock);
  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then
    crash_system(status_$ast_eof);

  if ast_uid_bytes_t(uid).first = 0 then begin
    aste := ast_$allocate_aste;
    aste^.flag_bits.in_trans := false;
    aste^.flag_bits.locked := false;
    aste^.flag_bits.dirty := false;
    aste^.flag_bits.area := false;
    aste^.flag_bits.remote := aote^.loc.remote;
    if aote^.loc.remote then
      ast_$aste_r_cnt := ast_$aste_r_cnt + 1
    else
      ast_$aste_l_cnt := ast_$aste_l_cnt + 1;
    aste^.page_count := chr(0);
    aste^.wire_count := 1;
    aste^.aote := aote;
    aste^.segment := seg;
%if pmap_threads %then
    aste^.pmap_link.asid := -1;
%endif

    cur := aote^.aste_list;
    if (cur = nil) or else (seg > cur^.segment) then begin
      aote^.aste_list := aste;
      aste^.next := cur;
    end
    else begin
  10:
      if seg = cur^.segment then begin
        crash_system(status_$ast_eof);
        goto 10;
      end;
      if (cur^.next = nil) and then
         (seg < cur^.next^.segment) then begin
        cur := cur^.next;
        goto 10;
      end;
      aste^.next := cur^.next;
      cur^.next := aste;
    end;

    aote^.status_flags := aote^.status_flags + 1;
    for i := 0 to 31 do begin
%if pmmu_page_maps %then
      { no disk copy, the disk address all ones, the flags clear }
      ast_pmaps[aste^.seg_index][i].hi_flags :=
        ast_pmaps[aste^.seg_index][i].hi_flags + [15];
      ast_pmaps[aste^.seg_index][i].dentry.daddr := 16#1FFFFF;
      ast_pmaps[aste^.seg_index][i].flags :=
        ast_pmaps[aste^.seg_index][i].flags - [0..9];
%else
      ast_pmaps[aste^.seg_index][i].flags :=
        ast_pmaps[aste^.seg_index][i].flags - [13];
      ast_pmaps[aste^.seg_index][i].flags :=
        ast_pmaps[aste^.seg_index][i].flags - [15];
      ast_pmaps[aste^.seg_index][i].flags :=
        ast_pmaps[aste^.seg_index][i].flags - [14];
      ast_pmap_row_bits_ptr_t(addr(ast_pmaps[aste^.seg_index]))^[i].
        bits_28_23 := 0;
      ast_pmap_row_bits_ptr_t(addr(ast_pmaps[aste^.seg_index]))^[i].
        bit_22 := 1;
      ast_pmap_row_bits_ptr_t(addr(ast_pmaps[aste^.seg_index]))^[i].
        daddr := 16#3FFFFF;
%endif
    end;
  end
  else begin
    aste := ast_$lookup_aste(aote^, seg);
    if aste = nil then begin
      aste := ast_$lookup_or_create_aste(aote^, seg, status);
      if aste = nil then
        crash_system(status);
    end;
    aste^.wire_count := aste^.wire_count + 1;
  end;

  ml_$unlock(ml_$ast_lock);
  ast_$activate_aste_canned := aste;
end;
