{ ast_$count_valid_pages - give a run of page-map entries their pages, or
  report them null (nested in AST_$TOUCH).

  Image addresses:
    sau2  0x00E0305C  ast_$count_valid_pages (nested)
    sau8  0x03C033A4  ast_$count_valid_pages (nested)
    sau9  0x3C4043B0  ast_$count_valid_pages (nested)

  - When AST_$TOUCH's flags have member 1 (only pages that exist), the
    run's transition marks are cleared and the result is the run's
    count.
  - Otherwise as many zeroed pages as the run has entries (at least one)
    go into AST_$TOUCH's page list; the result is the number allocated.

  Status stored (in AST_$TOUCH's status):
    none: the pages were allocated
    status_$pmap_page_null: flags member 1
}

function ast_$count_valid_pages(var entries: univ ast_$pmap_run_t;
                                count: pinteger): pinteger;
var
  p: ast_$ppn_ptr_t;
  i: integer;
begin
  if 1 in ast_$word_set_t(flags) then begin
    ast_$clear_transition_bits(entries, count);
    status.all := status_$pmap_page_null;
  end
  else begin
    p := addr(ppn_array);
    count := ast_$allocate_pages(count, 1, ppn_array);
    for i := 1 to count do begin
      zero_page(p^);
      p := ast_$ppn_ptr_t(integer32(p) + 4);
    end;
  end;

  ast_$count_valid_pages := count;
end;
