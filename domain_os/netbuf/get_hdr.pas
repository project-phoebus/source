{ NETBUF_$GET_HDR - take a header page, waiting or allocating one.

  Image addresses:
    sau2  0x00E0EDD6  NETBUF_$GET_HDR
    sau9  0x3C411228  NETBUF_$GET_HDR

  - While NETBUF_$GET_HDR_COND finds none, the network process (type 7)
    waits netbuf_$delay_time, counting the delay, and retries.
  - Any other process gets a new page from WP_$CALLOC and NETBUF_$GETVA
    (a bad status crashes the system), counted, made uncached with
    `netbuf_cache_inhibit', cleared, its physical address stored.

  Status stored: none.
}

procedure netbuf_$get_hdr(out phys: integer32; out va: integer32);
var
  ppn: integer32;
  status: status_$t;
  i: integer;
begin
  repeat
    if netbuf_$get_hdr_cond(phys, va) then return;
    if proc1_$type[proc1_$pcb_ptr_t(proc1_$current_pcb)^.mypid] <> 7 then
      exit;
    time_$wait(time_$relative, netbuf_$delay_time, status);
    if status.all <> status_$ok then
      crash_system(status);
    netbuf_$hdr_delays := netbuf_$hdr_delays + 1;
  until false;

  wp_$calloc(ppn, status);
  phys := lshft(ppn, 10);
  if status.all = status_$ok then
    netbuf_$getva(lshft(ppn, 10), va, status);
  if status.all <> status_$ok then
    crash_system(status);

  netbuf_$hdr_allocs := netbuf_$hdr_allocs + 1;
%if netbuf_cache_inhibit %then
  mmu_$cache_inhibit_va(univ_ptr(va));
%endif
  for i := 1 to 4 do
    netbuf_$hdr_page_ptr_t(va)^.data_ptrs[i] := 0;
  netbuf_$hdr_page_ptr_t(va)^.phys := phys;
end;
