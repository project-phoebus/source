{ PBU_$UNWIRE_USER_PAGES - unwire every page a unit has wired.

  Image addresses:
    sau5  0x00E59D7E  PBU_$UNWIRE_USER_PAGES

  - Only while the page owner table is in use (the Multibus present, or
    a VME unit set up).  For a unit above 15 every owned page is unwired
    outright, the owners kept; for a unit of 0..15 the pages it owns
    (PBU_$DELETE_PPN, its status ignored).

  Status stored: none.
}

procedure pbu_$unwire_user_pages(in unit: integer);
var
  ppn: linteger;
  owners: pbu_$unit_set_t;
  delete_status: status_$t;
begin
  if pbu_$mcb.present or pbu_$mcb.vme_set_up then
    for ppn := mmap_$lppn to mmap_$hppn do begin
      owners := pbu_$ppn_owners[ppn];
      if owners <> [] then
        if pinteger(unit) > pbu_$max_unit then
          wp_$unwire(ppn)
        else if unit in owners then
          pbu_$delete_ppn(unit, ppn, delete_status);
    end;
end;
