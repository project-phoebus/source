{ NETBUF_$INIT - set up the network buffers.

  Image addresses:
    sau2  0x00E2F630  NETBUF_$INIT

  - The window's address is stored and its 192 slots linked into the
    free list (slot k holds k + 1, the last -1).
  - The data pool's limit is half the pageable pages; 39 header and 10
    data pages are added.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure netbuf_$init;
var
  i: integer32;
  unused_8: integer32;                    { stand-in }
begin
  netbuf_$va_base_addr := integer32(addr(network_$bufpool));

  { the slot free list }
  for i := 0 to 191 do
    netbuf_$va_slots[i] := i + 1;
  netbuf_$va_slots[191] := -1;

  netbuf_$dat_lim := rshft(mmap_$pageable_pages, 1);

  netbuf_$add_pages(39, 10);
end;
