# The NETWORK subsystem in Domain Pascal

The network layer's paging and header services, the network table and
the network's server processes.

## Layout

One module, `network.pas`, `module network, wired_proc, wired_data;`:
the map names its three code segments and its data segment NETWORK.

| section      | code size | routines | attribute |
|--------------|-----------|----------|-----------|
| WIRED_PROC   | 0x2DD0    | network_$phys_copy .. NETWORK_$REQUEST_SERVER | none (the heading's) |
| OS_INIT_PROC | 0x1C8     | NETWORK_$INIT, _$LOAD | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$   | 0x148     | NETWORK_$READ_SERVICE .. _$DISMISS_REQUEST_SERVERS | `[section(procedure$, data$)]` |

The map's NETWORK_ASM code segment (0xB8 bytes) is hand assembly:
NETWORK_$GET_CHKSUM (`m68k/get_chksum.s`) and OS_$DATA_COPY,
OS_$DATA_ZERO (os/'s rows).

Data: the map's NETWORK data segment in WIRED_DATA (0x364 bytes).  The
WIRED_PROC routines reach it through A5, the others by its address;
several routines share its objects, so they are module variables and
the globals the unit defines (the map's symbols in the block), and the
heading names the WIRED sections.  `network.pas` lists every object
with its offset.

## Routines and their fragments

One fragment per routine, included by `network.pas` in image order.

| routine | fragment |
|---|---|
| network_$phys_copy | `phys_copy.pas` (module-local, `internal`) |
| NETWORK_$INSTALL_NET | `install_net.pas` |
| NETWORK_$REMOVE_NET | `remove_net.pas` |
| NETWORK_$GET_NET | `get_net.pas` |
| GET_CHKSUM | `page_chksum.pas` (the map's name) |
| NETWORK_$GETHDR | `gethdr.pas` |
| NETWORK_$RTNHDR | `rtnhdr.pas` |
| NETWORK_$SET_SERVICE | `set_service.pas` |
| network_$send_request | `send_request.pas` (module-local) |
| network_$wait_response | `wait_response.pas` (module-local) |
| network_$do_request | `do_request.pas` (module-local) |
| NETWORK_$GET_PKT_SIZE | `get_pkt_size.pas` |
| NETWORK_$WRITE | `write.pas` |
| NETWORK_$READ_AHEAD | `read_ahead.pas` |
| NETWORK_$AST_GET_INFO | `ast_get_info.pas` |
| NETWORK_$RING_INFO | `ring_info.pas` |
| NETWORK_$REPORT_FAILURE | `report_failure.pas` (heading in network.pas) |
| network_$ps_send_reply | `ps_send_reply.pas` (nested in PAGE_SERVER, included by `page_server.pas`) |
| network_$process_paging_request | `process_paging_request.pas` (nested in PAGE_SERVER, included by `page_server.pas`) |
| NETWORK_$PAGE_SERVER | `page_server.pas` |
| NETWORK_$REQUEST_SERVER | `request_server.pas` |
| NETWORK_$GET_CHKSUM | none: hand assembly (`m68k/get_chksum.s`) |
| NETWORK_$INIT | `init.pas` |
| NETWORK_$LOAD | `load.pas` |
| NETWORK_$READ_SERVICE | `read_service.pas` |
| NETWORK_$ADD_PAGE_SERVERS | `add_page_servers.pas` |
| NETWORK_$ADD_REQUEST_SERVERS | `add_request_servers.pas` (the limit network_$max_request_servers: 2 on the SAU5, `two_request_servers`) |
| NETWORK_$DISMISS_REQUEST_SERVERS | `dismiss_request_servers.pas` |
| (data) | the module's variables in `network.pas` |

The SAU8's NETWORK routines need no source of their own: against the
SAU9's they differ only in addresses (the copy buffers, the memory map's
base, which `mmap_ppns_400` gives the MMAP array, `mmap/mmap.ins.pas`)
and, in NETWORK_$GET_PKT_SIZE, in the order of a comparison's operands,
where the SAU8 compares as the SAU2 does.  Nor do the SAU4's: against
the SAU2's they differ in addresses, in the 28-byte ASTE's wire count
(`large_vm'), in NETWORK_$GET_PKT_SIZE's operand order (as the SAU9's)
and in code generation.  Nor do the SAU7's: against the SAU8's they
differ only in addresses and in the memory map's base, which
`mmap_ppns_4000_bfff` gives the MMAP array; its NETWORK_ASM segment is
the SAU8's code.  Nor do the SAU6's: against the SAU9's they differ in
addresses, in the memory map's base, which `mmap_ppns_4000` gives the
MMAP array, and in the page-out's test of an anonymous object's UID in
network_$process_paging_request, whose operands the SAU6 compares in
the source's order (as the SAU2 and SAU4) where the SAU7, SAU8 and SAU9
compare the other way round; its NETWORK_ASM segment is every SAU's
code.

`fetch_diskless_info.pas` is the OS module's module-local routine (the
first of OS's OS_INIT_PROC segment): it stays here and is included by
`os/os.pas`, not by `network.pas`.

The two module-local routines before NETWORK_$PAGE_SERVER are nested in
it (the reply sender takes the server's frame in A1; the paging request
reads it through its dynamic link), so `page_server.pas` holds
PAGE_SERVER and includes the two fragments inside it.

The paging protocol's request and reply types are named in
`network.pas`'s `const` block (network_ps_rqst_*, network_ps_reply_*),
used by network_$process_paging_request's `case' labels and reply
stores and by the clients.  network_$fetch_diskless_info's ASKNODE
request codes are asknode/asknode.ins.pas's.  The slot `case's of
NETWORK_$PAGE_SERVER and NETWORK_$REQUEST_SERVER (EC_$WAITN's index)
are not codes and stay numbers.

Shared declarations: NETWORK_$REPORT_FAILURE's heading is in
`network.pas` (its formal is RING's ring_$csr_t); the two record views
in `network.ins.pas` (network_$obj_loc_t, network_$attr_rec_t) carry a
TODO(merge) (17 of that file's 25 includers do not include
file/file.ins.pas); RING_$SENDP's flags are `in univ integer'
(REQUEST_SERVER passes a constant cell).

## Open items

### TODO(pascal)

- `install_net.pas`, `set_service.pas`, `get_pkt_size.pas`,
  `load.pas`, `dismiss_request_servers.pas`, `send_request.pas`,
  `wait_response.pas`, `do_request.pas`, `write.pas`, `read_ahead.pas`,
  `page_server.pas`, `request_server.pas`,
  `process_paging_request.pas`: frame bytes no object explains, or
  frame offsets against dpc's.
- `send_request.pas`, `ps_send_reply.pas`: hdr_va stored back from a
  register after PKT_$BLD_INTERNET_HDR; the construct is not identified.
- `get_pkt_size.pas`: a direct route's 16#400 through another register
  and a dead load of the driver record.
- `read_ahead.pas`: the donated count compared signed, but the end's
  `for' loop has the unsigned count's guard.
- `report_failure.pas`, `page_server.pas`, `request_server.pas`:
  NETWORK_$SERVER_PKT_INFO copied as 0x1E bytes into a pkt_$info_t of
  32 (also rem_name/send_request.pas's).
- `process_paging_request.pas`: the zero dividend of the page-in's
  packet count; the log's word divides.
- `network.pas`: the block's unaddressed bytes at +0x252, +0x288,
  +0x2AC.
- `network.ins.pas`: the TODO(merge)s of the two record views.

Unsettled for MMAP: MMAP_$RMT_LIMIT is tested on its first byte's sign
by both its readers (PAGE_SERVER, REQUEST_SERVER); mmap/mmap.ins.pas
declares an integer32, so the Pascal tests its sign (the same bit); a
boolean would give the image's byte test.
