{ DISK_$MNT_DINIT - initialize a drive through its driver.

  Image addresses:
    sau2  0x00E3DA64  DISK_$MNT_DINIT

  - The driver's dinit entry is called with the unit, the entry's
    controller and the five result cells.

  Returns:
    the driver's status: in either case

  Status stored: none.
}

function disk_$mnt_dinit(unit: pinteger; var dev: disk_$device_entry_ptr_t;
                         var num_blocks: univ integer32;
                         var sec_per_track: pinteger;
                         var num_heads: pinteger;
                         out pvlabel_info: univ disk_$pvlabel_info_t;
                         out flags: pinteger): integer32;
begin
  disk_$mnt_dinit :=
    disk_$dinit_proc_t(disk_$jump_table_ptr_t(dev^.jump_table)^.dinit)^(
      unit, dev^.controller, num_blocks, sec_per_track, num_heads,
      pvlabel_info, flags);
end;
