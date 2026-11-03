{ ring_$wire_driver - wire the driver's code and data, once.

  Image addresses:
    sau2  0x00E7667C  ring_$wire_driver (module-local)
    sau8  0x03C82F6A  ring_$wire_driver (module-local)

  - Under the I/O wiring lock, when nothing is wired yet, the driver's
    code section (RING_PROC) and then its data section (RING_DATA) are
    wired into the block's page list.

  Status stored: none.
}

procedure ring_$wire_driver; internal;
var
  data_max_pages: integer;
  data_pages: integer;
begin
  ml_$exclusion_start(io_$wiring_exclusion);
  if ring_$wire_cnt = 0 then begin
    mst_$wire_area(addr(ring_proc_start), addr(ring_proc_end),
                   ring_$wire_list, 32, ring_$wire_cnt);
    data_max_pages := 32 - ring_$wire_cnt;
    mst_$wire_area(addr(ring_data_start), addr(ring_data_end),
                   ring_$wire_list[ring_$wire_cnt], data_max_pages,
                   data_pages);
    ring_$wire_cnt := ring_$wire_cnt + data_pages;
  end;

  ml_$exclusion_stop(io_$wiring_exclusion);
end;
