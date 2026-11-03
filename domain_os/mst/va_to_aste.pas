{ mst_$va_to_aste - activate and wire the segment of a virtual address.

  Image addresses:
    sau8  0x03C0F31C  mst_$va_to_aste (module-local)
    sau9  0x3C4103F8  mst_$va_to_aste (module-local)

  - The address's MST entry is activated (AST_$MSTE_ACTIVATE_AND_WIRE,
    under the AST lock); the address space's segment map entry is made
    to point at the segment's page map, as MST_$TOUCH does.
  - The result is the wired ASTE, nil when the address has no entry or
    the activation failed; page is the address's page in its segment.

  Status stored:
    status_$reference_to_illegal_address: no ASID or MST entry
    AST_$MSTE_ACTIVATE_AND_WIRE's status: otherwise
}

function mst_$va_to_aste(va: integer32; out page: integer;
                         out status: status_$t): ast_$aste_ptr_t;
  internal;
var
  asid: pinteger;
  seg_index: pinteger;
  entry: ^mst_entry_t;
  aste: ast_$aste_ptr_t;
begin
  asid := mst_$va_to_segno(va, seg_index, proc1_$as_id);
  if (asid > mst_max_asid) or else
     (mst[(seg_index div 64) + mst_asid_base[asid]] = 0) then begin
    status.all := status_$reference_to_illegal_address;
    mst_$va_to_aste := nil;
    return;
  end;
  entry := addr(mste_pages[mst[(seg_index div 64) + mst_asid_base[asid]]]
                          [seg_index & 16#3F]);
  ml_$lock(ml_$ast_lock);
  aste := ast_$mste_activate_and_wire(entry^.as_ast, status);
  if aste <> nil then begin
    ml_$lock(ml_$pmap_lock);
    with smaps[seg_index + smap_asid_base[asid]] do
      if ctl.dt = mst_smap_invalid then begin
        table := (table & 15) + aste^.pmap_pa;
        lim.limit := 31;
        if asid = 0 then flags := flags + [9];
%if not smap_shared_global %then
        { the bit set for a global segment is cleared at once, as in
          MST_$TOUCH }
        flags := flags - [9];
        flags := flags + [10..15];
%endif
        ctl.dt := mst_smap_valid;
        bst[seg_index + bst_asid_base[asid]] :=
          mst_$pmap_link_t(aste^.pmap_link);
        aste^.pmap_link.asid := asid;
        aste^.pmap_link.seg := seg_index;
      end;
    ml_$unlock(ml_$pmap_lock);
    page := rshft(va & 16#7FFF, 10);
  end;
  ml_$unlock(ml_$ast_lock);
  mst_$va_to_aste := aste;
end;
