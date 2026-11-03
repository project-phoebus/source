{ PBU_$SAVE_PPN - wire a page for a unit.

  Image addresses:
    sau3  0x00E59BB6  PBU_$SAVE_PPN
    sau5  0x00E59E20  PBU_$SAVE_PPN

  - The page at va is wired (MST_$WIRE), and its number is the result.
    A page the PBU has wired already keeps one wiring; else the unit
    joins the page's owner set.

  Status stored:
    mst_$wire's status: the page was wired, or not
    status_$pbu_bad_buffer_address: the page is not MMAP_$LPPN..
      MMAP_$HPPN
    status_$pbu_page_already_wired: the unit has the page wired
}

function pbu_$save_ppn(unit: integer; va: linteger;
                       out status: status_$t): integer32;
  options(val_param);
var
  ppn: linteger;
  owners: pbu_$unit_set_t;
begin
  ppn := mst_$wire(va, status);
  pbu_$save_ppn := ppn;
  if status.all <> status_$ok then
    return;
  if (ppn < mmap_$lppn) or else (ppn > mmap_$hppn) then begin
    status.all := status_$pbu_bad_buffer_address;
    return;
  end;
  owners := pbu_$ppn_owners[ppn];
  if owners <> [] then
    wp_$unwire(ppn);
  if unit in owners then
    status.all := status_$pbu_page_already_wired
  else begin
    owners := owners + [unit];
    pbu_$ppn_owners[ppn] := owners;
  end;
end;
