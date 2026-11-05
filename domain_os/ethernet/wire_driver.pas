{ ethernet_wire_driver - wire the driver's code and data, and a unit's
  record.

  Image addresses:
    sau6  0x7808685A  ethernet_wire_driver
    sau7  0x3C49105A  ethernet_wire_driver
    sau8  0x03C8485A  ethernet_wire_driver
    sau9  0x3C48045A  ethernet_wire_driver

  - Under the I/O wiring lock.  The first unit to come up wires the
    code section (ETHER_PROC) and then the data section (ETHER_DATA)
    into the block's page list; each unit then wires its own record,
    once.

  Status stored: none.
}

procedure ethernet_wire_driver(u: ethernet_$unit_ptr_t); internal;
var
  pages: integer;
begin
  ml_$exclusion_start(io_$wiring_exclusion);
  ethernet_wire_users := ethernet_wire_users + 1;
  if ethernet_wire_users = 1 then begin
    mst_$wire_area(addr(ether_proc_start), addr(ether_proc_end),
                   ethernet_wire_list, 32, ethernet_wire_cnt);
    mst_$wire_area(addr(ether_data_start), addr(ether_data_end),
                   ethernet_wire_list[ethernet_wire_cnt + 1],
                   32 - ethernet_wire_cnt, pages);
    ethernet_wire_cnt := ethernet_wire_cnt + pages;
  end;
  if not u^.wired then begin
    mst_$wire_area(u, univ_ptr(integer32(u) + sizeof(ethernet_$unit_t) - 1),
                   ethernet_wire_list[ethernet_wire_cnt + 1],
                   32 - ethernet_wire_cnt, pages);
    ethernet_wire_cnt := ethernet_wire_cnt + pages;
    u^.wired := true;
  end;
  ml_$exclusion_stop(io_$wiring_exclusion);
end;
