{ DISK_$REVALID - let the volume's driver revalidate it.

  Image addresses:
    sau2  0x00E3DB74  DISK_$REVALID

  - The volume's driver's revalidate entry (the jump table's +0x0C) is
    called with the volume, if the driver has one.

  Status stored: none.
}

procedure disk_$revalid(in vol: disk_$volume_t);
begin
  if disk_$jump_table_ptr_t(vol.dev_info^.jump_table)^.revalidate <> nil then
    disk_$revalidate_proc_t(
      disk_$jump_table_ptr_t(vol.dev_info^.jump_table)^.revalidate)^(vol);
end;
