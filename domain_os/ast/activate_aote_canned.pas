{ AST_$ACTIVATE_AOTE_CANNED - activate an AOTE from a VTOCE already in
  memory.

  Image addresses:
    sau2  0x00E2F0C2  AST_$ACTIVATE_AOTE_CANNED
    sau4  0x0F8324C4  AST_$ACTIVATE_AOTE_CANNED
    sau9  0x3C434CC4  AST_$ACTIVATE_AOTE_CANNED

  - Under the AST lock a fresh AOTE gets one reference, its location
    word built from the location record, the attributes and location
    record copied in, and goes to the head of its UID's hash chain.
  - A UID already on the chain crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure ast_$activate_aote_canned(in vtoce: univ file_$attributes_t;
                                    in loc: univ file_$obj_loc_t);
var
  hash_index: integer;
  aote: ast_$aote_view_ptr_t;
  existing: ast_$aote_ptr_t;
begin
  ml_$lock(ml_$ast_lock);
  aote := ast_$aote_view_ptr_t(ast_$allocate_aote);

  aote^.aote.flags := aote^.aote.flags - [7];
  aote^.aote.flags := aote^.aote.flags - [6];
  aote^.aote.flags := aote^.aote.flags - [5];
  aote^.aote.flags := aote^.aote.flags - [4];
  aote^.ref_count := 1;
  aote^.aote.status_flags := 0;
  aote^.aote.hash_next := nil;
  aote^.aote.aste_list := nil;

  if 7 in loc.flags then begin
    ast_aote_loc_view_ptr_t(aote)^.loc.remote := true;
    ast_aote_loc_view_ptr_t(aote)^.loc.bits_25_20 := 0;
    ast_aote_loc_view_ptr_t(aote)^.loc.node := loc.node;
  end
  else
    aote^.location.all := loc.block_hint;

  aote^.attrs.fattr := vtoce;
  aote^.obj_loc.floc := loc;

  hash_index := uid_$hash(aote^.aote.uid, 251);
  existing := aoth[hash_index];
  while existing <> nil do begin
    if existing^.uid = aote^.aote.uid then
      crash_system(16#80030003)
    else
      existing := existing^.hash_next;
  end;

  aote^.aote.hash_next := aoth[hash_index];
  aoth[hash_index] := ast_$aote_ptr_t(aote);
  ml_$unlock(ml_$ast_lock);
end;
