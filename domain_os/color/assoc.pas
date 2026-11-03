{ COLOR_$ASSOC - give the color board to the calling process.

  Image addresses:
    sau4  0x0F87B0FA  COLOR_$ASSOC
    sau5  0x00E72D12  COLOR_$ASSOC

  - The board's user page (page 16#39, protection 6) is installed in the
    caller's address space at color_user_va: with `vm_regions' in
    special segment 0, which is mapped first (nothing is done when that
    fails), otherwise as the private page 16#6000; va and cstore are
    that address and the control store's.
  - A board another process held is taken from it (COLOR_$DISSOC on its
    behalf), with `vm_regions' after the special segment is removed from
    that process's address space when it is another; the display is
    turned on.

  Status stored: none.
}

procedure color_$assoc(out va: univ_ptr; out cstore: univ_ptr);
%if vm_regions %then
var
  special_va: univ_ptr;
  status: status_$t;
begin
  special_va := mst_$map_special(0, 1, special_seg_$uid, proc1_$as_id,
                                 status);
  if status.all = status_$ok then begin
    mmu_$install_special(16#39, special_va, proc1_$as_id, 6);
    va := univ_ptr(color_user_va);
    cstore := addr(color_cstore);
    color_associated := true;
    if color_owner <> 0 then
      if color_owner <> proc1_$current then begin
        if color_as_id <> 0 then
          if color_as_id <> proc1_$as_id then
            mmu_$remove_special_seg(special_va, color_as_id, 0);
        color_owner := proc1_$current;
        color_$dissoc;
        color_page_count := 0;
      end;
    color_as_id := proc1_$as_id;
    color_owner := proc1_$current;
    color_sup.command := color_cmd_display_on;
  end;
end;
%else
begin
  mmu_$install_private(16#39, univ_ptr(color_user_va), proc1_$as_id, 6);
  va := univ_ptr(color_user_va);
  cstore := addr(color_cstore);
  color_associated := true;
  if color_owner <> 0 then
    if color_owner <> proc1_$current then begin
      color_owner := proc1_$current;
      color_$dissoc;
      color_page_count := 0;
    end;
  color_owner := proc1_$current;
  color_sup.command := color_cmd_display_on;
end;
%endif
