{ mst_$lookup_object - locate a named object for mapping and check the
  caller's rights to it.

  Image addresses:
    sau2  0x00E43CBE  mst_$lookup_object (module-local)
    sau4  0x0F84BD90  mst_$lookup_object (module-local)
    sau8  0x03C4BEC2  mst_$lookup_object (module-local)
    sau9  0x3C44B080  mst_$lookup_object (module-local)

  - AST_$GET_COMMON_ATTRIBUTES gives the object's attributes and
    location: the local volume's index, or a remote object's network
    address with bit 31 set.  The length is returned.
  - Unless the type needs no check, FILE_$CHECK_PROT checks the rights
    the protection selects.
  - The local arm keeps bit 31; the read-only refusal is unflagged; the
    rights word is not used.

  Status stored:
    status_$ok: located and allowed
    status_$mst_object_not_found: a null UID, or no such object
    status_$file_volume_has_been_mounted_read_only: writing on a
      read-only volume
    status_$mst_no_rights, status_$mst_insufficient_rights,
      status_$mst_wrong_type: FILE_$CHECK_PROT's ACL statuses
    the callee's status, its fail bit set: the attributes or the
      network address failed
}

procedure mst_$lookup_object(uid: uid_$t; prot: integer;
                             area_size: integer32;
                             out location: univ mst_lookup_location_t;
                             out obj_len: linteger;
                             out status: status_$t);
var
  { The protection-to-rights table, 8 words in MST_UNWIRED's .DATA block
    at +0x38: this routine's static (rules, "Module data"), its only
    reader in the image.  dpc places a routine's static after the
    module's variables in the same block, at the same +0x38 (a probe). }
  prot_rights: static array[0..7] of pinteger := [0, 1, 4, 5, 2, 3, 6, 7];
                                          { +0x38 }
  loc: file_$obj_loc_t;
  attrs: ast_$common_attr_t;
  rights_out: integer;
  rights: pinteger;

label
  fail, not_found;

begin
  if uid.high = 0 then
    goto not_found;
  rights := prot_rights[prot & 7];
  loc.uid := uid;
  loc.flags := loc.flags - [6];
  ast_$get_common_attributes(loc, 2, attrs, status);
  if status.all <> status_$ok then
    if status.all <> file_$object_not_found then
      goto fail
    else
      goto not_found;
  if (1 in attrs.attr_flags_lo) and then
     ((prot & 16#14) = 4) then begin
    status.all :=
      status_$file_volume_has_been_mounted_read_only;
    return;
  end;
  location.all := 0;
  if not (7 in loc.flags) then
    location.local.low31 :=
      mst_obj_loc_view_t(loc).rights_byte
  else begin
    network_$install_net(loc.loc_info, location.net_addr,
                         status);
    if status.all <> status_$ok then begin
fail:
      status.fail := true;
      return;
    end;
    location.bits := location.bits + [31];
    location.net.low20 := loc.node;
  end;
  obj_len := attrs.length;
  if ord(attrs.sub_type) = mst_lookup_no_check_type then
    return;
  file_$check_prot(uid, rights, area_size, false, 0,
                   rights_out, status);
  if status.all <> status_$ok then
    if status.all = status_$no_right_to_perform_operation then
      status.all := status_$mst_no_rights
    else if status.all =
            status_$insufficient_rights_to_perform_operation then
      status.all := status_$mst_insufficient_rights
    else if status.all = status_$acl_wrong_type then
      status.all := status_$mst_wrong_type
    else if status.all = file_$object_not_found then begin
not_found:
      status.all := status_$mst_object_not_found;
    end;
end;

{ TODO(pascal) mst_$lookup_object's frame: the image copies the UID
  value parameter below the two records and leaves the top longword
  unaddressed; dpc puts every local 4 bytes lower, and no declaration
  order gives the image's. }
