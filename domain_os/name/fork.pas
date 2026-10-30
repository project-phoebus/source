{ NAME_$FORK - give a child address space its parent's directories.

  Image addresses:
    sau2  0x00E73E44  NAME_$FORK
    sau9  0x3C47B7DC  NAME_$FORK

  - The parent's working and naming directory UIDs and both mappings are
    copied to the child.
  - The two mappings are copied twice.

  Status stored: none. }

[section(proc2_create_pro, proc2_create_dat)]
procedure name_$fork(in parent_asid: integer; in child_asid: integer);
begin
  name_$wdir_uid[child_asid] := name_$wdir_uid[parent_asid];
  name_$ndir_uid[child_asid] := name_$ndir_uid[parent_asid];

  name_$wdir_mapped_info[child_asid] := name_$wdir_mapped_info[parent_asid];
  name_$ndir_mapped_info[child_asid] := name_$ndir_mapped_info[parent_asid];

  { the same two copies again }
  name_$wdir_mapped_info[child_asid] := name_$wdir_mapped_info[parent_asid];
  name_$ndir_mapped_info[child_asid] := name_$ndir_mapped_info[parent_asid];
end;
