{ cold_page_round - an address rounded up to a page.

  Image addresses:
    sau9  0x040030BE  cold_page_round (module-local)

  Status stored: none.
}

function cold_page_round(a: integer32): integer32; internal;
begin
  cold_page_round := (a + 1023) & (-1024);
end;
