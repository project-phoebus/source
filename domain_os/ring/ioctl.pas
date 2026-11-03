{ RING_$IOCTL - a unit's control request: set the transmit mask.

  Image addresses:
    sau2  0x00E76B2C  RING_$IOCTL
    sau3  0x00E7831C  RING_$IOCTL
    sau5  0x00E7DDAC  RING_$IOCTL

  Status stored:
    status_$ok: command 0 set the unit's transmit mask
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_not_implemented: any other command
}

procedure ring_$ioctl(var unit: pinteger; var cmd: ring_$ioctl_cmd_t;
                      reserved: integer; var param4: univ integer32;
                      out status: status_$t);
  options(val_param);
var
  mask: pinteger;
begin
  if unit > 1 then
    status.all := status_$ring_invalid_unit_num
  else if cmd.cmd = 0 then begin
    mask := cmd.tmask;
    ring_$set_hw_mask(unit, mask);
    status.all := 0;
  end
  else
    status.all := status_$ring_not_implemented;
end;
