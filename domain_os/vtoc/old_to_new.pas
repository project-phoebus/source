{ VTOCE_$OLD_TO_NEW - convert an old-format VTOCE into the new format.

  Image addresses:
    sau2  0x00E19DB8  VTOCE_$OLD_TO_NEW

  - The header's bits 9 and 8 go to the flag byte at +0x65, the UID is
    copied, the rest cleared and filled from the old entry: the times,
    the lengths, the link count plus one (at most 65525), nil owners,
    the ACL cell, the parent UID with member 24 set.

  Status stored: none.
}

{ TODO(pascal) VTOCE_$OLD_TO_NEW's 12-byte ACL cell copied from a constant in the code

  The image fills unknown_68 by a block copy from 12 bytes that follow
  the routine's code, three longwords of 16#0C: a 12-byte constant of
  the field's type assigned to it.  As with FLP_$DINIT's label record
  (the TODO(pascal) in flp/dinit.pas), the reference has no structured
  constant for it, and a `static' variable would be in the data
  section; the Pascal assigns the three longwords (the same values;
  three stores, not a copy from the code). }

[section(wired_proc, wired_data)]
procedure vtoce_$old_to_new(in old_vtoce: univ vtoce_$old_fm_t;
                            out new_vtoce: univ vtoce_$t);
var
  i: integer;                             { the loops' index }
begin
  new_vtoce.hdr.all := 0;
  new_vtoce.hdr.type_mode := old_vtoce.hdr.type_mode;
  new_vtoce.hdr.flags := old_vtoce.hdr.flags;

  { the header's bits, the old bit 8 twice }
  new_vtoce.hdr.in_use := old_vtoce.hdr.in_use;
  new_vtoce.hdr.mode_14_13 := old_vtoce.hdr.mode_14_13;
  new_vtoce.hdr.bit_12 := old_vtoce.hdr.bit_12;
  new_vtoce.hdr.bit_11 := old_vtoce.hdr.bit_11;
  new_vtoce.hdr.bit_10 := old_vtoce.hdr.bit_10;
  new_vtoce.ext.ext_5 := old_vtoce.hdr.bit_8;
  new_vtoce.ext.ext_4 := old_vtoce.hdr.bit_8;

  { the UID's 16 bytes }
  for i := 1 to 16 do
    new_vtoce.id.bytes[i] := old_vtoce.id.bytes[i];

  { the rest of the entry }
  for i := 5 to 35 do
    new_vtoce.longs[i] := 0;

  { the times and the lengths }
  new_vtoce.dtm := old_vtoce.dtm;
  new_vtoce.dtu.high := old_vtoce.unknown_28;
  new_vtoce.dtu.low := old_vtoce.unknown_34;
  new_vtoce.unused_24 := old_vtoce.unknown_24;
  new_vtoce.dta := new_vtoce.dtu;
  new_vtoce.dtc := new_vtoce.dtu;
  new_vtoce.lengths := old_vtoce.lengths;
  new_vtoce.acl_checksum := old_vtoce.dtu;

  { the link count, at most 16#FFF5 }
  new_vtoce.link_count := old_vtoce.link_count + 1;
  if new_vtoce.link_count >= 65525 then
    new_vtoce.link_count := 65525;

  { the nil owner, group and organization }
  new_vtoce.owner_uid := ppo_$nil_user_uid;
  new_vtoce.group_uid := rgyc_$g_nil_uid;
  new_vtoce.org_uid := ppo_$nil_org_uid;

  { the constant cell (see the TODO) }
  new_vtoce.unknown_68[1] := 16#0C;
  new_vtoce.unknown_68[2] := 16#0C;
  new_vtoce.unknown_68[3] := 16#0C;

  new_vtoce.acl_mode[1] := 16#10;
  new_vtoce.acl_mode[2] := 16#10;
  new_vtoce.acl_mode[3] := 16#10;
  new_vtoce.acl_mode[4] := 0;

  { the parent, member 24 of its low longword }
  new_vtoce.parent_uid.uid := old_vtoce.parent_uid.uid;
  new_vtoce.parent_uid.low_bits := new_vtoce.parent_uid.low_bits + [24];

  new_vtoce.ext.ext_7 := old_vtoce.hdr.bit_9;
end;
