{ dir_$finalize_split - end a split: purify the pages now on the path
  and drop the directory's spare pages (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4EECA  dir_$finalize_split (nested)

  - Nested in dir_$insert_entry (itself nested in dir_$add_entry), whose
    frames it reaches.

  Status stored:
    dir_$truncate_pages' status: the pages were purified
    dir_$purify_split_pages' status: they could not be
}

    procedure dir_$finalize_split(out status_ret: status_$t);
    var
      new_end: pinteger;
      level: integer;
    begin
      new_end := split_pages[max_depth - current_slot + 1];

      for level := current_slot to max_depth do
        split_pages[level - current_slot + 1] := path[level].page_no;

      dir_$purify_split_pages(status_ret);

      if status_ret.all = status_$ok then
        dir_$truncate_pages(handle, new_end, status_ret);
    end;
