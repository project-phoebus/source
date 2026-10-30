{ MST_$ALLOC_ASID - allocate an address space.

  Image addresses:
    sau2  0x00E42D3A  MST_$ALLOC_ASID
    sau9  0x3C44A0C6  MST_$ALLOC_ASID

  - Under the ASID lock the first ASID not in MST_$ASID_LIST is taken
    and the first MST word of its run backed with a page of MSTEs.
  - That page's first MSTE is made the OS wired segment's (left alone
    if it names OS_WIRED_$UID, filled if free).  The result is the
    ASID, or 0 on failure.
  - With the large address space no MSTE page is taken: an ASID other
    than 1 gets a RARS page, a copy of ASID 0's, and the global regions
    (the first two statuses only).

  Status stored:
    status_$ok: allocated
    status_$no_asid_available: none free
    status_$mst_no_space_available: the first MSTE names another object
    status_$virtual_memory_resources_exhausted: no page for the MSTEs
}

function mst_$alloc_asid(out status: status_$t): integer;
label
  found, done;
var
  st: status_$t;
  asid: 0..mst_max_asid;
%if large_address_space %then
  i: integer;
%else
  base: pinteger;
%endif
begin
  ml_$lock(ml_$mst_asid_lock);
  for asid := 0 to mst_max_asid do
    if not (asid in mst_$asid_list) then
      goto found;
  st.all := status_$no_asid_available;
  goto done;
found:
  mst_$set(mst_$asid_list, mst_asid_none, asid);
%if large_address_space %then
  { the ASID's RARS page, a copy of ASID 0's (ASID 1's is MST_$INIT's),
    and the global regions active }
  if asid <> 1 then begin
    mmu_$rars_phaddr[asid] := mst_$init_table_page(
      linteger(addr(rars[rars_asid_base[asid]]))) * 1024;
    for i := 0 to 255 do
      rars[rars_asid_base[asid] + i] := rars[rars_asid_base[0] + i];
    mst_$regions_active[asid] := mst_$regions_active[asid] +
                                 mst_global_regions;
  end;
  st.all := status_$ok;
%else
  base := mst_asid_base[asid];
  st := mst_$alloc_table_page(asid, 0, mst[base]);
  if st.all = status_$ok then begin
    with mste_pages[mst[base]][0] do begin
      if uid <> os_wired_$uid then begin
        if uid_high <> 0 then begin
          st.all := status_$mst_no_space_available;
          goto done;
        end;
        uid := os_wired_$uid;
        area_id := 0;
        flags.bits := flags.bits * [9..13];
      end;
    end;
    st.all := status_$ok;
  end;
%endif
done:
  ml_$unlock(ml_$mst_asid_lock);
  status := st;
  if status.all = status_$ok then
    mst_$alloc_asid := asid
  else
    mst_$alloc_asid := 0;
end;

{ TODO(pascal) MST_$ALLOC_ASID's frame

  st and 12 bytes below it that no instruction reaches (the
  register-held locals' homes) are still to be matched with stand-ins
  against dpc's layout; its code differs from the image's in the
  registers.  With the large address space the image reads
  rars_asid_base[0] once before the copy and adds the global regions
  from a constant set in the code, where dpc
  sets each member in place. }
