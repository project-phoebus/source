{ dir_$do_op_read_linku - DIR_$DO_OP's handler for operation 16#3E,
  reading a soft link's text.

  Image addresses:
    sau2  0x00E4D5B4  dir_$do_op_read_linku

  - As super-user, the directory opened for reading (mode 1, rights 1);
    the result UID starts as UID_$NIL, the length as 0.
  - The text is in the entry after its name (link_page -1) or on a page
    of its own; it is cut to the buffer's length (a signed compare).

  Status stored:
    dir_$open_dir's status: the text was copied whole, or the directory
      could not be opened
    name_$not_found: the name is not in the directory
    name_$pathname_truncated: the text was cut
    name_$not_link: not a soft link (its UID handed back)
}

procedure dir_$do_op_read_linku(in uid: uid_$t;
                                in name: univ name_$long_name_t;
                                name_len: integer; buf_len: integer;
                                buf: dir_$text_ptr_t;
                                out link_type_ret: integer;
                                out uid_ret: dir_$uid_view_t;
                                out status_ret: status_$t);
label
  10;
var
  text: dir_$text_ptr_t;
  entry: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  find_extra: integer32;
  depth: integer;
  i: integer;
begin
  uid_ret.uid := uid_$nil;
  link_type_ret := 0;
  acl_$enter_super;

  dir_$open_dir(uid, 1, 1, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  if not dir_$find_entry(handle^, name, name_len, 0, entry, find_extra,
                         depth) then
    status_ret.all := name_$not_found
  else if entry^.flags & 7 = 4 then begin
    { the link's text }
    if entry^.link_page = -1 then
      text := dir_$text_ptr_t(entry^.name_len +
                              integer32(addr(entry^.link_name)))
    else
      text := dir_$map_link_page(handle^, entry^.link_page);

    link_type_ret := entry^.child;
    if buf_len < link_type_ret then begin
      link_type_ret := buf_len;
      status_ret.all := name_$pathname_truncated;
    end;

    for i := 1 to link_type_ret do
      buf^[i] := text^[i];
  end
  else begin
    status_ret.all := name_$not_link;
    uid_ret.uid := entry^.uid;
  end;

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
