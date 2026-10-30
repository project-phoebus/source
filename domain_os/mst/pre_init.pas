{ MST_$PRE_INIT - the segment layout and each ASID's run of MST words.

  Image addresses:
    sau2  0x00E309F4  MST_$PRE_INIT
    sau9  0x3C436A34  MST_$PRE_INIT

  - On a 68020 the fourteen segment-layout words are replaced by the
    large address space's.
  - Each ASID's base in the MST words is the ASID times (MST_$SEG_TN +
    63) div 64, one word per 64 segments.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mst_$pre_init;
var
  asid: integer;
  words: integer;
  unused_8: integer32;                    { stand-in }
begin
%if large_address_space %then
  { the regions are constants: each ASID's bases into MST, BST, SMAPS
    and RARS }
  for asid := 0 to 57 do
    mst_asid_base[asid] := asid * ((mst_$seg_tn + 63) div 64);
  for asid := 0 to 57 do
    bst_asid_base[asid] := asid * mst_$seg_tn;
  for asid := 0 to 57 do
    smap_asid_base[asid] := asid * mst_$seg_tn;
  for asid := 0 to 57 do
    rars_asid_base[asid] := asid * 256;
%else
  if m68020 then begin
    mst_$seg_tn := 1664;
    mst_$global_a_size := 224;
    mst_$seg_global_a := 16#678;
    mst_$seg_global_a_end := 16#757;
    mst_$private_a_size := 1656;
    mst_$seg_private_a_end := 16#677;
    mst_$seg_private_b := 16#758;
    mst_$seg_private_b_end := 16#75F;
    mst_$seg_private_b_offset := 16#E0;
    mst_$seg_global_b := 16#760;
    mst_$seg_global_b_offset := 16#680;
    mst_$seg_high := 16#7E0;
    mst_$seg_mem_top := 16#800;
    mst_$global_b_size := 160;
  end;
  words := (mst_$seg_tn + 63) div 64;
  for asid := 0 to 57 do
    mst_asid_base[asid] := asid * words;
%endif
end;

{ TODO(pascal) MST_$PRE_INIT's frame: 4 bytes nothing addresses

  The image's frame has room for two words and four bytes more; what
  the original kept in the four is not seen.  unused_8 holds them. }
