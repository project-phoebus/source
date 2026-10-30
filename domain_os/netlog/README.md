# The NETLOG subsystem in Domain Pascal

Network event logging.

## Layout

One module, `netlog.pas`, `module netlog;` (the map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | 0x464 bytes | NETLOG_$CNTL (= NETLOG_$PROC_START; its cells), NETLOG_$LOG_IT, NETLOG_$SEND_PAGE | none |
| .TEXT | 4 bytes | (NETLOG_$PROC_END: four zero bytes, a marker; no Pascal) | |

Data: the map's NETLOG data segment, 0x84 bytes in .DATA, the module's
variables in `netlog.pas` (initialized: the packet info template's
first 16 bytes), with the map symbol NETLOG_$DONE_CNT (+0x6C)
`define`d among them; NETLOG_$DATA_START and NETLOG_$DATA_END are
markers.  The six cells of the hand-written NETLOG_ASM data segment
(WIRED_DATA) are extern in `netlog.ins.pas`.

| offset | variable | type |
|--------|----------|------|
| +0x00 | `pkt_info` | pkt_$info_t, `[flags := 4, routing_type := 2, addr_type := 2, protocol := 16#8031, retry_limit := 1, field_0a := 0, field_0c := 16#FFFF]` |
| +0x20 | `wired_pages` | array[1..10] of integer32 |
| +0x48 | `pkt_hdr` | netlog_$pkt_hdr_t (10 bytes) |
| +0x54 | `unused_54` | integer32, never addressed |
| +0x58 | `buffer_va` | array[1..2] of integer32 |
| +0x60 | `buffer_ppn` | array[1..2] of integer32 |
| +0x68 | `spin_lock` | integer32 |
| +0x6C | `netlog_$done_cnt` (NETLOG_$DONE_CNT) | integer32, defined |
| +0x70 | `page_counts` | array[1..2] of integer |
| +0x74 | `current_buf_ptr` | integer32 (converted to netlog_$page_ptr_t at the dereference) |
| +0x78..+0x7C | `wired_page_count`, `send_page_index`, `current_buf_index` | integer |
| +0x7E, +0x80 | `initialized`, `ok_to_send` | boolean |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| NETLOG_$CNTL | `cntl.pas` (its cells: 10 and the four markers' addresses) |
| NETLOG_$LOG_IT | `log_it.pas` |
| NETLOG_$SEND_PAGE | `send_page.pas` |
| (data) | the NETLOG_ASM cells extern; the block is `netlog.pas`'s variables |

`netlog.ins.pas`: the entry (its fields named with the prefix `e_`,
review: NETLOG_$LOG_IT fills the entry inside a `with`, where
unprefixed names would hide the routine's parameters), page and
template types, the kinds set, the NETLOG_ASM externs,
NETLOG_$DONE_CNT, the markers (extern chars), the three headings (CNTL
by address; LOG_IT `val_param` with the 8-byte UID a value parameter;
SEND_PAGE none).

Changes to shared insert files:
- `pkt/pkt.ins.pas` (new): pkt_$info_t, pkt_$hdr_t and its pointer,
  PKT_$BLD_INTERNET_HDR (17 arguments, `val_param`).
- `net_io/net_io.ins.pas` (new): net_io_$send_info_t, NET_IO_$SEND.
- `netbuf/netbuf.ins.pas` (new): NETBUF_$GETVA, NETBUF_$RTNVA (an
  integer32 function).
- `network/network.ins.pas` (new): NETWORK_$GETHDR, NETWORK_$RTNHDR.
- `mmap/mmap.ins.pas`: MMAP_$FREE.  `wp/wp.ins.pas`: WP_$CALLOC.
  `mst/mst.ins.pas`: MST_$WIRE_AREA.  `ec/ec.ins.pas`: EC_$ADVANCE
  (hand-written, `var`).

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Types and names

- wired_pages is indexed from 1 (MST_$WIRE_AREA is passed element 1),
  and the unwire loop runs over 1 .. count.
- 0x3F6 is a data length, 39 entries of 26 bytes:
  PKT_$BLD_INTERNET_HDR's and NET_IO_$SEND's data_len.
- NETLOG_$SEND_PAGE passes the page's physical address (buffer_ppn <<
  10) as NET_IO_$SEND's data_pages; extra1 is NET_IO_$SEND's flags, not
  a PKT_$BLD_INTERNET_HDR argument; retry_hint and timeout are
  PKT_$BLD_INTERNET_HDR's.
- The wired count (NETLOG_$CNTL) and the data page's address
  (NETLOG_$SEND_PAGE) are expressions passed by address, not locals.

### TODO(pascal)

- `cntl.pas`: 2 frame bytes (stand-in `unused_a`).
- `log_it.pas`: 4 frame bytes (stand-in `unused_18`; the `with`
  temporary lead).
- `send_page.pas`: the header address loaded into a register before the
  `if` it is used under.

## Named dispatch codes

NETLOG's packet template uses pkt/pkt.ins.pas's `pkt_$routing_inet` and
`pkt_$addr_long` (pkt's dispatch-code block).
