{ mst_$set_mstes - fill the MSTEs of segments start_seg .. end_seg of an
  ASID: the first from the arguments, the rest copies of it, each with
  the next object segment.

  Image addresses:
    sau2  0x00E43E10  mst_$set_mstes (module-local)
    sau4  0x0F84BEE6  mst_$set_mstes (module-local)
    sau8  0x03C4C00C  mst_$set_mstes (module-local)
    sau9  0x3C44B1CA  mst_$set_mstes (module-local)

  - The first entry gets the UID, the object segment, the protection
    (with 2 or'd in), the wired flag, the location and the touch count
    less one; later segments get copies, the object segment counted up.
  - With the large VM layout the protection goes to the segment map
    entries instead (made invalid for MST_$TOUCH to fill); with the
    large address space each segment counts in MST_$SEGS_MAPPED.
  - The paging file's and the wired kernel's entries keep theirs.
  - With the region registers the segment map entry is made invalid
    and given the protection.
  - The cache is cleared at the end (not with
    `set_mstes_no_cache_clear').

  Status stored: none.
}

procedure mst_$set_mstes(in uid: uid_$t; obj_seg: pinteger;
                         location: integer32; start_seg: pinteger;
                         end_seg: pinteger; touch_count: integer;
                         asid: integer; prot: mst_prot_t;
                         wired: boolean);
var
  base: pinteger;
  last: pinteger;
  seg: pinteger;
  i: pinteger;
  dst: mst_entry_ptr_t;
  unused_1c: array[1..2] of integer32;    { stand-in: the image's frame
                                            (the TODO(pascal) below) }
%if large_vm %then
  keep_smaps: boolean;
  smap: ^mst_smap_t;
  prot_bits: mst_prot_bits_t;
%endif
begin
  prot := prot ! 2;
  base := mst_asid_base[asid];
  with mste_pages[mst[base + rshft(start_seg, 6)]]
                 [start_seg & 16#3F]: first do begin
    first.uid := uid;
    first.area_id := obj_seg;
%if large_vm %then
    first.flags.bits := [];
%else
    first.flags.active := false;
    first.flags.modified := false;
    first.flags.prot := prot;
    first.flags.aste_idx := 0;
%endif
    if wired then
      first.flags.active := true;
    first.location := location;
    first.page_info.n_pages_m1 := touch_count - 1;
    last := start_seg;
    seg := last + 1;
    while seg <= end_seg do begin
      last := seg + 64 - (seg & 16#3F) - 1;
      if end_seg < last then
        last := end_seg;
      dst := addr(mste_pages[mst[base + rshft(seg, 6)]]
                            [seg & 16#3F]);
      for i := seg to last do begin
        dst^ := first;
        obj_seg := obj_seg + 1;
        dst^.area_id := obj_seg;
        dst := mst_entry_ptr_t(integer32(dst) + 16);
      end;
      seg := last + 1;
    end;
  end;
%if vm_regions %then
  mst_$segs_mapped[asid][start_seg div mst_region_segs] :=
    mst_$segs_mapped[asid][start_seg div mst_region_segs] + 1;
%endif
%if large_vm %then
  keep_smaps := (uid = network_$paging_file_uid) or (uid = os_wired_$uid);
  smap := addr(smaps[smap_asid_base[asid] + start_seg]);
  if not keep_smaps then begin
%if region_mmu %then
    smap^.bits := smap^.bits - [31];
    smap^.e.prot := prot;
%else
    { the protection's bits 0 and 3 in the table address's low bits, bit
      4 as supervisor only, bit 2 clear as write protect }
    smap^.ctl.dt := mst_smap_invalid;
    prot_bits := mst_prot_bits_t(prot);
    if 0 in prot_bits then
      smap^.table_bits := smap^.table_bits + [0]
    else
      smap^.table_bits := smap^.table_bits - [0];
    if 3 in prot_bits then
      smap^.table_bits := smap^.table_bits + [3]
    else
      smap^.table_bits := smap^.table_bits - [3];
    if 4 in prot_bits then
      smap^.flags := smap^.flags + [8]
    else
      smap^.flags := smap^.flags - [8];
    if 2 in prot_bits then
      smap^.flags := smap^.flags - [2]
    else
      smap^.flags := smap^.flags + [2];
%endif
  end;
  for i := start_seg + 1 to end_seg do begin
%if vm_regions %then
    mst_$segs_mapped[asid][i div mst_region_segs] :=
      mst_$segs_mapped[asid][i div mst_region_segs] + 1;
%endif
    if not keep_smaps then
      smaps[i + smap_asid_base[asid]] := smap^;
  end;
%endif
%if not set_mstes_no_cache_clear %then
  cache_$clear;
%endif
end;

{ TODO(pascal) mst_$set_mstes's frame: the image's frame is all
  unaddressed; dpc's homes for the five register-held locals take 20
  bytes, and an 8-byte stand-in makes up the rest.  The SAU9 image's
  frame is 16 bytes larger and holds the protection, prot_bits and two
  values of start_seg, which dpc keeps in registers. }
