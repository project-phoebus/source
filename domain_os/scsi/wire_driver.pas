{ scsi_wire_driver - wire the driver's own code and data.

  Image addresses:
    sau7  0x3C4B8344  scsi_wire_driver
    sau9  0x3C4A4EC0  scsi_wire_driver

  - Once: from SCSI_$PROC_START to SCSI_$DATA_END, at most 11 pages.
}

procedure scsi_wire_driver; internal;
begin
  if not scsi_wired then begin
    scsi_wired_count := 0;
    mst_$wire_area(addr(scsi_$proc_start), addr(scsi_$data_end),
                   scsi_wired_pages, 11, scsi_wired_count);
    scsi_wired := true;
  end;
end;
