# The SOCK subsystem in Domain Pascal

The network sockets (descriptors, the free list, the packet queues).

## Layout

One module, `sock.pas`, `module sock, wired_proc, wired_data;` (the map
segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | SOCK, 0x5B4 bytes | SOCK_$OPEN, _$ALLOCATE, _$ALLOCATE_USER, _$CLOSE, _$GET, _$PUT, _$PUT_INT, _$PUT_INT_INT | none (the heading's) |
| OS_INIT_PROC | SOCK, 0x7C bytes | SOCK_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the map's SOCK data segment in WIRED_DATA, 0x1C28 bytes, through
A5 (SOCK_$INIT by the block's absolute address):

| offset | variable | type |
|--------|----------|------|
| +0x0000 | SOCK_LIST (`define`d; a global though `$`-less) | sock_$list_t |
| +0x0020 | SOCK_$SOCKET (`define`d) | array[1..0xE0] of sock_$sock_t |
| +0x18A0 | `sock_lock` | integer32 |
| +0x18A4 | SOCK_$SOCKET_PTR (`define`d) | array[1..0xE0] of sock_$sock_ptr_t |
| +0x1C24 | `sock_user_limit` | integer, initialized 16#40 (the image's word) |
| +0x1C26 | 2 bytes: the block's rounding to 4 | |

All nine routines are global; none nested or module-local.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| SOCK_$OPEN | `open.pas` |
| SOCK_$ALLOCATE | `allocate.pas` |
| SOCK_$ALLOCATE_USER | `allocate_user.pas` |
| SOCK_$CLOSE | `close.pas` |
| SOCK_$GET | `get.pas` |
| SOCK_$PUT | `put.pas` |
| SOCK_$PUT_INT | `put_int.pas` |
| SOCK_$PUT_INT_INT | `put_int_int.pas` |
| SOCK_$INIT | `init.pas` |
| (data) | the block in `sock.pas` |

## Insert files

- `sock.ins.pas` (from APP's translation, MAC's additions kept): the
  flag word a variant packed record (`open`, `user_mode`, `allocated`,
  `number`, or `members`, a word set: the image stores the fields and
  tests the set's members), the flag members and the first dynamic
  number, `sock_$list_t`, `sock_$hdr_bytes_t`; SOCK_LIST and
  SOCK_$SOCKET extern; the headings of every routine.  `app/app.pas`
  and `mac_os/mac_os.pas` include it.
- `netbuf/netbuf.ins.pas`: the header page's queue fields;
  NETBUF_$ADD_PAGES, _$DEL_PAGES.
- `ec/ec.ins.pas`, `ml/ml.ins.pas`, `pkt/pkt.ins.pas`: used as they are
  (EC_$INIT, EC_$ADVANCE, the spin lock, PKT_$DUMP_DATA).

## Open items

### Form

- SOCK_$OPEN, _$ALLOCATE and _$ALLOCATE_USER take four words, the
  descriptor's max_queue, hdr_pages, data_pages and max_data_len
  (`sock.ins.pas`); read as two longwords they would be pairs of these.
- The code indexes the block's arrays from 1 only: there is no socket 0
  over SOCK_LIST's tail and no pointer 0, nor 0xE1, over the lock or the
  limit.

### TODO(pascal)

- `allocate.pas`: 2 frame bytes (stand-in `unused_8`).
- `get.pas`: the lengths' one-longword copy; 2 frame bytes (`unused_10`).
- `put_int.pas`: SOCK_$PUT_INT's signed and unsigned bound tests, 4 frame
  bytes (`unused_8`); SOCK_$PUT_INT_INT's open test as the word's sign,
  4 frame bytes (`unused_14`).
