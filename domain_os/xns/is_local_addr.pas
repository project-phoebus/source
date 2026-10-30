{ xns_$is_local_addr - whether an XNS address's host is the broadcast
  host.

  Image addresses:
    sau2  0x00E17850  xns_$is_local_addr

  - True when the host's three words are all 16#FFFF: despite its name,
    the routine tests for the broadcast host.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of xns_$is_local_addr no object explains

  The SAU2 frame holds the reserved slot of an `internal' routine and
  the boolean result variable's word (held in D0), and 4 bytes more, held
  by the stand-in unused_8 (the result below it).
  Every XNS module-local function has 4 such bytes:
  xns_$pkt_bufs_in_netbuf_pool (xns/pkt_bufs_in_netbuf_pool.pas),
  xns_$find_socket and xns_$is_broadcast_addr (xns/find_socket.pas,
  xns/is_broadcast_addr.pas), xns_$get_checksum likewise less
  certainly; a rule for internal functions' frames (a 4-byte result
  slot? a temporary?) would explain them all. }

function xns_$is_local_addr(in addr: xns_$addr_t): boolean; internal;
var
  unused_8: integer32;                    { stand-in }
begin
  xns_$is_local_addr := false;
  if (addr.host[2] = 16#FFFF) and then (addr.host[0] = 16#FFFF)
     and then (addr.host[1] = 16#FFFF) then
    xns_$is_local_addr := true;
end;
