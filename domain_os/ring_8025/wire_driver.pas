{ ring_8025_wire_driver - wire the driver's code and data, a unit's
  control area and route cache, and its record.

  Image addresses:
    sau8  0x03C89080  ring_8025_wire_driver
    sau9  0x3C484C80  ring_8025_wire_driver

  - Under the I/O wiring lock.  The first unit to come up wires the
    code section (RING8025_PROC) and then the data section
    (RING8025_DATA) into the block's page list; each unit then wires its
    own areas and record, once.
  - The control area is backed by six contiguous physical pages,
    asked for up to 30 times a tick apart; the route cache by eight
    pages from WP_$CALLOC_LIST.  Each page is wired and installed at its
    place in the auxiliary area.
  - The unit's record is wired to its byte at 0x432.

  Status stored:
    status_$ok: the unit is wired
    status_$r8025_internal_driver_error: no contiguous pages for the
      control area
}

procedure ring_8025_wire_driver(u: ring_8025_$unit_ptr_t;
                                out status: status_$t); internal;
label
  done;
var
  max_pages: integer;
  pages: integer;
  n: integer;
  ctl_ppns: array[1..r8025_ctl_pages] of integer32;
  route_ppns: array[1..r8025_route_pages] of integer32;
  va: integer32;
  tries: integer;
  i: integer;
begin
  ml_$exclusion_start(io_$wiring_exclusion);
  ring_8025_wire_users := ring_8025_wire_users + 1;
  if ring_8025_wire_users = 1 then begin
    mst_$wire_area(addr(ring8025_proc_st), addr(ring8025_proc_en),
                   ring_8025_wire_list, r8025_wire_max, ring_8025_wire_cnt);
    max_pages := r8025_wire_max - ring_8025_wire_cnt;
    mst_$wire_area(addr(ring8025_data_st), addr(ring8025_data_en),
                   ring_8025_wire_list[ring_8025_wire_cnt + 1], max_pages,
                   pages);
    ring_8025_wire_cnt := ring_8025_wire_cnt + pages;
  end;
  status.all := status_$ok;
  if not u^.wired then begin
    if not u^.ctl_wired then begin
      n := r8025_ctl_pages;
      for tries := 1 to 30 do begin
        ast_$alloc_contig(n, ctl_ppns, status);
        if status.all = status_$ok then
          exit;
        discard(ec_$waitn(addr(time_$clockh_ec),
                          ec_$read(time_$clockh_ec) + 1, 1));
      end;
      if status.all <> status_$ok then begin
        status.all := status_$r8025_internal_driver_error;
        goto done;
      end;
      va := integer32(addr(ring8025_$aux_da.ctl[u^.cnum]));
      for i := 1 to r8025_ctl_pages do begin
        wp_$wire(ctl_ppns[i]);
        mmu_$install(ctl_ppns[i], univ_ptr(va), 0, 16#16);
        va := va + 1024;
      end;
      u^.ctl_wired := true;
    end;
    if not u^.routes_wired then begin
      n := r8025_route_pages;
      wp_$calloc_list(n, route_ppns);
      va := integer32(addr(ring8025_$aux_da.routes[u^.cnum]));
      for i := 1 to r8025_route_pages do begin
        wp_$wire(route_ppns[i]);
        mmu_$install(route_ppns[i], univ_ptr(va), 0, 16#16);
        va := va + 1024;
      end;
      u^.routes_wired := true;
    end;
    max_pages := r8025_wire_max - ring_8025_wire_cnt;
    mst_$wire_area(u,
                   univ_ptr(integer32(u) + sizeof(ring_8025_$unit_t) - 2),
                   ring_8025_wire_list[ring_8025_wire_cnt + 1], max_pages,
                   pages);
    ring_8025_wire_cnt := ring_8025_wire_cnt + pages;
    u^.wired := true;
  end;
done:
  ml_$exclusion_stop(io_$wiring_exclusion);
end;
