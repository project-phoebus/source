# The PKT subsystem in Domain Pascal

The internet packets (building and taking apart the Domain internet
header, sending with retries, request and reply, the ping server and the
list of nodes that failed to answer).

## Layout

One module, `pkt.pas`, `module pkt, wired_proc, wired_data;` (the map
segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | PKT, 0xD0C bytes | PKT_$BLD_INTERNET_HDR .. PKT_$PING_SERVER | none (the heading's) |
| OS_INIT_PROC | PKT, 0x34 bytes | PKT_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ | PKT, 0x2C0 bytes | PKT_$SAR_INTERNET | `[section(procedure$, data$)]` |

Data: the map's PKT data segment in WIRED_DATA, 0xA8 bytes, through A5
in the WIRED_PROC routines that use it; PKT_$INIT and PKT_$SAR_INTERNET
use none of it:

| offset | variable | type |
|--------|----------|------|
| +0x00 | PKT_$MISSING_NODE (`define`d) | array[1..10] of pkt_$missing_entry_t |
| +0x50 | `pkt_$spin_lock` | integer32 |
| +0x54 | `pkt_$visibility_seq` | linteger, initialized 1 |
| +0x58 | PKT_$N_MISSING (`define`d) | integer |
| +0x5A | `pkt_$ping_req_hdr` | integer, initialized 1 (the ping's 2-byte template) |
| +0x5C | `pkt_$short_id` | pinteger |
| +0x5E | 2 bytes: `pkt_$long_id`'s alignment | |
| +0x60 | `pkt_$long_id` | integer32 |
| +0x64 | `pkt_$default_flags` | integer |
| +0x66 | `unused_66` | integer, a stand-in: nothing addresses it, and dpc places the next record 2-aligned |
| +0x68 | `pkt_$ping_template` | pkt_$info_t, initialized (flags 0x10) |
| +0x88 | `pkt_$ping_reply_info` | pkt_$info_t, initialized (flags 0x20) |

`dpc -o` on the declarations gives the image's 0xA8 bytes exactly.

Routines: fourteen globals (every map symbol), none module-local, none
nested, none hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PKT_$BLD_INTERNET_HDR | `bld_internet_hdr.pas` |
| PKT_$BRK_INTERNET_HDR | `brk_internet_hdr.pas` |
| PKT_$NEXT_ID | `next_id.pas` |
| PKT_$NEXT_LONG_ID | `next_long_id.pas` |
| PKT_$COPY_TO_PA | `copy_to_pa.pas` |
| PKT_$SEND_INTERNET | `send_internet.pas` |
| PKT_$DUMP_DATA | `dump_data.pas` |
| PKT_$DAT_COPY | `dat_copy.pas` |
| PKT_$RECENTLY_MISSING | `recently_missing.pas` |
| PKT_$NOTE_VISIBLE | `note_visible.pas` |
| PKT_$LIKELY_TO_ANSWER | `likely_to_answer.pas` |
| PKT_$PING_SERVER | `ping_server.pas` |
| PKT_$INIT | `init.pas` |
| PKT_$SAR_INTERNET | `sar_internet.pas` |
| (data) | the block in `pkt.pas`; the four constant cells (the integer32 0 the ping senders pass as data, time_$relative, and two statuses to CRASH_SYSTEM) are the compiler's |

## Insert files

- `pkt.ins.pas` (reviewed; NET_IO rewrote the header record earlier).
  For PKT:
  - `pkt_$hdr_flags_t` has a second variant, `info_flags`, the whole
    byte 4 (PKT_$BLD_INTERNET_HDR writes it as a byte).  The first
    variant's byte 4 is `info_bits`, the type mask, a set of 8 whose
    member 7 is broadcast (`pkt_$hdr_broadcast`): both images test bit
    7 on the byte, the set member's form, where a packed boolean there
    is tested on the word.
  - PKT_$BLD_INTERNET_HDR's heading: request_id, template_len and
    data_len are pinteger (unsigned compares and zero-extensions in the
    body), and timeout_out is `out pinteger` (its readers widen it with
    zeros).  (Review:) dest_node and src_node are linteger: the body
    merges them unmasked into the packed node fields, the form for a
    type without negative values (dpc masks an integer32 there).
  - pkt_$bytes_t and its pointer, pkt_$net_addr_t, pkt_$internet_hdr_t
    (the reply header) and its pointer, pkt_$sar_result_t,
    pkt_$missing_entry_t, the externs PKT_$MISSING_NODE and
    PKT_$N_MISSING, and the headings of the twelve other routines.
    Still only `base/base.ins.pas` before it, so `netbuf/netbuf.ins.pas`
    and the other users include it as before.
  - Users re-checked: app, net, net_io (both modules), netbuf, netlog,
    sock, volx, mac_os, hint, bat (the full gate).
- `netlog/send_page.pas`: its local `timeout` is pinteger, the type of
  PKT_$BLD_INTERNET_HDR's `out` timeout_out.
- `rip/rip.ins.pas`: rip_$dest_addr_t (a packed record: the 20-bit
  host_node field the PKT routines merge into the longword at 6) and
  RIP_$FIND_NEXTHOP's heading.  Its users mac/send.pas and mac_os/*
  still check.
- `network/network.ins.pas`: seven network statuses and
  NETWORK_$LOOPBACK_FLAG.
- `fim/fim.ins.pas`: FIM_$SIGNAL's heading.
- `time/time.ins.pas`: time_$wait_quit (the customer time.ins.pas's
  name for 16#000D0003).
- Used as they are: `ml/ml.ins.pas`, `misc/crash_system.ins.pas`,
  `os/os.ins.pas`, `node/node.ins.pas`, `proc1/proc1.ins.pas`,
  `netbuf/netbuf.ins.pas`, `route/route.ins.pas`, `sock/sock.ins.pas`,
  `xns/xns.ins.pas`, `app/app.ins.pas`, `net_io/net_io.ins.pas`,
  `ec/ec.ins.pas`.

## Open items

Form and names:
- PKT_$NOTE_VISIBLE: a visible node leaves the list; a node not visible
  is kept on it or added.
- PKT_$LIKELY_TO_ANSWER, PKT_$SAR_INTERNET and PKT_$PING_SERVER call
  SOCK_$ALLOCATE and SOCK_$OPEN with four words after the socket
  (sock/sock.ins.pas): 2, 1, 0, 1024; 2, 1, 1, 1024; 3, 0, 0, 1024,
  which the image pushes merged into two longwords each.
- PKT_$SEND_INTERNET keeps one header pointer, held in a register with
  its frame home, stored there before each pass by address.
- PKT_$BRK_INTERNET_HDR has no room in its 4-byte frame for a template
  offset local (the expression is formed once and kept in a register).
- 16#00110005 is named status_$network_receive_process_failed_to_start;
  stcode.db.10.2's text is "no available socket", and PKT_$SAR_INTERNET
  crashes with it when it cannot get a socket.
- The word below the callers' pushes is the alignment pad, not a
  function-result slot.
- The block is, in the image, the module's variables and two defined
  globals, not one record.

### TODO(pascal)

- `bld_internet_hdr.pas`: the unsigned template_len is tested signed
  once.
- `copy_to_pa.pas`: buffers_out[buf_count] reached through a stepped
  pointer while buf_count is kept in its frame word.
- `dat_copy.pas`: the loop's index is never formed (a stepped pointer,
  as NETBUF_$RTN_PKT's).
- `likely_to_answer.pas`: 30 frame bytes no instruction addresses.
- `ping_server.pas`: 22 frame bytes no instruction addresses.

## Named dispatch codes

pkt/pkt.ins.pas's dispatch-code block names the routing types
(`pkt_$routing_local`/`_inet`), the address types
(`pkt_$addr_short`/`_long`) and the long-address subtype
(`pkt_$subtype_long_addr`; msg's msg_proto_subtype_inet is the same
code).  Used in bld_internet_hdr, brk_internet_hdr, pkt.pas's templates,
and by net_io, ring, route, asknode, msg, netlog and rip.
