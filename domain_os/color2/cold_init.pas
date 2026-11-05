{ COLOR2_$COLD_INIT - initialize the graphics board's color display
  driver at boot.

  Image addresses:
    sau5  0x00E73138  COLOR2_$COLD_INIT
    sau6  0x78079FC8  COLOR2_$COLD_INIT

  - The DN580's display gets COLOR2_$INT_EC and its interrupt
    (COLOR2_$INT_INIT); the DN570's its control word's copy with the
    video on.  Neither has an owner, nor is associated.

  Status stored: none.
}

procedure color2_$cold_init;
begin
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    color2_owner2 := 0;
    ec_$init(color2_$int_ec);
    color2_$int_init;
  end
  else if smd_$graphic_device_id = smd_gdev_color3 then begin
    color3_$cr_contents := 16#8;
    color2_owner3 := 0;
  end;
  color2_associated := false;
end;
