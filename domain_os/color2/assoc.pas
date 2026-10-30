{ COLOR2_$ASSOC - give the graphics board's color display to the caller.

  Image addresses:
    sau5  0x00E73192  COLOR2_$ASSOC

  - ctl is the board's control block's address.  A display another
    process held is taken from it (COLOR2_$DISSOC on its behalf), the
    caller becomes the owner and the video is turned on.

  Status stored: none.
}

procedure color2_$assoc(out ctl: univ_ptr);
begin
  ctl := addr(kolor_ctl);
  color2_associated := true;
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    if color2_owner2 <> 0 then
      if color2_owner2 <> proc1_$current then begin
        color2_owner2 := proc1_$current;
        color2_$dissoc;
      end;
    color2_owner2 := proc1_$current;
    kolor_ctl.ctl := kolor_ctl.ctl + [3];
  end
  else if smd_$graphic_device_id = smd_gdev_color3 then begin
    if color2_owner3 <> 0 then
      if color2_owner3 <> proc1_$current then begin
        color2_owner3 := proc1_$current;
        color2_$dissoc;
      end;
    color2_owner3 := proc1_$current;
    color3_$cr_contents := color3_$cr_contents ! 16#8;
    kolor_ctl.cr := color3_$cr_contents;
  end;
end;
