{ ast_$process_aote - deactivate an object: its segments, its attributes,
  its hash chain.

  Image addresses:
    sau2  0x00E01AD2  ast_$process_aote (module-local)
    sau4  0x0F801EEA  ast_$process_aote (module-local)
    sau6  0x78002278  ast_$process_aote (module-local)
    sau7  0x3C40268E  ast_$process_aote (module-local)
    sau9  0x3C402E8E  ast_$process_aote (module-local)

  Assume we're called with the AST lock held.

  - Each segment on the AOTE's list is deactivated and freed (waited for
    while in transition when wait is set).  Unless purge is set the AOTE
    is then purified; then it is unlinked from its hash chain.

  Status stored:
    status_$ok: the object was deactivated
    status_$ast_segment_not_deactivatable: the AOTE is in transition or
      referenced, or a protected local object (unless keep), or from a
      segment
    ast_$deactivate_segment's or ast_$purify_aote's status, with the
      fail bit: a step failed
}

procedure ast_$process_aote(var aote: univ ast_$aote_view_t; purge: boolean;
                            keep: boolean; wait: boolean;
                            out status_ret: status_$t);
  internal;
label
  10, 20;
var
  aste: ast_$aste_ptr_t;
  i: integer;
  prev: ast_$aote_ptr_t;
begin
  status_ret.all := status_$ok;

  if ((7 in aote.aote.flags) or (aote.ref_count <> 0)) or else
     (not keep and then (ord(aote.aote.sub_type) = 2) and then
      (1 in aote.attrs.common.attr_flags_lo) and then
      not aote.aote.loc.remote) then begin
    status_ret.all := status_$ast_segment_not_deactivatable;
    return;
  end;

  aote.aote.flags := aote.aote.flags + [7];

  { the segments }
  while aote.aote.aste_list <> nil do begin
    aste := aote.aote.aste_list;
    if (15 in aste^.flags) and then wait then
      ast_$wait_for_ast_intrans
    else begin
      ast_$deactivate_segment(aste^, purge, keep, status_ret);
      if status_ret.all <> status_$ok then
        if status_ret.all = status_$ast_segment_not_deactivatable then
          goto 20
        else
          goto 10;
      ast_$free_aste(aste^);
    end;
  end;

  if not purge then begin
    ast_$purify_aote(aote, false, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  { off the hash chain }
  i := uid_$hash(aote.aote.obj_loc_uid, 251);
  prev := aoth[i];
  if prev = ast_$aote_ptr_t(addr(aote)) then begin
    aoth[i] := aote.aote.hash_next;
    return;
  end
  else begin
    while prev^.hash_next <> addr(aote) do
      prev := prev^.hash_next;
    prev^.hash_next := aote.aote.hash_next;
    return;
  end;

10:
  status_ret.fail := true;
20:
  aote.aote.flags := aote.aote.flags - [7];
  ec_$advance(ast_$ast_in_trans_ec);
end;
