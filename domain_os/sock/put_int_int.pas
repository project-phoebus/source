{ SOCK_$PUT_INT_INT - append a packet to a socket's queue.

  Image addresses:
    sau2  0x00E161F8  SOCK_$PUT_INT_INT

  - Under the socket lock.  The packet's record goes into the queue
    fields of its header's page (the header's address with its low ten
    bits cleared), and the page onto the queue; the data pages the
    payload reaches are kept, the others cleared.
  - The result is 0 when queued, 1 for a full queue, 2 for a socket not
    allocated, not open (with flags set), or a packet longer than its
    data length (compared unsigned).

  Status stored: none.
}

{ TODO(pascal) the open test is the flag word's sign, and 4 frame bytes

  The open test reads member 15 of the word loaded for the allocated
  test as the word's sign, which is neither known form (a bit test on
  the register for a word set's constant member, a byte test for a
  top-bit boolean field).  Read as `sock_flag_open in
  sock^.flags.members'.  The stand-in unused_14 holds 4 frame bytes
  nothing addresses.  Not settled. }

function sock_$put_int_int(sock: sock_$sock_ptr_t; in info: sock_$pkt_info_t;
                           flags: boolean; ec_param1: integer;
                           ec_param2: integer): integer;
var
  netbuf: netbuf_$hdr_page_ptr_t;
  result: integer;
  i: integer;
  token: pinteger;
  unused_14: integer32;                   { stand-in: TODO above }
begin
  token := ml_$spin_lock(sock_lock);

  if not (sock_flag_allocated in sock^.flags.members)
     or else (flags and then not (sock_flag_open in sock^.flags.members))
     or else (info.data_len > sock^.max_data_len) then
    result := 2
  else if sock^.queue_count >= sock^.max_queue then
    result := 1
  else begin
    { the page's queue fields }
    sock^.queue_count := sock^.queue_count + 1;
    netbuf := netbuf_$hdr_page_ptr_t(info.hdr & (-16#400));
    netbuf^.next := 0;
    netbuf^.src_addr := info.src_addr;
    netbuf^.src_port := info.src_port;
    netbuf^.dst_addr := info.dst_addr;
    netbuf^.dst_port := info.flags;
    netbuf^.data_len := info.data_len;
    netbuf^.hdr_len := info.hdr_len;
    netbuf^.ec_param1 := ec_param1;
    netbuf^.ec_param2 := ec_param2;
    netbuf^.hop_count := info.n_hops;
    netbuf^.hdr_ptr := info.hdr;
    for i := 0 to info.n_hops - 1 do
      netbuf^.hops[i] := info.hops[i];

    { the queue }
    if sock^.queue_tail = 0 then begin
      sock^.queue_head := integer32(netbuf);
      sock^.queue_tail := integer32(netbuf);
    end
    else begin
      netbuf_$hdr_page_ptr_t(sock^.queue_tail)^.next := integer32(netbuf);
      sock^.queue_tail := integer32(netbuf);
    end;

    { the data pages }
    for i := 1 to 4 do
      if info.data_len > (i - 1) * 1024 then
        netbuf^.data_ptrs[i] := info.data_pages[i]
      else
        netbuf^.data_ptrs[i] := 0;
    result := 0;
  end;

  ml_$spin_unlock(sock_lock, token);
  sock_$put_int_int := result;
end;
