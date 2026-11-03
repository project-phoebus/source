{ sm_$format - format a track of a storage module drive.

  Image addresses:
    sau3  0x00E6E1CC  sm_$format (module-local)
    sau5  0x00E6F524  sm_$format (module-local)

  Assume we're called with the controller's lock held.

  - At most two tries; a failed command resets the controller (a failed
    reset ends them).  On an error the requester's pending flag is
    cleared.

  Status stored (in req):
    none: the track was formatted
    sm_$reset's status: a failed command, and the reset failed too
    sm_$check_status's status: the drive's status after the last try
}

procedure sm_$format(in vol: disk_$volume_t; var req: disk_$io_req_t);
  internal;
label
  failed;
var
  unit: integer;
  try: integer;
  status: integer32;
  rst_status: status_$t;
begin
  unit := vol.dev_unit;
  for try := 1 to 2 do begin
    sm_$cb.cyl := req.daddr.cyl;
    sm_$cb.head := req.daddr.head;
    sm_$cb.buf_offset := sm_$page_offset(addr(sm_$cb.fmt_block));
    rst_status.all := sm_$command(unit, sm_cmd_format);
    if rst_status.all <> 0 then begin
      sm_$reset(sm_dcte, rst_status);
      status := rst_status.all;
      if status <> 0 then
        goto failed;
    end
    else begin
      status := sm_$check_status(vol.dev_unit);
      if status = 0 then
        return;
    end;
  end;
  if status = 0 then
    return;

failed:
  disk_bptbl[req.owner_op.owner].io_pending := false;
  req.status.all := status;
end;
