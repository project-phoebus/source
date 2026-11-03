{ iic_map_iova - map a physical page at an I/O address.

  Image addresses:
    sau3  0x00E85518  iic_map_iova (module-local)

  - The PBU's I/O map entry of the I/O address's 1 KB page gets the
    physical address's page number and the valid bit.

  Status stored: none.
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_map_iova(pa: integer32; iova: integer32); internal;
begin
  iic_$iomap_ptr_t(addr(iomap))^[rshft(iova, 10)].page := rshft(pa, 10) + 16#8000;
end;
