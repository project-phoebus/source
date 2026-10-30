{ DISK_$UNASSIGN - give up a volume assigned to the calling process.

  Image addresses:
    sau2  0x00E6BDA8  DISK_$UNASSIGN

  - On a node that is not really diskless, a volume assigned (mount
    state 2) to the calling process is dismounted.

  Status stored:
    status_$ok: the volume was dismounted
    status_$invalid_volume_index: an index outside 1..10
    status_$volume_not_properly_mounted: not assigned to the caller, or
      a really diskless node
}

procedure disk_$unassign(in vol_idx: integer; out status: status_$t);
begin
  if network_$really_diskless then
    status.all := status_$volume_not_properly_mounted
  else if not (vol_idx in [1..10]) then
    status.all := status_$invalid_volume_index
  else
    with disk_$dvtbl[vol_idx] do
      if (mount_state <> 2) or else (mount_proc <> proc1_$current) then
        status.all := status_$volume_not_properly_mounted
      else begin
        disk_$dismount(vol_idx);
        status.all := status_$ok;
      end;
end;
