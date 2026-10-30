{ acl_$convert_image - convert a version-4 ACL image to version 5.

  Image addresses:
    sau2  0x00E44E68  acl_$convert_image (module-local)

  - The version-5 header and a default protection record are built; the
    world entry gives the record's world rights, every other entry is
    copied with its rights converted.
  - For a file or directory ACL each copied entry's rights bits 2, 1, 0,
    3 and 6 are added to the subsystem rights.

  Status stored:
    status_$ok: always
}

procedure acl_$convert_image(in src: univ acl_$v4_image_t;
                             out prot: acl_$prot_data_t;
                             out dst: univ acl_$v5_build_t;
                             out length_ret: integer;
                             out status_ret: status_$t); internal;
var
  def_acl_uid: uid_$t;
  i: integer;
  j: integer;                             { the count }
  n: integer;
begin
  status_ret.all := status_$ok;

  { the version-5 header }
  dst.version := 5;
  dst.type_uid := src.type_uid;
  dst.ids16 := src.ids16;
  for i := 1 to 12 do
    dst.words_2a[i] := 0;
  dst.reserved_0a := 0;
  dst.reserved_10 := 0;
  dst.reserved_22 := 0;
  dst.reserved_26 := 0;
  dst.world_entry_present := false;
  dst.unused_29 := chr(0);

  acl_$def_acldata(prot, def_acl_uid);
  prot.world_rights := [];

  { the entries }
  n := 1;
  for j := 1 to src.entry_count do
    if (src.entries[j].person = uid_$nil) and then
       (src.entries[j].group = uid_$nil) and then
       (src.entries[j].org = uid_$nil) then
      prot.world_rights := acl_$rights_t(
        acl_$convert_rights(src.entries[j].rights, src.type_uid))
    else begin
      dst.entries[n].ids := src.entries[j].ids;
      dst.entries[n].rights_l :=
        acl_$convert_rights(src.entries[j].rights, src.type_uid);
      if (src.type_uid = acl_$file_acl) or else
         (src.type_uid = acl_$dir_acl) then begin
        if (dst.entries[n].rights_l & 16#4) <> 0 then
          prot.subsys_rights := prot.subsys_rights + [2];
        if (dst.entries[n].rights_l & 16#2) <> 0 then
          prot.subsys_rights := prot.subsys_rights + [1];
        if (dst.entries[n].rights_l & 16#1) <> 0 then
          prot.subsys_rights := prot.subsys_rights + [0];
        if (dst.entries[n].rights_l & 16#8) <> 0 then
          prot.subsys_rights := prot.subsys_rights + [3];
        if (dst.entries[n].rights_l & 16#40) <> 0 then
          prot.subsys_rights := prot.subsys_rights + [6];
      end;
      n := n + 1;
    end;

  if n > 1 then
    dst.entry_count := n - 1
  else
    dst.entry_count := 0;
  length_ret := dst.entry_count * 32 + 52;
end;
