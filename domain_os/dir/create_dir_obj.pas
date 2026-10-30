{ dir_$create_dir_obj - create a directory object and lay out its root
  page.

  Image addresses:
    sau2  0x00E52394  dir_$create_dir_obj (module-local)

  - Created in the parent's volume (FILE_$PRIV_CREATE, type 1); page 0
    becomes an empty root page with one stub entry, the parent's default
    protections and the caller's two default ACLs.
  - Each real default ACL gains a reference (attribute 6); the object is
    deleted if anything failed after its creation.
  - A failed file-ACL reference is rolled back with status_ret.

  Status stored:
    status_$ok: the directory object was made (the last step's status)
    file_$priv_create's or dir_$validate_handle's status: that step
      failed
    status_$naming_directory_locked: no handle was free
    ast_$set_attribute's status: a default ACL's reference failed
}

{ TODO(pascal) 0x30 bytes of dir_$create_dir_obj's frame that no object
  explains

  The SAU2 image's frame holds value, handle_ptr, local_status and
  delete_result, and leaves 0x30 bytes open: a run of 0x24 (the size of
  a 40-byte local buffer that nothing addresses) and two smaller ones.
  The register-held handle, page and dir_acl_byte may each keep a slot,
  which explains at most 12 of them.  dpc's frame is 0x24 bytes
  smaller. }

procedure dir_$create_dir_obj(in parent_uid: uid_$t;
                              in page0_data: dir_$root_page_t;
                              in dir_acl_uid: uid_$t;
                              in file_acl_uid: uid_$t;
                              var new_uid_ret: uid_$t;
                              out status_ret: status_$t);
  internal;
label
  10;
var
  value: file_$attr_value_t;
  handle_ptr: dir_$handle_ptr_t;
  local_status: status_$t;
  delete_result: boolean;
  handle: integer32;
  page: integer32;
  dir_acl_byte: integer;
begin
  discard(file_$priv_create(1, uid_$nil, parent_uid, new_uid_ret, 0, 0,
                            nil, status_ret));
  if status_ret.all <> status_$ok then
    return;

  handle := integer32(dir_$alloc_handle);
  if handle = 0 then begin
    status_ret.all := status_$naming_directory_locked;
    return;
  end;

  dir_$handle_ptr_t(handle)^.uid := new_uid_ret;
  dir_$validate_handle(dir_$handle_ptr_t(handle)^, 2, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  page := integer32(dir_$map_page(dir_$handle_ptr_t(handle)^, 0));

  with dir_$root_page_ptr_t(page)^ do begin
    { the header and the root area }
    hdr.flags.format := 5;
    hdr.flags.kind := 0;
    hdr.next_page := -1;
    entry_count := 1;
    base_offset := 16#68;
    root_len := base_offset + 8;
    hdr.index_end := 16#12 + root_len;
    hdr.heap_base := 16#400;

    { the index table's one slot }
    hdr.heap_base := (hdr.heap_base - 16#0E) & (-4);
    dir_$word_ptr_t(page + hdr.index_end)^ := hdr.heap_base;
    hdr.index_end := hdr.index_end + 2;

    { the stub entry }
    with dir_$entry_ptr_t(page + hdr.heap_base)^ do begin
      bits.kind := 4;
      name_len := 1;
      link_page := -1;
    end;

    { the default protections }
    dir_def_prot.prot := page0_data.dir_def_prot.prot;
    file_def_prot.prot := page0_data.file_def_prot.prot;
    dir_def_prot.acl_uid := dir_acl_uid;
    file_def_prot.acl_uid := file_acl_uid;
  end;

  { the directories' default ACL }
  value.word_val := 1;
  dir_acl_byte := dir_$uid_view_t(dir_acl_uid).b0;
  if dir_acl_byte <> 0 then begin
    ast_$set_attribute(dir_acl_uid, 6, value, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  { the files' default ACL }
  if dir_$uid_view_t(file_acl_uid).b0 <> 0 then begin
    ast_$set_attribute(file_acl_uid, 6, value, status_ret);
    if status_ret.all <> status_$ok then
      if dir_acl_byte <> 0 then
        ast_$set_attribute(dir_acl_uid, 7, value, status_ret);
  end
  else
    file_$fw_partial(new_uid_ret, 0, 16#400, local_status);

10:
  handle_ptr := dir_$handle_ptr_t(handle);
  dir_$release_handle(handle_ptr);
  if status_ret.all <> status_$ok then
    file_$delete_obj(new_uid_ret, true, delete_result, local_status);
end;
