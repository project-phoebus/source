{ acl_$prim_create_internal - build the version-4 image of a new ACL
  object from a version-5 image and a protection record.

  Image addresses:
    sau2  0x00E4519C  acl_$prim_create_internal (module-local)
    sau2  0x00E45046  acl_$pci_rights_mask (nested)
    sau2  0x00E450F2  acl_$pci_uid_ge (nested)
    sau2  0x00E45122  acl_$pci_copy_entry (nested)
    sau2  0x00E45154  acl_$pci_subsys_rights (nested)

  - The source's person, group and organization runs are copied, the
    record's owner, group and organization merged into theirs at the
    first entry whose UID is below theirs (unsigned).
  - A world entry follows when the world rights are not empty.
  - A placed entry with rights bit 5 is marked: its number goes into
    the header, or with `flag' its rights become the subsystem mask.
  - The size check leaves out a world entry with bit 4; the append
    writes it.

  Status stored:
    status_$acl_is_full: more than 22 entries (nothing else is written)
}

procedure acl_$prim_create_internal(in prot: acl_$prot_data_t;
                                    in src_image: univ acl_$v5_build_t;
                                    src_len: integer;
                                    in acl_type: uid_$t;
                                    flag: boolean;
                                    out image: univ acl_$v4_image_t;
                                    out image_len_ret: integer;
                                    out status: status_$t); internal;
var
  src: acl_$v5_build_ptr_t;
  hdr: acl_$v4_image_ptr_t;
  owner_done: boolean;
  group_done: boolean;
  org_done: boolean;
  out_idx: integer;
  in_idx: integer;
  need: integer;
  world: acl_$rights_word_t;
  i: integer;                             { the count only }

  { acl_$pci_rights_mask - the version-4 rights longword for version-5
    rights bits.

    Image addresses:
      sau2  0x00E45046  acl_$pci_rights_mask (nested)

    - Nested in acl_$prim_create_internal; it reaches nothing of its
      parent.

    Status stored: none. }

  function acl_$pci_rights_mask(rights: acl_$rights_word_t;
                                in acl_type: uid_$t): integer32;
  var
    m: integer32;
  begin
    m := 0;
    if acl_type = acl_$file_acl then begin
      if 2 in rights then
        m := 2;
      if 1 in rights then
        m := m ! 16#4;
      if 0 in rights then
        m := m ! 16#1;
      if not (6 in rights) then
        m := m ! 16#8;
    end
    else if acl_type = acl_$dir_acl then begin
      if 2 in rights then
        m := 1;
      if 1 in rights then
        m := m ! 16#4E;
      if 0 in rights then
        m := m ! 16#20;
      if not (6 in rights) then
        m := m ! 16#10;
    end;

    if 3 in rights then
      m := m ! 16#12000000;
    acl_$pci_rights_mask := m ! 16#2D000000;
  end;

  { acl_$pci_uid_ge - whether one UID is not below another.

    Image addresses:
      sau2  0x00E450F2  acl_$pci_uid_ge (nested)

    - Nested in acl_$prim_create_internal; it reaches nothing of its
      parent.

    Status stored: none. }

  function acl_$pci_uid_ge(in a: univ acl_$uid_longs_t;
                           in b: univ acl_$uid_longs_t): boolean;
  var
    i: integer;                           { the count }
  begin
    acl_$pci_uid_ge := true;
    for i := 1 to 2 do
      if a[i] < b[i] then begin
        acl_$pci_uid_ge := false;
        return;
      end
      else if a[i] > b[i] then
        return;
  end;

  { acl_$pci_copy_entry - copy a version-5 entry's three UIDs into a
    version-4 entry.

    Image addresses:
      sau2  0x00E45122  acl_$pci_copy_entry (nested)

    - Nested in acl_$prim_create_internal; it reaches nothing of its
      parent.

    Status stored: none. }

  procedure acl_$pci_copy_entry(in src: acl_$cache_entry_t;
                                out dst: acl_$v4_entry_t);
  begin
    with dst do begin
      ids := src.ids;
      reserved_20 := 0;
      subsys := uid_$nil;
    end;
  end;

  { acl_$pci_subsys_rights - the rights of a marked entry when the flag
    is set.

    Image addresses:
      sau2  0x00E45154  acl_$pci_subsys_rights (nested)

    - Nested in acl_$prim_create_internal, whose acl_type it reads.
    - For an ACL type neither the file nor the directory type, r is not
      assigned.

    Status stored: none. }

  function acl_$pci_subsys_rights: integer32;
  var
    r: integer32;
  begin
    if acl_type = acl_$file_acl then
      r := 16#0F
    else if acl_type = acl_$dir_acl then
      r := 16#7F;
    acl_$pci_subsys_rights := r ! 16#3F000000;
  end;

begin
  src := addr(src_image);
  hdr := addr(image);
  owner_done := false;
  group_done := false;
  org_done := false;

  { the header }
  with hdr^ do begin
    version := 4;
    if src_len > 0 then begin
      type_uid := acl_type;
      ids16 := src^.ids16;
    end
    else begin
      type_uid := acl_type;
      required_uid := uid_$nil;
      subsys_uid := acl_type;
    end;
    reserved_0a := 0;
    reserved_10 := 0;
    owner_slot := 0;
    group_slot := 0;
    org_slot := 0;
    world_entry_present := false;
    unused_29 := chr(0);
    for i := 1 to 5 do
      reserved_2a[i] := 0;
  end;

  { the entries needed }
  out_idx := 1;
  need := 0;
  in_idx := 1;
  if not (4 in prot.owner_rights) then
    need := 1;
  if not (4 in prot.group_rights) then
    need := need + 1;
  if not (4 in prot.org_rights) then
    need := need + 1;
  if not (4 in prot.world_rights) and then
     (prot.world_rights <> []) then
    need := need + 1;
  if src_len > 0 then
    need := need + src^.entry_count;
  if need > 22 then begin
    status.all := status_$acl_is_full;
    return;
  end;

  { the person run, the owner merged in }
  while (in_idx <= src^.entry_count) and then
        (src^.entries[in_idx].person <> uid_$nil) do begin
    if owner_done or else (4 in prot.owner_rights) or else
       acl_$pci_uid_ge(src^.entries[in_idx].person, prot.owner) then begin
      acl_$pci_copy_entry(src^.entries[in_idx], hdr^.entries[out_idx]);
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(src^.entries[in_idx].rights, acl_type);
      hdr^.entries[out_idx].reserved_24 := 0;
      in_idx := in_idx + 1;
      out_idx := out_idx + 1;
      next;
    end;
    if not owner_done and then not (4 in prot.owner_rights) then begin
      with hdr^.entries[out_idx].ids_block do begin
        person := prot.owner;
        group := uid_$nil;
        org := uid_$nil;
        subsys := uid_$nil;
        reserved_20 := 0;
        hdr^.entries[out_idx].reserved_24 := 0;
        hdr^.entries[out_idx].rights :=
          acl_$pci_rights_mask(prot.owner_rights, acl_type);
        owner_done := true;
        if not flag then begin
          if 5 in prot.owner_rights then
            hdr^.owner_slot := out_idx;
        end
        else if 5 in prot.owner_rights then
          hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
        if person <> uid_$nil then
          out_idx := out_idx + 1;
      end;
    end;
  end;

  { the owner after the run }
  if not owner_done and then not (4 in prot.owner_rights) then begin
    with hdr^.entries[out_idx].ids_block do begin
      person := prot.owner;
      group := uid_$nil;
      org := uid_$nil;
      subsys := uid_$nil;
      reserved_20 := 0;
      hdr^.entries[out_idx].reserved_24 := 0;
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(prot.owner_rights, acl_type);
      if not flag then begin
        if 5 in prot.owner_rights then
          hdr^.owner_slot := out_idx;
      end
      else if 5 in prot.owner_rights then
        hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
      if person <> uid_$nil then
        out_idx := out_idx + 1;
    end;
  end;

  { the group run, the group merged in }
  while (in_idx <= src^.entry_count) and then
        (src^.entries[in_idx].group <> uid_$nil) do begin
    if group_done or else (4 in prot.group_rights) or else
       acl_$pci_uid_ge(src^.entries[in_idx].group, prot.group) then begin
      acl_$pci_copy_entry(src^.entries[in_idx], hdr^.entries[out_idx]);
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(src^.entries[in_idx].rights, acl_type);
      hdr^.entries[out_idx].reserved_24 := 0;
      in_idx := in_idx + 1;
      out_idx := out_idx + 1;
      next;
    end;
    if not group_done and then not (4 in prot.group_rights) then begin
      with hdr^.entries[out_idx].ids_block do begin
        person := uid_$nil;
        group := prot.group;
        org := uid_$nil;
        subsys := uid_$nil;
        reserved_20 := 0;
        hdr^.entries[out_idx].reserved_24 := 0;
        hdr^.entries[out_idx].rights :=
          acl_$pci_rights_mask(prot.group_rights, acl_type);
        group_done := true;
        if not flag then begin
          if 5 in prot.group_rights then
            hdr^.group_slot := out_idx;
        end
        else if 5 in prot.group_rights then
          hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
        if group <> uid_$nil then
          out_idx := out_idx + 1;
      end;
    end;
  end;

  { the group after the run }
  if not group_done and then not (4 in prot.group_rights) then begin
    with hdr^.entries[out_idx].ids_block do begin
      person := uid_$nil;
      group := prot.group;
      org := uid_$nil;
      subsys := uid_$nil;
      reserved_20 := 0;
      hdr^.entries[out_idx].reserved_24 := 0;
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(prot.group_rights, acl_type);
      if not flag then begin
        if 5 in prot.group_rights then
          hdr^.group_slot := out_idx;
      end
      else if 5 in prot.group_rights then
        hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
      if group <> uid_$nil then
        out_idx := out_idx + 1;
    end;
  end;

  { the organization run, the org merged in }
  while (in_idx <= src^.entry_count) and then
        (src^.entries[in_idx].org <> uid_$nil) do begin
    if org_done or else (4 in prot.org_rights) or else
       acl_$pci_uid_ge(src^.entries[in_idx].org, prot.org) then begin
      acl_$pci_copy_entry(src^.entries[in_idx], hdr^.entries[out_idx]);
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(src^.entries[in_idx].rights, acl_type);
      hdr^.entries[out_idx].reserved_24 := 0;
      in_idx := in_idx + 1;
      out_idx := out_idx + 1;
      next;
    end;
    if not org_done and then not (4 in prot.org_rights) then begin
      with hdr^.entries[out_idx].ids_block do begin
        person := uid_$nil;
        group := uid_$nil;
        org := prot.org;
        subsys := uid_$nil;
        reserved_20 := 0;
        hdr^.entries[out_idx].reserved_24 := 0;
        hdr^.entries[out_idx].rights :=
          acl_$pci_rights_mask(prot.org_rights, acl_type);
        org_done := true;
        if not flag then begin
          if 5 in prot.org_rights then
            hdr^.org_slot := out_idx;
        end
        else if 5 in prot.org_rights then
          hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
        if org <> uid_$nil then
          out_idx := out_idx + 1;
      end;
    end;
  end;

  { the organization after the run }
  if not org_done and then not (4 in prot.org_rights) then begin
    with hdr^.entries[out_idx].ids_block do begin
      person := uid_$nil;
      group := uid_$nil;
      org := prot.org;
      subsys := uid_$nil;
      reserved_20 := 0;
      hdr^.entries[out_idx].reserved_24 := 0;
      hdr^.entries[out_idx].rights :=
        acl_$pci_rights_mask(prot.org_rights, acl_type);
      if not flag then begin
        if 5 in prot.org_rights then
          hdr^.org_slot := out_idx;
      end
      else if 5 in prot.org_rights then
        hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
      if org <> uid_$nil then
        out_idx := out_idx + 1;
    end;
  end;

  { the world entry }
  world := prot.world_rights;
  if world <> [] then begin
    with hdr^.entries[out_idx].ids_block do begin
      person := uid_$nil;
      group := uid_$nil;
      org := uid_$nil;
      subsys := uid_$nil;
      reserved_20 := 0;
    end;
    hdr^.entries[out_idx].reserved_24 := 0;
    hdr^.entries[out_idx].rights := acl_$pci_rights_mask(world, acl_type);
    if flag and then (5 in prot.world_rights) then
      hdr^.entries[out_idx].rights := acl_$pci_subsys_rights;
    out_idx := out_idx + 1;
  end;

  out_idx := out_idx - 1;
  hdr^.entry_count := out_idx;
  image_len_ret := out_idx * 44 + 52;
end;
