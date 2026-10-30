{ DISK_$AS_OPTIONS - set the async options of an assigned volume.

  Image addresses:
    sau2  0x00E6C0A8  DISK_$AS_OPTIONS

  - A volume assigned (mount state 2) to the calling process gets the
    caller's options word.

  Status stored:
    status_$ok: the options were set
    status_$invalid_volume_index: an index outside 1..10
    status_$volume_not_properly_mounted: the volume is not assigned to
      the calling process
}

procedure disk_$as_options(in vol_idx: integer; in options: disk_$as_options_t;
                           out status: status_$t);
begin
  if not (vol_idx in [1..10]) then
    status.all := status_$invalid_volume_index
  else begin
    status.all := status_$ok;
    with disk_$dvtbl[vol_idx] do
      if (mount_state <> 2) or else (mount_proc <> proc1_$current) then
        status.all := status_$volume_not_properly_mounted
      else
        as_options := options;
  end;
end;
