{ scsi_wire_page - wire a page of the current address space for a
  device.

  Image addresses:
    sau7  0x3C4B9150  scsi_wire_page
    sau9  0x3C4A67B8  scsi_wire_page

  - The page's first owner has its caching inhibited; any later one
    gives the extra wiring back at once.
  - Returns the page number (when it was wired for the device).

  Status stored:
    status_$ok: the page is wired for the device
    MST_$WIRE's status: the page could not be wired
    status_$scsi_page_already_wired: the device has it wired already
}

function scsi_wire_page(dev: integer; va: integer32;
                        out status: status_$t): integer32; internal;
var
  ppn: integer32;
  owners: scsi_owners_t;
begin
  ppn := mst_$wire(va, status);
  if status.all = status_$ok then begin
    owners := scsi_$ppn_owners[ppn];
    if owners = [] then
      ast_$cache_inhibit_ppn(ppn)
    else
      wp_$unwire(ppn);
    if dev in owners then
      status.all := status_$scsi_page_already_wired
    else begin
      owners := [dev] + owners;
      scsi_$ppn_owners[ppn] := owners;
      scsi_wire_page := ppn;
    end;
  end;
end;
