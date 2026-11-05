{ COLOR2_$ASSOC - give the graphics board's color display to the caller.

  Image addresses:
    sau5  0x00E73192  COLOR2_$ASSOC
    sau6  0x7807A026  COLOR2_$ASSOC

  - ctl is the board's control block's address; with `vm_regions'
    (base/config.ins.pas) the address of the board's 64 pages mapped into
    two of the caller's special segments, from page 16#1240 (the DN580's)
    or 16#180 (the DN570's), and nothing else is done when the mapping
    fails.  A display another
    process held is taken from it (COLOR2_$DISSOC on its behalf), the
    caller becomes the owner and the video is turned on.

  Status stored: none.
}

procedure color2_$assoc(out ctl: univ_ptr);
%if vm_regions %then
var
  special_va: univ_ptr;
  status: status_$t;
  first_ppn: integer32;
  i: integer;
%endif
begin
%if vm_regions %then
  { the board's 64 pages in the caller's special segment }
  special_va := mst_$map_special(0, 2, special_seg_$uid, proc1_$as_id,
                                 status);
  if status.all <> status_$ok then
    return;
  if smd_$graphic_device_id = smd_gdev_color2 then
    first_ppn := 16#1240
  else
    first_ppn := 16#180;
  for i := 0 to 63 do
    mmu_$install_special(first_ppn + i,
                         univ_ptr(integer32(special_va) + i * 1024),
                         proc1_$as_id, 6);
  ctl := special_va;
%else
  ctl := addr(kolor_ctl);
%endif
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
