{ COLOR2_$SHUTDOWN - give up the graphics board's color display at
  shutdown.

  Image addresses:
    sau5  0x00E7327E  COLOR2_$SHUTDOWN

  - Once the display has been associated, the current process takes it
    over and gives it back (COLOR2_$DISSOC).

  Status stored: none.
}

procedure color2_$shutdown;
begin
  if color2_associated then begin
    if smd_$graphic_device_id = smd_gdev_color2 then
      color2_owner2 := proc1_$current
    else if smd_$graphic_device_id = smd_gdev_color3 then
      color2_owner3 := proc1_$current;
    color2_$dissoc;
  end;
end;
