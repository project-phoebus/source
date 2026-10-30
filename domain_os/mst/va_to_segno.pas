{ MST_$VA_TO_SEGNO - the MST word index of a virtual address.

  Image addresses:
    sau2  0x00E0DCC8  MST_$VA_TO_SEGNO
    sau9  0x3C40FDA8  MST_$VA_TO_SEGNO

  - The segment number (the address shifted right 15) is placed in one
    of the address space's four regions and made its MST word's index.
  - The result is an ASID: the caller's default for a private segment,
    0 for a global one, mst_asid_none (58) for the gap between global A
    and B (no index stored then).

  Status stored: none.
}

function mst_$va_to_segno(virtual_addr: integer32; out segno_out: pinteger;
                          default_result: pinteger): pinteger;
var
  segno: linteger;
  seg: pinteger;
  index: pinteger;
begin
  segno := rshft(virtual_addr, 15);
  if segno >= mst_$seg_mem_top then begin
    mst_$va_to_segno := 0;
    return;
  end;
  seg := segno;
  index := seg;
  if index < mst_$private_a_size then begin
    segno_out := index;
    mst_$va_to_segno := default_result;
    return;
  end;
  index := seg - mst_$seg_private_b;
  if index < mst_private_b_count then begin
    segno_out := index + mst_$private_a_size;
    mst_$va_to_segno := default_result;
    return;
  end;
  index := seg - mst_$seg_global_a;
  if index < mst_$global_a_size then
    segno_out := index
  else if seg < mst_$seg_global_b then begin
    mst_$va_to_segno := mst_asid_none;
    return;
  end
  else
    segno_out := seg - mst_$seg_global_b
                 + mst_$global_a_size;
  mst_$va_to_segno := 0;
end;
