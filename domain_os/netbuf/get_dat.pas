{ NETBUF_$GET_DAT - take a data page, waiting or allocating one.

  Image addresses:
    sau2  0x00E0EFA4  NETBUF_$GET_DAT

  - As NETBUF_$GET_HDR: the network process (type 7) waits and retries;
    any other gets a new page from WP_$CALLOC (a bad status crashes the
    system), counted, and its address returned.

  Status stored: none.
}

procedure netbuf_$get_dat(out addr: integer32);
var
  ppn: integer32;
  status: status_$t;
begin
  repeat
    if netbuf_$get_dat_cond(addr) then return;
    if proc1_$type[proc1_$pcb_ptr_t(proc1_$current_pcb)^.mypid] <> 7 then
      exit;
    time_$wait(time_$relative, netbuf_$delay_time, status);
    if status.all <> status_$ok then
      crash_system(status);
    netbuf_$dat_delays := netbuf_$dat_delays + 1;
  until false;

  wp_$calloc(ppn, status);
  if status.all <> status_$ok then
    crash_system(status);
  netbuf_$dat_allocs := netbuf_$dat_allocs + 1;
  addr := lshft(ppn, 10);
end;
