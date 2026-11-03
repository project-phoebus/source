{ ATBUS_$XLATE_IOVA - translate an AT bus address to a page number.

  Image addresses:
    sau9  0x3C40C9FC  ATBUS_$XLATE_IOVA
    sau8  0x03C0B9C4  ATBUS_$XLATE_IOVA

  - An address up to 16#400 is an I/O port: a page for each 8 ports,
    from page 16#100.  Above, a memory address: 1024 bytes to a page.
  - The same code on the SAU7, SAU8 and SAU9.

  Status stored: none.
}

function atbus_$xlate_iova(bus_addr: linteger): integer32;
  options(val_param);
begin
  if bus_addr <= atbus_$io_port_limit then
    atbus_$xlate_iova :=
      bus_addr div atbus_$io_ports_per_page + atbus_$io_first_page
  else
    atbus_$xlate_iova := bus_addr div atbus_$page_size;
end;
