{ MST_$BST_TO_VA - the virtual address at which a page map is mapped.

  Image addresses:
    sau8  0x03C0F284  MST_$BST_TO_VA
    sau9  0x3C41035C  MST_$BST_TO_VA

  - The page map's thread is searched for an entry of the address space
    asid, or of a global segment (ASID 0); its segment index becomes the
    segment's number and its address.
  - The result: true when va and found_asid were set.

  Status stored: none.
}

function mst_$bst_to_va(link: univ mst_$pmap_link_t; asid: integer;
                        out va: integer32; out found_asid: integer):
  boolean;
  options(val_param);
var
  p: ^mst_$pmap_link_t;
  owner: integer;
  segno: pinteger;
begin
  p := addr(link);
  while p^.asid <> -1 do begin
    owner := p^.asid;
    if (owner = asid) or else (owner = 0) then begin
      if owner = 0 then begin
        { global A, then global B }
        if p^.seg >= mst_$global_a_size then
          segno := p^.seg - mst_$global_a_size + mst_$seg_global_b
        else
          segno := p^.seg + mst_$seg_global_a;
      end
      else begin
        { private A, then private B }
        if p^.seg >= mst_$private_a_size then
          segno := p^.seg - mst_$private_a_size + mst_$seg_private_b
        else
          segno := p^.seg;
      end;
      va := lshft(integer32(segno), 15);
      found_asid := owner;
      mst_$bst_to_va := true;
      return;
    end;
    p := addr(bst[p^.seg + bst_asid_base[owner]]);
  end;
  mst_$bst_to_va := false;
end;
