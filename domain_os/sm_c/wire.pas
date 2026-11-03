{ sm_c_$wire - wire the SM_C driver's code and the command block, once.

  Image addresses:
    sau3  0x00E6EDD0  sm_c_$wire (module-local; the map's SM_C_$PROC_START)
    sau5  0x00E74934  sm_c_$wire (module-local; the map's SM_C_$PROC_START)

  - Wires the PBU, the module's code (at most 15 pages) and the command
    block's page; a failure of the last crashes the system.
  - The map's SM_C_$PROC_START, the mark of the module's wired range, is
    the routine's first byte.

  Status stored: none.
}

procedure sm_c_$wire; internal;
var
  status: status_$t;
begin
  if not sm_c_wired then begin
    pbu_$wire_pbu;
    mst_$wire_area(addr(sm_c_$proc_start), addr(sm_c_$proc_end),
                   sm_c_wired_pages, 15, sm_c_wired_count);
    sm_c_wired_count := sm_c_wired_count + 1;
    sm_c_wired_pages[sm_c_wired_count] :=
      mst_$wire(integer32(addr(sm_$cb)), status);
    if status.all <> 0 then
      crash_system(status);
    sm_c_wired := true;
  end;
end;
