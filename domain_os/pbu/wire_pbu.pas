{ PBU_$WIRE_PBU - wire the PBU page.

  Image addresses:
    sau3  0x00E59F7E  PBU_$WIRE_PBU
    sau5  0x00E5A42A  PBU_$WIRE_PBU

  - Once (PBU_$MCB.wired): the pages from PBU_$PAGE_START to
    PBU_$DATA_END, which interrupt-level code reaches, and their list
    kept for PBU_$SETDOWN.

  Status stored: none.
}

procedure pbu_$wire_pbu;
begin
  if not pbu_$mcb.wired then begin
    pbu_wired_count := 0;
    mst_$wire_area(addr(pbu_$page_start), addr(pbu_$data_end),
                   pbu_wired_pages, pbu_max_wired_pages, pbu_wired_count);
    pbu_$mcb.wired := true;
  end;
end;
