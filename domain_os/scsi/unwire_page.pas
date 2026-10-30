{ scsi_unwire_page - unwire a physical page for a device.

  Image addresses:
    sau9  0x3C4A6836  scsi_unwire_page

  - The page's last owner restores its caching and gives the wiring
    back.

  Status stored:
    status_$ok: the page is no longer wired for the device
    status_$scsi_page_not_wired: the device does not have it wired
}

procedure scsi_unwire_page(dev: integer; ppn: integer32;
                           out status: status_$t); internal;
var
  owners: scsi_owners_t;
begin
  owners := scsi_$ppn_owners[ppn];
  if not (dev in owners) then
    status.all := status_$scsi_page_not_wired
  else begin
    owners := owners - [dev];
    scsi_$ppn_owners[ppn] := owners;
    if owners = [] then begin
      ast_$cache_enable_ppn(ppn);
      wp_$unwire(ppn);
    end;
    status.all := status_$ok;
  end;
end;
