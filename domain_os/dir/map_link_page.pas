{ dir_$map_link_page - map a directory's link-text page.

  Image addresses:
    sau2  0x00E4D572  dir_$map_link_page

  - A page whose kind is not 2 (a link page) crashes the system.
  - The result is the address of the page's second byte, where the link
    text begins.

  Status stored: none.
}

function dir_$map_link_page(var handle: dir_$handle_t;
                            page: pinteger): univ_ptr;
  internal;
var
  page_hdr: dir_$page_hdr_ptr_t;
begin
  page_hdr := dir_$map_page(handle, page);

  if page_hdr^.flags.kind <> 2 then
    crash_system(status_$naming_internal_error);

  dir_$map_link_page := univ_ptr(integer32(page_hdr) + 1);
end;
