{ COLOR2_$DISSOC - take the graphics board's color display back from
  its owner.

  Image addresses:
    sau5  0x00E7321E  COLOR2_$DISSOC

  - Only for the display's owner: the board is waited for and the
    display has no owner.  COLOR2_$BUSY_WAIT's status is ignored.

  Status stored: none.
}

procedure color2_$dissoc;
var
  status: status_$t;
begin
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    if color2_owner2 <> proc1_$current then
      status.all := status_$color2_illegal_caller
    else begin
      color2_$busy_wait(status);
      color2_owner2 := 0;
    end;
  end
  else if smd_$graphic_device_id = smd_gdev_color3 then begin
    if color2_owner3 <> proc1_$current then
      status.all := status_$color2_illegal_caller
    else begin
      color2_$busy_wait(status);
      color2_owner3 := 0;
    end;
  end;
end;
