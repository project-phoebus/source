{ sm_$wire - wire the storage module driver's code and data, once.

  Image addresses:
    sau5  0x00E6EF86  sm_$wire (module-local)

  - The PBU, then the module's code and data; the pages go into
    sm_wired_pages, ten at most.

  Status stored: none.
}

procedure sm_$wire; internal;
var
  data_count: integer;
begin
  if not sm_$cb.flags.wired then begin
    pbu_$wire_pbu;
    mst_$wire_area(addr(sm_$proc_start), addr(sm_$proc_end),
                   sm_wired_pages, 10, sm_wired_count);
    mst_$wire_area(addr(sm_$data_start), addr(sm_$data_end),
                   sm_wired_pages[sm_wired_count], 10 - sm_wired_count,
                   data_count);
    sm_wired_count := sm_wired_count + data_count;
    sm_$cb.flags.wired := true;
  end;
end;
