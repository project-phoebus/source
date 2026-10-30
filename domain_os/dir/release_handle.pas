{ dir_$release_handle - unlock, unmap and free a directory handle.

  Image addresses:
    sau2  0x00E4B9D6  dir_$release_handle

  - A nil handle pointer is left; else the handle is released and the
    pointer cleared.

  Status stored: none.
}

procedure dir_$release_handle(in out handle_ptr: dir_$handle_ptr_t);
  internal;
begin
  if handle_ptr <> nil then begin
    dir_$unlock_obj(handle_ptr^);
    dir_$unmap_pages(handle_ptr^);
    dir_$free_handle(handle_ptr^);
    handle_ptr := nil;
  end;
end;
