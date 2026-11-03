{ mst_$va_to_pte - the MSTE of an address in an address space.

  Image addresses:
    sau2  0x00E4411C  mst_$va_to_pte (module-local)
    sau8  0x03C4C552  mst_$va_to_pte (module-local)
    sau9  0x3C44B6E8  mst_$va_to_pte (module-local)

  - MST_$VA_TO_SEGNO gives the address's table and segment; the MST word
    of its group of 64 names a page of MSTEs, and the entry is that
    page's (segment & 63)th.  The entry and its protection are returned.
  - With the large VM layout the protection is read back from the
    segment's segment map entry, as mst_$set_mstes stored it.

  Status stored:
    status_$ok: found
    status_$reference_to_illegal_address: an unknown table, an empty
      MST word, or an entry with no object (the pointer then cleared)
}

procedure mst_$va_to_pte;
label
  illegal;
var
  e: mst_entry_ptr_t;
  segno: pinteger;
  dir_index: integer;
  local_seg: pinteger;
%if large_vm %then
  smap: ^mst_smap_t;
  prot_bits: mst_prot_bits_t;
%endif
begin
  segno := mst_$va_to_segno(va, local_seg, asid);
  if segno > mst_max_asid then goto illegal;
  dir_index := (local_seg div 64) + mst_asid_base[segno];
  if mst[dir_index] = 0 then begin
  illegal:
    status.all := status_$reference_to_illegal_address;
  end
  else begin
    e := addr(mste_pages[mst[dir_index]][local_seg & 16#3F]);
    entry := e;
    if e^.uid.high = 0 then begin
      status.all := status_$reference_to_illegal_address;
      entry := nil;
    end
    else begin
%if large_vm %then
      smap := addr(smaps[local_seg + smap_asid_base[segno]]);
      prot_bits := [1];
      if 0 in smap^.table_bits then prot_bits := prot_bits + [0];
      if 3 in smap^.table_bits then prot_bits := prot_bits + [3];
      if 8 in smap^.flags then prot_bits := prot_bits + [4];
      if not (2 in smap^.flags) then prot_bits := prot_bits + [2];
      prot := pinteger(prot_bits);
%else
      prot := e^.flags.prot;
%endif
      status.all := status_$ok;
    end;
  end;
end;
