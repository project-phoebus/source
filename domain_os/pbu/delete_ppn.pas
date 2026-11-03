{ PBU_$DELETE_PPN - take a unit out of a wired page's owners.

  Image addresses:
    sau3  0x00E59A8A  PBU_$DELETE_PPN
    sau5  0x00E59D00  PBU_$DELETE_PPN

  - The page is unwired (WP_$UNWIRE) when no owner is left.

  Status stored:
    status_$ok: the unit left the page's owners
    status_$pbu_bad_buffer_address: ppn is not MMAP_$LPPN..MMAP_$HPPN
    status_$pbu_page_not_wired: the unit has not wired the page
}

procedure pbu_$delete_ppn(unit: integer; ppn: linteger;
                          out status: status_$t);
  options(val_param);
var
  owners: pbu_$unit_set_t;
begin
  if (ppn < mmap_$lppn) or else (ppn > mmap_$hppn) then
    status.all := status_$pbu_bad_buffer_address
  else begin
    owners := pbu_$ppn_owners[ppn];
    if not (unit in owners) then
      status.all := status_$pbu_page_not_wired
    else begin
      owners := owners - [unit];
      pbu_$ppn_owners[ppn] := owners;
      if owners = [] then
        wp_$unwire(ppn);
      status.all := status_$ok;
    end;
  end;
end;
