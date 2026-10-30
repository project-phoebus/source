{ acl_$eval_acl_entries - the rights a cached ACL image grants a SID
  block.

  Image addresses:
    sau2  0x00E46172  acl_$eval_acl_entries (module-local)

  - The record's owner (unless ignored, bit 4) when it is the caller's
    person; else a person entry matching the caller, masked by the
    subsystem rights.
  - Else nine passes, the caller's group and each project, over the
    record's group and the group entries, their rights or-ed; else the
    organization, then the world rights.
  - Phase 3 scans from where the last phase-2 scan left off, not from
    max_index; the two agree whenever phase 3 runs.

  Status stored: none.
}

function acl_$eval_acl_entries(in slot: acl_$cache_slot_t;
                               in sids: acl_sid_block_t;
                               in proj_uids: acl_$proj_uids_t;
                               in prot: acl_$prot_data_t): acl_$rights_word_t;
  internal;
type
  entry_ptr_t = ^acl_$cache_entry_t;
var
  local_sids: acl_sid_block_t;
  max_index: integer;
  start_index: integer;
  matched: boolean;
  entry: entry_ptr_t;
  index: integer;
  count: integer;
  accum: acl_$rights_word_t;
  which: integer;
begin
  { the record's owner }
  if not (4 in prot.owner_rights) and then (prot.owner = sids.user_sid)
  then begin
    acl_$eval_acl_entries := prot.owner_rights;
    return;
  end;

  { phase 1, the person entries }
  index := 1;
  entry := addr(slot.entries[1]);
  count := slot.entry_count;
  while (index <= count) and then (entry^.person <> uid_$nil) do begin
    if (entry^.person = sids.user_sid) and then
       ((entry^.group = sids.group_sid) or else (entry^.group = uid_$nil))
       and then
       ((entry^.org = sids.org_sid) or else (entry^.org = uid_$nil))
    then begin
      acl_$eval_acl_entries := prot.subsys_rights * entry^.rights;
      return;
    end;
    index := index + 1;
    entry := entry_ptr_t(integer32(entry) + 32);
  end;

  { phase 2, the group entries for each pass }
  accum := [];
  matched := false;
  start_index := index;
  max_index := index;
  for which := 0 to 8 do begin
    if which = 0 then
      local_sids := sids
    else begin
      if proj_uids[which] = uid_$nil then
        exit;
      local_sids.group_sid := proj_uids[which];
    end;
    if not (4 in prot.group_rights) and then
       (prot.group = local_sids.group_sid) then begin
      accum := accum + prot.group_rights;
      matched := true;
      next;
    end;
    index := start_index;
    entry := addr(slot.entries[index]);
    while (index <= count) and then (entry^.group <> uid_$nil) do begin
      if (entry^.group = local_sids.group_sid) and then
         ((entry^.org = local_sids.org_sid) or else
          (entry^.org = uid_$nil)) then begin
        accum := accum + (prot.subsys_rights * entry^.rights);
        matched := true;
        exit;
      end;
      index := index + 1;
      entry := entry_ptr_t(integer32(entry) + 32);
    end;
    if index > max_index then
      max_index := index;
  end;

  if matched then begin
    acl_$eval_acl_entries := accum;
    return;
  end;

  { phase 3, the organization and the world }
  index := max_index;
  if not (4 in prot.org_rights) and then (prot.org = sids.org_sid)
  then begin
    acl_$eval_acl_entries := prot.org_rights;
    return;
  end;
  while (index <= count) and then (entry^.org <> uid_$nil) do begin
    if entry^.org = sids.org_sid then begin
      acl_$eval_acl_entries := prot.subsys_rights * entry^.rights;
      return;
    end;
    index := index + 1;
    entry := entry_ptr_t(integer32(entry) + 32);
  end;
  acl_$eval_acl_entries := prot.world_rights;
end;
