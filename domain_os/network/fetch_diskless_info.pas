{ network_$fetch_diskless_info - ask another node for boot-time information.

  Image addresses:
    sau2  0x00E3366C  network_$fetch_diskless_info (module-local)
    sau3  0x00E31AB4  network_$fetch_diskless_info (module-local)
    sau8  0x03C36EB8  network_$fetch_diskless_info

  - A fragment of the OS module (os/os.pas), the first routine of its
    OS_INIT_PROC segment.
  - One ASKNODE_$INTERNET_INFO request, its answer folded into local
    state: the clock for request 2, the timezone record for request 8,
    and a hint and a routing entry for request 16#37.
  - Any failure of a request other than 16#37 crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure network_$fetch_diskless_info(cmd: integer; node: linteger);
  internal;
type
  reply_t = record
    case integer of
      1: (raw: asknode_$reply_t);
      2: (word_00: integer32;             { 0x00 }
          status: status_$t;              { 0x04 }
          network: integer32;             { 0x08 }
          clockh: time_$clockh_t);        { 0x0C }
      3: (word_00_3: integer32;           { 0x00 }
          word_04_3: integer32;           { 0x04 }
          tz: cal_$timezone_rec_t);       { 0x08 }
  end;
  hint_uid_t = record
    case integer of
      1: (uid: uid_$t);
      2: (high: integer32;
          low: uid_$gen_low_t);
  end;
var
  source: rip_$nexthop_t;
  reply: reply_t;
  addrs: hint_$addr_t;
  hint: hint_uid_t;
  status: status_$t;
begin
  asknode_$internet_info(cmd, node, 0, 0, 16#200, reply.raw, status);

  if status.all = status_$ok then
    status := reply.status;
  if status.all <> status_$ok then
    if cmd <> asknode_$req_route_port then
      crash_system(status);

  case cmd of
    asknode_$req_boot_time:
      time_$clockh := reply.clockh;
    asknode_$req_timezone:
      cal_$timezone := reply.tz;
    asknode_$req_route_port:
      if (status.all = status_$ok) and then
         (route_$port[0].network <> reply.network) then begin
        hint.uid := uid_$nil;
        hint.low.node := node;
        addrs.node_id := node;
        addrs.flags := reply.network;
        hint_$addi(hint.uid, addrs);
        source.network := reply.network;
        source.host_bits.host_node := node;
        rip_$update_int(reply.network, source, 1, 0, false, status);
      end;
  end;
end;
