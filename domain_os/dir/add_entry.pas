{ dir_$add_entry - add a named entry to an open directory (the parent of
  the B-tree insert family).

  Image addresses:
    sau2  0x00E4FE0A  dir_$add_entry (module-local)

  - A soft link whose name and text exceed 433 bytes gets a page of its
    own for the text (dir_$alloc_overflow_page); otherwise overflow_page
    is 16#FFFF.
  - A failed insert during a split runs DIR_$CLEANUP.
  - Its declaration part holds the nested insert family, whose variables
    are its locals.

  Status stored:
    dir_$insert_entry's status: the entry was inserted, or failed
    name_$bad_leaf: a NUL or '/' in the name, or "." or ".."
    name_$already_exists: the name is in the directory
    dir_$alloc_overflow_page's status: the text's page failed
}

{ TODO(pascal) dir_$add_entry's open frame bytes

  The SAU2 image's frame leaves 14 bytes no declared object explains (8
  together, between split_pages and remove_uid, and three single
  words): a local missing from the declarations, split_pages longer than
  the 16 words its users copy, or the slots of register-held locals.
  dpc lays the frame out without them, so the nested routines' accesses
  through their static links get other offsets than the image's.  Not
  settled; no stand-in is declared. }

procedure dir_$add_entry(var handle: dir_$handle_t;
                         in name: univ name_$long_name_t;
                         name_len: integer;
                         entry_type: pinteger;
                         extra: integer32;
                         in uid: uid_$t;
                         link_len: integer;
                         in link_data: univ name_$long_pname_t;
                         out status_ret: status_$t);
  internal;
var
  fim_data: fim_$cleanup_rec_t;
  remove_uid: uid_$t;
  split_pages: array[1..16] of pinteger;
  dir_uid: uid_$t;
  path: dir_$path_t;
  new_page: dir_$root_page_ptr_t;
  inter_page: dir_$root_page_ptr_t;
  recursive_param: linteger;
  first_child_name: dir_$name_ptr_t;
  first_child_idx: dir_$word_ptr_t;
  first_child_entry: dir_$entry_ptr_t;
  temp_entry: dir_$entry_ptr_t;
  idx_base: dir_$index_ptr_t;
  page_data: dir_$root_page_ptr_t;
  fim_status: status_$t;
  accum_size: integer;
  split_threshold: integer;
  free_space: integer;
  recursive_name_len: integer;
  copy_start: integer;
  page_count: integer;
  current_slot: integer;
  overflow_page: pinteger;
  max_depth: integer;
  i: integer;

%include 'dir/alloc_overflow_page.pas';      { dir_$alloc_overflow_page }
%include 'dir/insert_entry.pas';             { dir_$insert_entry, and its
                                               seven }

begin
  for i := 1 to name_len do
    if (name[i] = chr(0)) or else (name[i] = '/') then begin
      status_ret.all := name_$bad_leaf;
      return;
    end;

  if (name[1] = '.') and then
     ((name_len = 1) or else ((name_len = 2) and then (name[2] = '.')))
  then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  if dir_$find_entry(handle, name, name_len, 8, temp_entry, path,
                     max_depth) then begin
    status_ret.all := name_$already_exists;
    return;
  end;

  if (entry_type = 4) and then (name_len + link_len > 433) then begin
    dir_$alloc_overflow_page(status_ret);
    if status_ret.all <> status_$ok then
      return;
  end
  else
    overflow_page := 16#FFFF;

  dir_$insert_entry(max_depth, 0, name_len, status_ret);

  if (status_ret.all <> status_$ok) and then handle.split_busy then
    dir_$cleanup;
end;
