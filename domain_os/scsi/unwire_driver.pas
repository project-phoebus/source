{ scsi_unwire_driver - unwire the driver's own code and data.

  Image addresses:
    sau9  0x3C4A4EFC  scsi_unwire_driver
}

procedure scsi_unwire_driver; internal;
var
  i: integer;
begin
  for i := 1 to scsi_wired_count do
    wp_$unwire(scsi_wired_pages[i]);
  scsi_wired := false;
end;
