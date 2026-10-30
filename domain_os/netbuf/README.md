# The NETBUF subsystem in Domain Pascal

The network buffers (the header and data page pools and the virtual
window they are mapped into).

## Layout

One module, `netbuf.pas`, `module netbuf_, wired_proc, wired_data;` (the
map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | NETBUF_, 0x85C bytes | netbuf_rtnva_locked, NETBUF_$ADD_PAGES .. NETBUF_$RTN_PKT | none (the heading's) |
| OS_INIT_PROC | NETBUF_, 0x54 bytes | NETBUF_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the map's NETBUF_ data segment in WIRED_DATA, 0x338 bytes,
through A5 in the WIRED_PROC routines, by its address in NETBUF_$INIT:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `netbuf_$va_slots` | array[0..191] of integer32 |
| +0x300 | `netbuf_$delay_time` | time_$clock_t, initialized high 0, low 16#8000 (the image's bytes) |
| +0x308 | `netbuf_$spin_lock` | integer32 |
| +0x30C | NETBUF_$DAT_ALLOCS (`define`d) | integer32 |
| +0x310 | NETBUF_$HDR_ALLOCS (`define`d) | integer32 |
| +0x314 | NETBUF_$DAT_DELAYS (`define`d) | integer32 |
| +0x318 | NETBUF_$HDR_DELAYS (`define`d) | integer32 |
| +0x31C | NETBUF_$DAT_LIM (`define`d) | linteger |
| +0x320 | NETBUF_$DAT_CNT (`define`d) | linteger |
| +0x324 | NETBUF_$DAT_TOP (`define`d) | integer32 |
| +0x328 | NETBUF_$HDR_TOP (`define`d) | integer32 |
| +0x32C | `netbuf_$va_top` | integer32 |
| +0x330 | `netbuf_$va_base_addr` | integer32 |
| +0x334 | NETBUF_HDR_ALLOC (`define`d; a global though `$`-less) | integer |
| +0x336 | 2 bytes: the block's rounding to 4 | |

With `netbuf_cache_inhibit` (base/config.ins.pas: the SAU7 and SAU9)
NETBUF_$ADD_PAGES and NETBUF_$GET_HDR make each header page uncached
(MMU_$CACHE_INHIBIT_VA) once it is in the window.  With
`mmap_ppns_10000` (the SAU9) the data pool's links are the page
entries' 22-bit fields (`mmap/mmap.ins.pas`); the NETBUF source is the
same.

Routines: twelve globals (every map symbol), one module-local
(`internal`): netbuf_rtnva_locked, which has no map symbol and two
map-named callers.  None is nested; none is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| netbuf_rtnva_locked | `rtnva_locked.pas` (not adjacent to NETBUF_$RTNVA in the image) |
| NETBUF_$ADD_PAGES | `add_pages.pas` |
| NETBUF_$DEL_PAGES | `del_pages.pas` |
| NETBUF_$GETVA | `getva.pas` |
| NETBUF_$RTNVA | `rtnva.pas` |
| NETBUF_$GET_HDR_COND | `get_hdr_cond.pas` |
| NETBUF_$GET_HDR | `get_hdr.pas` |
| NETBUF_$RTN_HDR | `rtn_hdr.pas` |
| NETBUF_$GET_DAT_COND | `get_dat_cond.pas` |
| NETBUF_$GET_DAT | `get_dat.pas` |
| NETBUF_$RTN_DAT | `rtn_dat.pas` |
| NETBUF_$RTN_PKT | `rtn_pkt.pas` |
| NETBUF_$INIT | `init.pas` |
| (data) | the block in `netbuf.pas`; the two constant cells (time_$relative, passed to TIME_$WAIT, and status_$network_buffer_error) are the compiler's |

## Insert files

- `netbuf.ins.pas`: the header page's longword at 0x3FC named `phys`
  (the routines store and return the page's physical address there);
  the nine defined variables extern; the headings of every routine.
  Its users still check: `app/app.pas`, `netlog/netlog.pas`,
  `sock/sock.pas`, `mac_os/mac_os.pas`.
- `network/network.ins.pas`: status_$network_buffer_error and
  status_$network_out_of_blocks, the page type and
  NETWORK_$BUFPOOL (the window, a map symbol in NETPOOL).
  `netlog/netlog.pas` and `volx/volx.pas` still check.
- `proc1/proc1.ins.pas`: `proc1_$pcb_t` (mypid at 0x44) and its pointer
  type, for PROC1_$TYPE's index in NETBUF_$GET_HDR and _$GET_DAT.
- Used as they are: `ml/ml.ins.pas`, `time/time.ins.pas`,
  `misc/crash_system.ins.pas`, `mmu/mmu.ins.pas` (MMU_$INSTALL,
  MMU_$REMOVE), `mmap/mmap.ins.pas` (MMAP, MMAP_$FREE,
  MMAP_$PAGEABLE_PAGES), `wp/wp.ins.pas` (WP_$CALLOC, WP_$CALLOC_LIST),
  `pkt/pkt.ins.pas`.

## Open items

NETBUF_$GETVA adds NETWORK_$BUFPOOL's address to form a slot's address,
not the block's variable netbuf_$va_base_addr; NETBUF_$INIT sets the
variable to that address and nothing writes it again, so the two agree;
netbuf_rtnva_locked and NETBUF_$RTN_HDR do subtract the variable.

Form: the block is the module's variables and nine defined globals in
the image (the map names NETBUF_$DAT_ALLOCS .. NETBUF_$HDR_TOP and
NETBUF_HDR_ALLOC inside it; RING reads two of them by address), not one
record.  NETBUF_$GETVA and NETBUF_$RTNVA have no room in their frames
for a local address: GETVA reuses va_out's stored value, RTNVA assigns
its result straight from the call.  NETBUF_$DEL_PAGES' `va` and
NETBUF_$GET_DAT's `ppn` are stored only for the call that passes them.

### TODO(pascal)

- `rtn_pkt.pas`: the loop's index i is never formed; dat_arr[i] is a
  pointer stepped with it (strength reduction of a `while` loop's
  variable, as VFMT_$MAIN's, vfmt/main.pas).