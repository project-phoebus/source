{ ACL_$MIN_RIGHTS - the rights every user has to an object.

  Image addresses:
    sau2  0x00E468E2  ACL_$MIN_RIGHTS

  - The world rights, less the owner's, group's and organization's not
    marked kept (bit 4), less each entry's of a cached default ACL
    image.
  - The result is the low four bits, empty when the attributes or the
    image cannot be had.

  Status stored: none.
}

function acl_$min_rights(uid: uid_$t): acl_$rights_word_t;
var
  attrs: ast_$acl_attr_t;
  loc: file_$obj_loc_t;
  status: status_$t;
  rights: acl_$rights_word_t;
  slot: integer;
  i: integer;                             { (the count only) }
  cached: boolean;
begin
  acl_$get_obj_acl_attrs(uid, loc, attrs, status);
  if status.all <> status_$ok then begin
    acl_$min_rights := [];
    return;
  end;

  { world rights less the three SIDs' }
  rights := attrs.prot.world_rights;
  if not (4 in attrs.prot.owner_rights) then
    rights := rights - attrs.prot.owner_rights;
  if not (4 in attrs.prot.group_rights) then
    rights := rights - attrs.prot.group_rights;
  if not (4 in attrs.prot.org_rights) then
    rights := rights - attrs.prot.org_rights;

  { the default ACL's cached image }
  if attrs.default_acl <> uid_$nil then begin
    ml_$lock(ml_$acl_lock);
    slot := acl_$find_acl_slot(attrs.default_acl, cached, attrs.prot,
                               status);
    if status.all <> status_$ok then begin
      ml_$unlock(ml_$acl_lock);
      acl_$min_rights := [];
      return;
    end;
    if (slot <> -1) and then (rights <> []) then
      with acl_$acl_cache[slot] do
        for i := 1 to entry_count do
          rights := rights - entries[i].rights;
    ml_$unlock(ml_$acl_lock);
  end;

  acl_$min_rights := rights * [0..3];
end;
