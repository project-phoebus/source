{ dir_$purify_split_pages - sort a split's pages and purify them
  (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4EA9C  dir_$purify_split_pages (nested)

  - The pages are sorted in descending order (an exchange sort,
    unsigned) and purified with one AST_$PURIFY call.
  - Nested in dir_$insert_entry (itself nested in dir_$add_entry), whose
    frames it reaches.

  Status stored:
    ast_$purify's status: always
}

    procedure dir_$purify_split_pages(out status_ret: status_$t);
    var
      page_list: array[1..16] of integer32;
      i: integer;
      j: integer;
      t: pinteger;
    begin
      { descending order, compared unsigned }
      for i := 1 to page_count - 1 do
        for j := i + 1 to page_count do
          if split_pages[j] > split_pages[i] then begin
            t := split_pages[i];
            split_pages[i] := split_pages[j];
            split_pages[j] := t;
          end;

      for i := 1 to page_count do
        page_list[i] := split_pages[i];

      ast_$purify(handle.uid, 16#12, 0, page_list, page_count, status_ret);
    end;
