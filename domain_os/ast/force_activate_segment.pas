{ ast_$force_activate_segment - activate an object: a fresh AOTE for its
  UID, located and its attributes read.

  Image addresses:
    sau2  0x00E020FA  ast_$force_activate_segment (module-local)
    sau4  0x0F802512  ast_$force_activate_segment (module-local)
    sau6  0x7800288E  ast_$force_activate_segment (module-local)
    sau7  0x3C402CA4  ast_$force_activate_segment (module-local)
    sau9  0x3C4034A4  ast_$force_activate_segment (module-local)

  Assume we're called with the AST lock held.

  - If an activation happened meanwhile, an AOTE for the UID already on
    its chain is the result (waited for while in transition).
  - Otherwise a fresh AOTE goes onto its chain and, with the lock
    released, the object is located (a volume search, the hints, its
    node, or VTOC_$LOOKUP) and its VTOCE read.
  - The result is the AOTE, or nil (the AOTE unlinked and released).

  Status stored:
    status_$ok: the object was activated
    ast_$validate_uid's result: the volume is being dismounted, or a
      lookup gave 16#20006
    the callees' statuses: the object was not located or read
}

function ast_$force_activate_segment(in uid: uid_$t;
                                     location: ast_$loc_word_t;
                                     out status_ret: status_$t;
                                     force: boolean): ast_$aote_ptr_t;
  internal;
label
  10, 30, 40, 50, 80, 90;
var
  seqn_before: integer32;
  aote: ast_$aote_view_ptr_t;
  i: integer;
  existing: ast_$aote_ptr_t;
  prev: ast_$aote_ptr_t;
begin
  seqn_before := ast_$aote_seqn;
  aote := ast_$aote_view_ptr_t(ast_$allocate_aote);
  i := uid_$hash(uid, 251);

  { another activation meanwhile }
10:
  while seqn_before <> ast_$aote_seqn do begin
    existing := aoth[i];
    while existing <> nil do
      if existing^.uid = uid then begin
        if 7 in existing^.flags then begin
          ast_$wait_for_ast_intrans;
          goto 10;
        end;
        ast_$release_aote(aote^.aote);
        status_ret.all := status_$ok;
        ast_$force_activate_segment := existing;
        return;
      end
      else
        existing := existing^.hash_next;
    exit;
  end;

  { the fresh AOTE }
  ast_$aote_seqn := ast_$aote_seqn + 1;
  aote^.aote.flags := aote^.aote.flags + [7];
  aote^.aote.flags := aote^.aote.flags - [6];
  aote^.aote.flags := aote^.aote.flags - [5];
  aote^.aote.flags := aote^.aote.flags - [4];
  aote^.ref_count := 0;
  aote^.aote.status_flags := 0;
  aote^.aote.hash_next := nil;
  aote^.aote.aste_list := nil;
  aote^.location := location;
  aote^.aote.uid := uid;
  aote^.aote.unknown_9c := chr(0);
  aote^.aote.obj_loc_uid := uid;
  aote^.aote.loc.remote := location.hi < 0;
  aote^.aote.loc.scratch := false;

  if location.hi >= 0 then
    aote^.aote.vol_index := location.all & 16#7FFFFFFF
  else begin
    aote^.aote.vol_index := 0;
    aote^.aote.obj_loc_addr.low := location.all & 16#FFFFF;
    network_$get_net(location.addr, aote^.aote.obj_loc_addr.high,
                     status_ret);
  end;

  { onto its chain, the lock released }
  aote^.aote.hash_next := aoth[i];
  aoth[i] := ast_$aote_ptr_t(aote);
  ml_$unlock(ml_$ast_lock);

  { no location }
  if (location.all & 16#7FFFFFFF) = 0 then begin
    if force then begin
      vtoc_$search_volumes(aote^.obj_loc.vtoc, status_ret);
      goto 30;
    end;
    ast_$lookup_with_hints(aote^.obj_loc, location, aote^.attrs,
                           status_ret);
    if status_ret.all <> status_$ok then
      goto 90;
    if not aote^.aote.loc.remote then
      goto 40;
    aote^.location := location;
    goto 50;
  end;

  { a remote location }
  if aote^.aote.loc.remote then begin
    network_$ast_get_info(aote^.obj_loc.net, 8, aote^.attrs.net,
                          status_ret);
    goto 50;
  end;

  { a local one }
  if aote^.aote.vol_index in ast_$vol_info_count then
    goto 80;
  vtoc_$lookup(aote^.obj_loc.vtoc, status_ret);

30:
  if status_ret.all <> status_$ok then
    goto 90;
40:
  aote^.location.all := aote^.obj_loc.floc.block_hint;

  { the attributes }
50:
  if aote^.aote.loc.remote then
    goto 90;
  if aote^.aote.vol_index in ast_$vol_info_count then begin
80:
    status_ret.all := ast_$validate_uid(uid, 16#30F00);
  end
  else begin
    vtoce_$read(aote^.obj_loc.vtoc, aote^.attrs.vtoce, status_ret);
    if 1 in aote^.attrs.common.attr_flags_lo then
      aote^.attrs.fattr.acl_checksum := 0;
  end;

  { the lock again, the dismount test again }
90:
  ml_$lock(ml_$ast_lock);
  if not aote^.aote.loc.remote and then
     (aote^.aote.vol_index in ast_$vol_info_count) then
    status_ret.all := ast_$validate_uid(uid, 16#30F00);

  if status_ret.all <> status_$ok then begin
    if status_ret.all = 16#20006 then
      status_ret.all := ast_$validate_uid(uid, status_ret.all);
    prev := aoth[i];
    if prev = ast_$aote_ptr_t(aote) then
      aoth[i] := aote^.aote.hash_next
    else begin
      while prev^.hash_next <> aote do
        prev := prev^.hash_next;
      prev^.hash_next := aote^.aote.hash_next;
    end;
    ast_$release_aote(aote^.aote);
    ast_$force_activate_segment := nil;
  end
  else begin
    aote^.aote.flags := aote^.aote.flags - [7];
    ec_$advance(ast_$ast_in_trans_ec);
    ast_$force_activate_segment := ast_$aote_ptr_t(aote);
  end;
end;
