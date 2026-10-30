{ COLOR_$ASSOC - give the color board to the calling process.

  Image addresses:
    sau5  0x00E72D12  COLOR_$ASSOC

  - The board's user page is installed at 16#6000 in the caller's address
    space (page 16#39, protection 6); va and cstore are that address and
    the control store's.
  - A board another process held is taken from it (COLOR_$DISSOC on its
    behalf); the display is turned on.

  Status stored: none.
}

procedure color_$assoc(out va: univ_ptr; out cstore: univ_ptr);
begin
  mmu_$install_private(16#39, univ_ptr(16#6000), proc1_$as_id, 6);
  va := univ_ptr(16#6000);
  cstore := addr(color_cstore);
  color_associated := true;
  if color_owner <> 0 then
    if color_owner <> proc1_$current then begin
      color_owner := proc1_$current;
      color_$dissoc;
      color_page_count := 0;
    end;
  color_owner := proc1_$current;
  color_sup.command := 16#280E;
end;
