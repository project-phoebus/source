{ AST_$LOAD_AOTE - refresh or enter an object's AOTE from a fetched
  attribute record.

  Image addresses:
    sau2  0x00E0238C  AST_$LOAD_AOTE
    sau4  0x0F8027A4  AST_$LOAD_AOTE
    sau6  0x78002B14  AST_$LOAD_AOTE
    sau7  0x3C402F2A  AST_$LOAD_AOTE
    sau8  0x03C0271E  AST_$LOAD_AOTE
    sau9  0x3C40372A  AST_$LOAD_AOTE

  - Under the AST lock, a found AOTE gets the caller's attribute record,
    its DTV kept and its touched member 4 cleared.
  - Otherwise a fresh AOTE gets the location record (a remote object's
    network installed) and the attributes, and goes to the head of its
    bucket.  It is given back if the object appeared meanwhile, its
    volume is dismounting or the network install failed.

  Status stored: none.
}

procedure ast_$load_aote(in attrs: file_$attributes_t;
                         in loc: file_$obj_loc_t);
label
  10, 20;
var
  status: status_$t;
  saved_dtv: time_$clock_t;
  existing: ast_$aote_ptr_t;
  seqn_before: integer32;
  aote: ast_$aote_view_ptr_t;
  hash_index: integer;
  node: linteger;
begin
  ml_$lock(ml_$ast_lock);

  { already active: refresh, the DTV kept }
  existing := ast_$lookup_aote_by_uid(loc.uid);
  if existing <> nil then begin
    saved_dtv := existing^.dtv;
    ast_$aote_view_ptr_t(existing)^.attrs.fattr := attrs;
    existing^.dtv := saved_dtv;
    existing^.flags := existing^.flags - [4];
    goto 20;
  end;

  seqn_before := ast_$aote_seqn;
  aote := ast_$aote_view_ptr_t(ast_$allocate_aote);
  hash_index := uid_$hash(loc.uid, 251);

  { activated meanwhile? }
  if seqn_before <> ast_$aote_seqn then begin
    existing := aoth[hash_index];
    while existing <> nil do begin
      if existing^.uid = loc.uid then
        goto 10;
      existing := existing^.hash_next;
    end;
  end;

  { a dismounting volume }
  if ast_$obj_loc_view_t(loc).net.rights in ast_$vol_info_count then
    goto 10;

  { the fresh AOTE }
  ast_$aote_seqn := ast_$aote_seqn + 1;
  aote^.aote.flags := aote^.aote.flags - [7];
  aote^.aote.flags := aote^.aote.flags - [6];
  aote^.aote.flags := aote^.aote.flags - [5];
  aote^.ref_count := 0;
  aote^.aote.status_flags := 0;
  aote^.aote.hash_next := nil;
  aote^.aote.aste_list := nil;
  aote^.obj_loc.floc := loc;

  { remote or local }
  node := loc.node;
  aote^.aote.loc.remote := node <> node_$me;
  if aote^.aote.loc.remote then begin
    network_$install_net(loc.loc_info, aote^.location.addr, status);
    if status.all <> status_$ok then
      goto 10;
    aote^.location.bits.node := node;
    aote^.location.bits.remote := true;
  end
  else
    aote^.location.all := loc.block_hint;

  { the attributes, onto the bucket }
  aote^.attrs.fattr := attrs;
  aote^.aote.hash_next := aoth[hash_index];
  aoth[hash_index] := ast_$aote_ptr_t(aote);
  goto 20;

  { given back }
10:
  ast_$release_aote(aote^.aote);

20:
  ml_$unlock(ml_$ast_lock);
end;
