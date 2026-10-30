# The APP subsystem in Domain Pascal

The application protocol layer (packets of the Domain internet and XNS
application channel).

## Layout

One module, `app.pas`, `module app, wired_proc, wired_data;` (the map
segments' name):

| section    | code           | routines | attribute |
|------------|----------------|----------|-----------|
| WIRED_PROC | APP, 0x3E8 bytes | APP_$RECEIVE, APP_$DEMUX, APP_$STD_OPEN | none (the heading's) |

Data: the APP data segment (0x74 bytes) in WIRED_DATA, the module's
variables in `app.pas` (all zero but APP_$STD_IDP_CHANNEL's 16#FFFF),
with the map symbol APP_$STD_IDP_CHANNEL (+0x14) `define`d among them.
Two routines use the block (APP_$RECEIVE and APP_$STD_OPEN through A5),
so its objects are module variables and the heading names WIRED_PROC
and WIRED_DATA (LOG's and KBD's shape); APP_$DEMUX loads no A5.

| offset | variable | type |
|--------|----------|------|
| +0x00 | `exclusion_lock` | ml_$exclusion_t |
| +0x12 | `unknown_12` | integer, never addressed |
| +0x14 | `app_$std_idp_channel` (APP_$STD_IDP_CHANNEL) | pinteger, defined, `:= 16#FFFF` |
| +0x16 | `unknown_16` | integer, never addressed |
| +0x18 | `temp_buffer` | array[1..16#5C] of char |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| APP_$RECEIVE | `receive.pas` |
| APP_$DEMUX | `demux.pas` |
| APP_$STD_OPEN | `std_open.pas` |
| (data) | the module's variables in `app.pas` |

All three routines are global (map symbols); none is nested, and there
is no module-local routine.  The Pascal reads the headers' fields
through the header records.

`app.ins.pas`: the status and protocol constants, the application
header `app_$pkt_hdr_t` (its fields prefixed `p_`, see the file), the
received Domain header `app_$rcv_hdr_t` (a variant part for its
variable part), the packed result record `app_$receive_rec_t` (the bit
fields at +0x26..+0x29), APP_$STD_IDP_CHANNEL, and the three headings:
APP_$RECEIVE `val_param` (the socket a word by value, the record and
status `out`), APP_$DEMUX the default convention (five addresses, the
xns_$demux_proc_t shape), APP_$STD_OPEN no parameters.

Changes to shared insert files:
- `sock/sock.ins.pas`: the packet flags' members, the socket
  descriptor, sock_$pkt_info_t (hdr an integer32 address), the
  SOCK_$SOCKET_PTR table, SOCK_$GET and SOCK_$PUT (boolean functions,
  `val_param`).
- `route/route.ins.pas`: route_$port_t's first field, ROUTE_$PORTP,
  ROUTE_$FIND_PORTP (a pointer function, `val_param`).
- `xns/xns.ins.pas`: XNS_IDP_HEADER_SIZE, the IDP header, the packet
  descriptor (a variant part at +0x34), the demux routine type, the
  channel open record, XNS_IDP_$OS_OPEN.
- `pkt/pkt.ins.pas`: pkt_$data_pages_t (the four payload pages, shared
  by the three records that hold them), PKT_$DUMP_DATA.
- `netbuf/netbuf.ins.pas`: NETBUF_$RTN_HDR, the header page record with
  its two queue words.
- `ml/ml.ins.pas`: ML_$EXCLUSION_START and _STOP (hand assembly, `var`).
- `os/os.ins.pas`: os_$data_t and OS_$DATA_COPY (hand assembly,
  `val_param`, `univ` source and destination).
- `ring/ring.ins.pas`: RING_$OVERFLOW_OVERFLOW and RING_$FILE_OVERFLOW
  (in NET_IO's block).

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Forms the image settles

- The two bytes before the ROUTE_$FIND_PORTP and PKT_$DUMP_DATA pushes
  are the alignment pad of a 6-byte argument list.
- The temp buffer is the block's last 0x5C bytes, from +0x18.
- `app_$pkt_hdr_t`'s byte at +0x14 is tested as a boolean by APP_$DEMUX
  (its sign).
- The record names for +0x08/+0x0C of the application header (src_)
  read as the destination on an incoming packet (TODO); kept.

### TODO(pascal)

- `receive.pas`: 24 frame bytes (stand-in `unused_68`); bounce's store
  between OS_$DATA_COPY's pushes.
- `demux.pas`: 8 frame bytes (stand-ins `unused_48`, `unused_4c`).
- `std_open.pas`: opt 8-aligned (no stand-in).

### The header's byte set

`app_$rcv_hdr_t`'s byte set at 0x07 is a `[byte] set of 0..7` field,
`rh_flags_07`, after the 7-char array (ref 3.15.5, p. 3-61: size
attributes on sets; a one-byte object may sit at an odd offset, ref
3.10.5.5): a plain set would take a word in the unpacked record (ref
3.9.3) and move every later field by 2.  The offsets (0x07, 0x08, 0x12,
0x18, 0x4B) follow from the reference's rules and the image's
displacements.  `receive.pas` reads `hdr^.rh_flags_07`.

## Named dispatch codes

app/app.ins.pas's dispatch-code block names APP_$RECEIVE's network types
(`app_$net_type_local`/`_remote`).
