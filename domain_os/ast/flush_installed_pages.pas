{ ast_$flush_installed_pages - unmap and free the pages AST_$FREE_PAGES has
  collected (nested in AST_$FREE_PAGES).

  Image addresses:
    sau2  0x00E03FBC  ast_$flush_installed_pages (nested)
    sau4  0x0F80439C  ast_$flush_installed_pages (nested)
    sau8  0x03C042E8  ast_$flush_installed_pages (nested)
    sau9  0x3C4052F4  ast_$flush_installed_pages (nested)

  - The gathered installed pages are removed from the MMU and given back
    to the page pool, the segment's page count goes down by their
    number, and the count is cleared.

  Status stored: none.
}

  procedure ast_$flush_installed_pages;
  begin
%if pmmu_page_maps or region_mmu %then
    { the entries are cleared by the caller: the translations flushed }
    mmu_$purge;
%else
    mmu_$remove_list(installed_pages, installed_count);
%endif

    mmap_$free_pages(proc1_$current, installed_pages, installed_count);

    aste.page_count := chr(ord(aste.page_count) - installed_count);

    installed_count := 0;
  end;
