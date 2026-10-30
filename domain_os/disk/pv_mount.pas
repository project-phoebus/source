{ DISK_$PV_MOUNT - mount a physical volume.

  Image addresses:
    sau2  0x00E6C9E8  DISK_$PV_MOUNT

  - disk_$pv_mount_internal with mount type 2, a block count of 18 and
    one sector and one head as the starting geometry; the first
    member's volume index is the result.

  Status stored:
    disk_$pv_mount_internal's status: in either case
}

function disk_$pv_mount(dev: integer; bus: integer; ctlr: integer;
                        out status: status_$t): integer;
var
  pv_label: disk_$pvlabel_buf_t;
  num_blocks: integer32;
  unit_id: pinteger;
  num_heads: pinteger;
  sec_per_track: pinteger;
begin
  num_blocks := 18;
  sec_per_track := 1;
  num_heads := 1;
  disk_$pv_mount := disk_$pv_mount_internal(2, dev, bus, ctlr, unit_id,
                                            num_blocks, sec_per_track,
                                            num_heads, pv_label, status);
end;
