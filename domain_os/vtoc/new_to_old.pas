{ VTOCE_$NEW_TO_OLD - convert a new-format VTOCE into the old format.

  Image addresses:
    sau2  0x00E384C4  VTOCE_$NEW_TO_OLD

  - Field by field: the flag bit back into the header's bit 9, the UID,
    the parent (with flags set, the object's own UID with member 27),
    the times and lengths, the link count less one (65534 for 65525 and
    above), the checksum.

  Status stored: none.
}

procedure vtoce_$new_to_old(in new_vtoce: univ vtoce_$t; in flags: boolean;
                            out old_vtoce: univ vtoce_$old_fm_t);
var
  i: integer;                             { the loop }
begin
  { the header }
  old_vtoce.hdr := new_vtoce.hdr;
  old_vtoce.hdr.bit_9 := new_vtoce.ext.ext_7;
  old_vtoce.hdr.low_byte := 0;

  { the UID's 16 bytes }
  for i := 1 to 16 do
    old_vtoce.id.bytes[i] := new_vtoce.id.bytes[i];

  { the parent field }
  if flags then begin
    old_vtoce.parent_uid.uid := new_vtoce.id.uid;
    old_vtoce.parent_uid.low_bits := old_vtoce.parent_uid.low_bits + [27];
  end
  else begin
    old_vtoce.parent_uid.uid := new_vtoce.parent_uid.uid;
    old_vtoce.parent_uid.low_bits :=
      old_vtoce.parent_uid.low_bits - [24..27];
  end;

  { the times and the lengths }
  old_vtoce.dtm := new_vtoce.dtm;
  old_vtoce.unknown_24 := new_vtoce.unused_24;
  old_vtoce.unknown_28 := new_vtoce.dtu.high;
  old_vtoce.unknown_34 := new_vtoce.dtu.low;
  old_vtoce.lengths := new_vtoce.lengths;

  { the link count, 16#FFFE at the top }
  if new_vtoce.link_count >= 65525 then
    old_vtoce.link_count := 65534
  else
    old_vtoce.link_count := new_vtoce.link_count - 1;

  old_vtoce.dtu := new_vtoce.acl_checksum;
  old_vtoce.reserved_3c := 0;
end;
