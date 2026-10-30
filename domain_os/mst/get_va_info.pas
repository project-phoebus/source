{ MST_$GET_VA_INFO - the object mapped at an address, with its
  protection and flags.

  Image addresses:
    sau2  0x00E4404E  MST_$GET_VA_INFO
    sau9  0x3C44B61A  MST_$GET_VA_INFO

  - The address's MSTE is copied out under the ASID lock; its UID, the
    address's offset in the object, the protection and the flag word's
    bits 15 and 14 are returned.

  Status stored:
    status_$ok: the MSTE was found
    status_$reference_to_illegal_address: an ASID past the last
    mst_$va_to_pte's status: no MSTE for the address
}

procedure mst_$get_va_info(in asid: integer;
                           in va: integer32;
                           out uid: uid_$t;
                           out va_info: integer32;
                           out prot: univ pinteger;
                           out active: boolean;
                           out modified: boolean;
                           out status: status_$t);
var
  entry_copy: mst_entry_t;
  lookup_status: status_$t;
  entry: mst_entry_ptr_t;
  a: pinteger;
  v: integer32;
begin
  a := asid;
  v := va;
  if a > mst_max_asid then begin
    status.all := status_$reference_to_illegal_address;
    return;
  end;
  ml_$lock(ml_$mst_asid_lock);
  mst_$va_to_pte(a, v, prot, entry, lookup_status);
  if lookup_status.all = status_$ok then
    entry_copy := entry^;
  ml_$unlock(ml_$mst_asid_lock);
  status := lookup_status;
  if status.all <> status_$ok then return;
  uid := entry_copy.uid;
  va_info := (v & 16#7FFF)
             + lshft(integer32(entry_copy.area_id), 15);
  active := 15 in entry_copy.flags.bits;
  modified := 14 in entry_copy.flags.bits;
end;
