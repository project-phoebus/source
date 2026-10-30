{ GET_CHKSUM - the checksum of a page given by its physical address.

  Image addresses:
    sau2  0x00E0F312  GET_CHKSUM
    sau9  0x3C41176E  GET_CHKSUM

  - The page is mapped into the network buffer window (a failure
    crashes the system), summed with NETWORK_$GET_CHKSUM and unmapped,
    and its frame's referenced bit cleared with MMU_$CLR_USED (with
    `pft_mmu'; elsewhere the bit is the page table's, not cleared here).
  - A map symbol without `$'.

  Status stored: none.
}

function get_chksum(in pa: integer32; in len: integer): integer32;
var
  va: univ_ptr;
  status: status_$t;
  sum: integer32;
begin
  { map the page }
  netbuf_$getva(pa, va, status);
  if status.all <> status_$ok then
    crash_system(status);

  { sum it, unmap it, clear its frame's bit }
  sum := network_$get_chksum(va);
  discard(netbuf_$rtnva(va));
%if pft_mmu %then
  mmu_$clr_used(rshft(pa, 10));
%endif
  get_chksum := sum;
end;
