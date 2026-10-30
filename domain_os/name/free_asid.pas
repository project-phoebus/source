{ NAME_$FREE_ASID - release an address space's directories.

  Image addresses:
    sau2  0x00E74DA8  NAME_$FREE_ASID
    sau9  0x3C47C948  NAME_$FREE_ASID

  - As super-user, the working and naming directory mappings are undone
    and both UIDs reset to the node's directory.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of NAME_$FREE_ASID no object explains

  The SAU2 frame has 4 bytes in a global routine with no local the code
  addresses (stand-in unused_4). }

[section(proc2_delete_pro, proc2_delete_dat)]
procedure name_$free_asid(in asid: integer);
var
  unused_4: integer32;                    { the TODO above }
begin
  acl_$enter_super;
  name_$unmap_dir_buffers(asid, name_$wdir_mapped_info[asid]);
  name_$unmap_dir_buffers(asid, name_$ndir_mapped_info[asid]);
  name_$wdir_uid[asid] := name_$node_uid;
  name_$ndir_uid[asid] := name_$node_uid;
  acl_$exit_super;
end;
