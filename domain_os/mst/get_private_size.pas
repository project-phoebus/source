{ MST_$GET_PRIVATE_SIZE - the sizes of an address space's mapped private
  segments.

  Image addresses:
    sau2  0x00E44AAE  MST_$GET_PRIVATE_SIZE
    sau4  0x0F84CF16  MST_$GET_PRIVATE_SIZE
    sau6  0x7804C228  MST_$GET_PRIVATE_SIZE
    sau7  0x3C45501C  MST_$GET_PRIVATE_SIZE
    sau8  0x03C4D0AC  MST_$GET_PRIVATE_SIZE
    sau9  0x3C44C21C  MST_$GET_PRIVATE_SIZE

  - Under the ASID lock the address space's private A MST words are
    walked; the entries with an object and without the skip bit are
    counted, and of those the read-write ones (protection 3).
  - With the large VM layout protection 3 is read back from the
    segment map entry: the two bits mst_$set_mstes sets for it, or with
    the region registers the entry's protection field.
  - The sizes are the counts times 32 (pages).

  Status stored:
    status_$ok: the sizes were returned
    status_$reference_to_illegal_address: an ASID past the last
}

procedure mst_$get_private_size(in asid: pinteger;
                                out size_ret: integer32;
                                out rw_size_ret: integer32;
                                out status_ret: status_$t);
const
  { private A's MST words }
%if large_address_space or vm_8192_segs or vm_65536_segs %then
  private_a_words = mst_$private_a_size div 64;
%elseif run_time_layout %then
  private_a_words = 25;
%else
  private_a_words = 4;
%endif
var
  count: integer32;
  rw_count: integer32;
  base: pinteger;
  slot: pinteger;
  i: integer;
  unused_18: array[1..5] of integer;      { stand-in }
  end_slot: linteger;
%if large_vm %then
  seg: pinteger;
  smap: ^mst_smap_t;
%endif
begin
  if asid > mst_max_asid then begin
    status_ret.all := status_$reference_to_illegal_address;
    return;
  end;
  count := 0;
  base := mst_asid_base[asid];
  rw_count := 0;
%if large_vm %then
  seg := 0;
%endif
  slot := base;
  ml_$lock(ml_$mst_asid_lock);
  end_slot := linteger(base) + private_a_words;
  while linteger(slot) < end_slot do begin
    if mst[slot] <> 0 then begin
      for i := 0 to 63 do begin
        with mste_pages[mst[slot]][i] do
          if (uid.high <> 0) and then
             not (14 in flags.bits) then begin
            count := count + 1;
%if large_vm %then
            smap := addr(smaps[seg + smap_asid_base[asid]]);
%if region_mmu %then
            if (smap^.e.prot & 7) = 3 then
              rw_count := rw_count + 1;
%else
            if (0 in smap^.table_bits) and then (2 in smap^.flags) then
              rw_count := rw_count + 1;
%endif
%else
            if (flags.prot & 7) = 3 then
              rw_count := rw_count + 1;
%endif
          end;
%if large_vm %then
        seg := seg + 1;
%endif
      end;
    end
%if large_vm %then
    else
      seg := seg + 64
%endif
    ;
    slot := slot + 1;
  end;
  ml_$unlock(ml_$mst_asid_lock);
  size_ret := lshft(count, 5);
  rw_size_ret := lshft(rw_count, 5);
  status_ret.all := status_$ok;
end;

{ TODO(pascal) MST_$GET_PRIVATE_SIZE: the image keeps end_slot in its
  frame slot across the loop (dpc a register) and steps the MST word's
  address with slot; dpc's frame is 4 bytes larger.  The stand-in
  unused_18 fills the homes between the register-held locals and
  end_slot. }
