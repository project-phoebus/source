{ VOLX_$GET_UIDS - the UIDs of the volume at a physical location.

  Image addresses:
    sau2  0x00E6B62C  VOLX_$GET_UIDS

  Status stored:
    status_$ok: the logical volume's and the directory's UIDs were
      returned
    status_$volume_logical_vol_not_mounted: no mounted volume is at the
      location
}

{ TODO(pascal) the value parameters' copies in reverse order

  The SAU2 image lays the four copies out with the first parameter
  lowest; dpc allocates value parameters' copies from the top in
  parameter order, which gives the reverse.  vol's slot (held in a
  register) and the remaining bytes are not placed either. }

procedure volx_$get_uids(dev: integer; bus: integer; ctlr: integer;
                         lv_num: integer; out lv_uid_ret: uid_$t;
                         out dir_uid_ret: uid_$t; out status: status_$t);
var
  vol: integer;
begin
  vol := find_volx(dev, bus, ctlr, lv_num);

  if vol <> 0 then begin
    with volx_$table[vol] do begin
      lv_uid_ret := e_lv_uid;
      dir_uid_ret := e_dir_uid;
    end;
    status.all := status_$ok;
  end
  else
    status.all := status_$volume_logical_vol_not_mounted;
end;
