{ os_$free_gap_pmaps - give back the page maps of an unused range of global
  B.

  Image addresses:
    sau6  0x7803CCB0  os_$free_gap_pmaps (module-local)
    sau7  0x3C43CD44  os_$free_gap_pmaps (module-local)
    sau9  0x3C439D7C  os_$free_gap_pmaps (module-local)

  - low and high are the range's addresses; its segments are those wholly
    inside it, numbered from global B's first.
  - With invalidate, the segments' entries in ASID 0's segment map are
    made invalid first: their descriptor type, or with `vm_65536_segs'
    (4-byte entries) their valid bit.
  - The pages of OS_PMAPS that hold only those segments' page maps are
    freed.

  Status stored: none.
}

{ TODO(pascal) first, last and s are a non-negative subrange in the image

  The SAU9 image guards the `for' with a signed compare of the two
  words and zero-extends them as indices, the forms of a non-negative
  16-bit subrange (as 0..2047, global B's segments); pinteger (0..65535)
  gives the unsigned guard.  dpc does not yet take a word index of such a
  subrange into OS_PMAPS (an array whose bounds times its element size
  do not fit in 16 bits), so the declarations stay pinteger until it
  does. }

[section(os_init_proc, os_init_data)]
procedure os_$free_gap_pmaps(low: integer32; high: integer32;
                             invalidate: boolean);
  internal;
var
  first: pinteger;
  last: pinteger;
  s: pinteger;
  page: linteger;
  last_page: linteger;
begin
  first := rshft(low + 16#7FFF, 15) - mst_$seg_global_b;
  last := rshft(high - 16#8000, 15) - mst_$seg_global_b;

  { the segment map entries, after global A's in ASID 0's map }
  if invalidate then
    for s := first to last do
%if large_address_space %then
      smaps[smap_asid_base[0] + mst_$global_a_size + s].ctl.dt :=
        mst_smap_invalid;
%else
      smaps[smap_asid_base[0] + mst_$global_a_size + s].e.valid := false;
%endif

  { the whole pages of the range's page maps }
  page := linteger((integer32(addr(os_pmaps[first])) + 16#3FF) & (-16#400));
  last_page := linteger((integer32(addr(os_pmaps[last])) + 128 - 1024) &
                        (-16#400));
  while page <= last_page do begin
    os_$free_va_page(integer32(page));
    page := page + 1024;
  end;
end;
