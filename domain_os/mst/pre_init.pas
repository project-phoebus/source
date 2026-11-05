{ MST_$PRE_INIT - the segment layout and each ASID's run of MST words.

  Image addresses:
    sau2  0x00E309F4  MST_$PRE_INIT
    sau4  0x0F834060  MST_$PRE_INIT
    sau6  0x7803964C  MST_$PRE_INIT
    sau7  0x3C4395B8  MST_$PRE_INIT
    sau8  0x03C33A58  MST_$PRE_INIT
    sau9  0x3C436A34  MST_$PRE_INIT

  - On a 68020 the fourteen segment-layout words are replaced by the
    large address space's; with the layout chosen at boot, on a node
    with the MC68851 PMMU, by the PMMU layout's, with the region words.
  - Each ASID's base in the MST words is the ASID times (MST_$SEG_TN +
    63) div 64, one word per 64 segments.
  - With the large address space or the 8192 segments the layout is
    constants; each ASID's bases into BST, SMAPS and RARS are set too
    (RARS's a region register or root entry per region).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mst_$pre_init;
var
  asid: integer;
  words: integer;
  unused_8: integer32;                    { stand-in }
begin
%if large_address_space or vm_8192_segs or vm_65536_segs %then
  { the regions are constants: each ASID's bases into MST, BST, SMAPS
    and RARS }
  for asid := 0 to 57 do
    mst_asid_base[asid] := asid * ((mst_$seg_tn + 63) div 64);
  for asid := 0 to 57 do
    bst_asid_base[asid] := asid * mst_$seg_tn;
  for asid := 0 to 57 do
    smap_asid_base[asid] := asid * mst_$seg_tn;
  for asid := 0 to 57 do
    rars_asid_base[asid] := asid * mst_rars_asid_entries;
%elseif run_time_layout %then
  { the PMMU's layout in place of the default one }
  if mmu_$have_pmmu then begin
    mst_$seg_tn := 7424;
    mst_$global_a_size := 256;
    mst_$seg_global_a := 16#1CC0;
    mst_$seg_global_a_end := 16#1DBF;
    mst_$private_a_size := 7360;
    mst_$seg_private_a_end := 16#1CBF;
    mst_$seg_private_b := 16#1DC0;
    mst_$seg_private_b_end := 16#1DFF;
    mst_$seg_private_b_offset := 16#100;
    mst_$seg_global_b := 16#1E00;
    mst_$seg_global_b_offset := 16#1D00;
    mst_$seg_high := 16#1FF0;
    mst_$seg_mem_top := 16#2000;
    mst_$global_b_size := 512;
    special_$seg := 16#0EF80000;
    region_$tn := 128;
    region_$private_b := 16#77;
    region_$global_b_size := 8;
    region_$global_b := 16#78;
    region_$global_a_size := 4;
    region_$global_a := 16#73;
    region_$private_a_size := 115;
    region_$private_tn := 116;
  end;
  { each ASID's bases into MST, BST, SMAPS (a page's worth of BST links
    and of segment map entries rounded up) and RARS }
  words := (mst_$seg_tn + 64 - 1) div 64;
  for asid := 0 to 57 do
    mst_asid_base[asid] := asid * words;
  for asid := 0 to 57 do
    bst_asid_base[asid] := asid * ((mst_$seg_tn + 255) & ~255);
  for asid := 0 to 57 do
    smap_asid_base[asid] := asid * ((mst_$seg_tn + 127) & ~127);
  for asid := 0 to 57 do
    rars_asid_base[asid] := region_$tn * asid;
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
