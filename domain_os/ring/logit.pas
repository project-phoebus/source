{ RINGLOG_$LOGIT - record a packet in the ring log.

  Image addresses:
    sau2  0x00E1A20C  RINGLOG_$LOGIT
    sau8  0x03C1B3D0  RINGLOG_$LOGIT

  - A packet passes the node filter when the filter is 0 or names its
    destination or source, and each socket filter unless it is off.
  - The next entry is claimed under the log's spin lock, the index
    wrapping after 99; the result is its index, or -1 for a packet
    filtered out.
  - The node merges store 24-bit and 32-bit values into the 20-bit node
    fields unmasked; each later merge clears the bits that spilled, so
    the entry keeps each node's low 20 bits.

  Status stored: none.
}

function ringlog_$logit(in inbound: boolean; in hdr: univ pkt_$hdr_t):
  integer;
var
  token: pinteger;
  kind: integer;
  sock: integer;
  idx: integer;
  first: integer;
  i: integer;
begin
  ringlog_$logit := -1;
  if (ringlog_$id <> 0)
     and then (ringlog_$id <> hdr.dest_node)
     and then (ringlog_$id <> hdr.src_node) then
    return;

  { the socket }
  kind := hdr.routing_type;
  if kind = 1 then
    sock := hdr.src_sock
  else
    sock := hdr.src.sock;
  if sock > 11 then
    if kind = 1 then
      sock := hdr.route[hdr.route_count + 1]
    else
      sock := hdr.dest.sock;

  { the socket filters }
  if not ringlog_$nil_sock and then (sock = -1) then
    return;
  if not ringlog_$who_sock and then (sock = 5) then
    return;
  if not ringlog_$mbx_sock and then (sock = 9) then
    return;

  { claim an entry }
  token := ml_$spin_lock(ringlog_$spinlock);
  if ringlog_$first_entry then
    ringlog_$data.index := 0;
  ringlog_$first_entry := false;
  idx := ringlog_$data.index;
  ringlog_$data.index := ringlog_$data.index + 1;
  if ringlog_$data.index > 99 then
    ringlog_$data.index := 0;
  ml_$spin_unlock(ringlog_$spinlock, token);
  ringlog_$logit := idx;

  with ringlog_$data.entries[idx] do begin
    nodes.inbound := inbound;
    nodes.valid := true;
    nodes.send := kind = 1;
    nodes.node_c := hdr.dest_node;
    pkt_type := hdr.request_id;
    first := (hdr.hdr_size + 16#1E) div 2 + 1;
    for i := 0 to 12 do
      pkt_words[i] := ringlog_$hdr_words_ptr_t(addr(hdr))^[first + i];

    if not nodes.send then begin
      nodes.node_b := hdr.dest.node;
      nodes.node_a := hdr.src.node;
      sock_byte_03 := hdr.dest.sock;
      sock_byte_02 := hdr.src.sock;
      field_10 := hdr.dest.net;
      field_0c := hdr.src.net;
    end
    else begin
      field_0c := 0;
      field_10 := 0;
      nodes.node_b := hdr.dest_node;
      nodes.node_a := hdr.src_node;
      sock_byte_02 := hdr.src_sock;
      sock_byte_03 := hdr.route[hdr.route_count + 1];
    end;
  end;
end;
