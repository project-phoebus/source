{ mst_$init_table_page - allocate, install and zero one page of MSTEs.

  Image addresses:
    sau2  0x00E42CEC  mst_$init_table_page (module-local)
    sau4  0x0F84ACA0  mst_$init_table_page (module-local)
    sau8  0x03C4AD44  mst_$init_table_page (module-local)
    sau9  0x3C44A078  mst_$init_table_page (module-local)

  - A wired page from WP_$CALLOC is installed at va's page (protection
    16#16) and cleared; its page number is the result.

  Status stored: none.
}

function mst_$init_table_page(va: linteger): linteger; internal;
var
  status: status_$t;
  unused_c: integer32;                    { stand-in }
  ppn: integer32;
  p: integer32;
  page: mst_mem_page_ptr_t;
  i: integer;
begin
  page := mst_mem_page_ptr_t(va & 16#FFFFFC00);
  wp_$calloc(ppn, status);
  p := ppn;
  mmu_$install(p, page, 0, 16#16);
  for i := 0 to 255 do
    page^[i] := 0;
  mst_$init_table_page := p;
end;

{ TODO(pascal) mst_$init_table_page's frame and the clearing loop

  The image's frame leaves 4 open bytes above ppn and above status and 8
  below ppn; unused_c reproduces the 4 between them.  The clearing loop
  keeps no index in the image, so dpc's frame is 8 bytes larger. }
