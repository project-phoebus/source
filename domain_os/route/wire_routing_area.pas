{ route_$wire_routing_area - wire the routing code and data.

  Image addresses:
    sau2  0x00E69BCE  route_$wire_routing_area (module-local)

  - Only when no page is wired yet: the area from RTWIRED_PROC_START to
    RTWIRED_DATA_END, up to ten pages, into ROUTE_$WIRED_PAGES.

  Status stored: none.
}

procedure route_$wire_routing_area; internal;
begin
  if route_$n_wired_pages = 0 then
    mst_$wire_area(addr(rtwired_proc_start), addr(rtwired_data_end),
                   route_$wired_pages, 10, route_$n_wired_pages);
end;
