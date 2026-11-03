# The RING subsystem in Domain Pascal

The token-ring driver (the units' interrupt, receive process and paging
fast path, the transmitter, the channels and their packet types, the
statistics, the MAC_OS entries) and the ring's packet log.

## Layout

Four map modules.  Three module files, which `tools/pascal_check.sh` finds
(`ring/ring.pas` by its name, the others by their headings), and one
fragment for ATBUS_, whose module file is `../sysbus/atbus_.pas`:

| file | heading | code | data |
|------|---------|------|------|
| `ring.pas` | `module ring, ring_proc, ring_data;` | RING in OS_INIT_PROC, 0x1A8 bytes (RING_$GET_ID, ring_$init_internal, RING_$INIT, `[section(os_init_proc, os_init_data)]`); RING in RING_PROC, 0x2B34 bytes (ring_$process_rx_packet .. RING_$SEND_OS) | RING in RING_DATA, 0x5D0 bytes (through A5); RING in OS_INIT_DATA, 4 bytes (empty: RING_$INIT's A5 is its end) |
| `ring_wired.pas` | `module ring_wired, , wired_data;` | none | RING_WIRED, 0xAC bytes (WIRED_DATA, by address) |
| `ringlog_.pas` | `module ringlog_, wired_proc, wired_data;` | RINGLOG_ in WIRED_PROC, 0x1F8 bytes (RINGLOG_$LOGIT); RINGLOG_ in PROCEDURE$, 0x168 bytes (ringlog_$stop_logging, RINGLOG_$CNTL, `[section(procedure$, data$)]`) | RINGLOG_, 0x3C bytes (WIRED_DATA, through A5 in RINGLOG_$LOGIT); the overlay section RINGLOG_$DATA, 0x11FC bytes |
| `../sysbus/atbus_.pas` | `module atbus_, wired_proc, wired_data;` (ATBUS_'s) | RING_INTERRUPT, the second routine of ATBUS_'s code segment (WIRED_PROC) | ATBUS_'s data segment |

RING_INTERRUPT is ring/'s routine, its code ATBUS_'s.  `interrupt.pas`
is a fragment of that module, included by its module file
`../sysbus/atbus_.pas` with disk/interrupt.pas,
sysbus/init.pas and sysbus/define_int.pas, which declares the block it
reads (type2_do_io, type2_dcte).

The blocks' objects, their offsets and image bytes are tabled at the top
of each module file.  RING's block: RING_$CTL (the two units' records),
RING_$SCRUB, RING_$FROM_ERR, the wire list, the driver record
(initialized with the driver's entries), RING_$FORCE_START and six
clocks (four of them RING_$SENDP's time-outs), the port table, the
map's counters, the wire count and the receive processes' table;
RING_WIRED's: the software diagnostic's and the biphase/ESB counters,
the swdiag record and the two units' statistics; RINGLOG_'s: the wired
pages, the spin lock, the node and socket filters, RING_$LOGGING_NOW and
the first-entry flag.

Routines (47 compiled, none hand assembly; there is no ring/sau2/):
- globals (map symbols): RING_$GET_ID, _$INIT, _$INT, _$SEND_NULL,
  _$SENDP, _$POLL_STICKY_BPHERR, HDR_CHKSUM, RING_$RCV0, _$RCV1, _$START,
  _$KICK_DRIVER, _$SET_TMASK, _$GET_STATS, _$STOP, _$PROC2_CLEANUP,
  _$IOCTL, _$SVC_OPEN, _$SVC_CLOSE, _$SVC_WRITE, _$SVC_READ, _$SVC_IOCTL,
  _$OPEN_OS, _$CLOSE_OS, _$SEND_OS (RING); RINGLOG_$LOGIT, _$CNTL
  (RINGLOG_); RING_INTERRUPT (ATBUS_);
- module-local (`internal`, no map symbol): ring_$init_internal,
  ring_$process_rx_packet, ring_$clear_dma_channel, ring_$setup_tx_dma,
  ring_$setup_rx_dma, ring_$rcv_from_unit_priv,
  ring_$find_pkt_type, ring_$pkt_type_overlaps,
  ring_$find_adjacent_pkt_type, ring_$find_overlapping_pkt_type,
  ring_$receive_packet, ring_$wire_driver, ring_$do_start,
  ring_$set_hw_mask, ring_$open_internal, ring_$copy_data,
  ring_$copy_to_user;
- nested: ring_$validate_receive in ring_$rcv_from_unit_priv,
  ring_$discard_packet in ring_$receive_packet, ringlog_$stop_logging in
  RINGLOG_$CNTL, each placed before its parent.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| RING_INTERRUPT | `interrupt.pas` (ATBUS_'s; included by `../sysbus/atbus_.pas`) |
| RINGLOG_$LOGIT | `logit.pas` |
| RING_$GET_ID | `get_id.pas` |
| ring_$init_internal | `init_internal.pas` |
| RING_$INIT | `init.pas` |
| ringlog_$stop_logging, RINGLOG_$CNTL | `cntl.pas` (the first nested in the second) |
| ring_$process_rx_packet | `process_rx_packet.pas` |
| RING_$INT | `int.pas` |
| ring_$clear_dma_channel | `clear_dma_channel.pas` |
| ring_$setup_tx_dma | `setup_tx_dma.pas` |
| ring_$setup_rx_dma | `setup_rx_dma.pas` |
| ring_$set_timer (`ring8_controller`) | `set_timer.pas` |
| ring_$read_timer (`ring8_controller`) | `read_timer.pas` |
| ring_$set_rx_buffer (`ring8_controller`) | `set_rx_buffer.pas` |
| ring_$set_ccb (`ring8_controller`) | `set_ccb.pas` |
| ring8_$unit_int, ring8_$start_rx, RING8_$INT (`ring8_controller`) | `ring8_int.pas` (the first two nested) |
| ring_$setup_tx (`ring8_controller`) | `setup_tx.pas` |
| ring_$copy_rx (`ring8_controller`) | `copy_rx.pas` |
| RING_$SEND_NULL | `send_null.pas` |
| RING_$SENDP | `sendp.pas` |
| ring_$rearm_rx (`ring8_controller`), ring_$validate_receive, ring_$rcv_from_unit_priv | `rcv_from_unit_priv.pas` (the first two nested) |
| RING_$POLL_STICKY_BPHERR | `poll_sticky_bpherr.pas` |
| HDR_CHKSUM | `hdr_chksum.pas` |
| ring_$find_pkt_type | `find_pkt_type.pas` |
| ring_$pkt_type_overlaps | `pkt_type_overlaps.pas` |
| ring_$find_adjacent_pkt_type | `find_adjacent_pkt_type.pas` |
| ring_$find_overlapping_pkt_type | `find_overlapping_pkt_type.pas` |
| ring_$discard_packet, ring_$receive_packet | `receive_packet.pas` (the first nested) |
| RING_$RCV0 | `rcv0.pas` |
| RING_$RCV1 | `rcv1.pas` |
| ring_$wire_driver | `wire_driver.pas` |
| ring_$do_start | `do_start.pas` |
| ring_$set_hw_mask | `set_hw_mask.pas` |
| RING_$START | `start.pas` |
| RING_$KICK_DRIVER | `kick_driver.pas` |
| RING_$SET_TMASK | `set_tmask.pas` |
| RING_$GET_STATS | `get_stats.pas` |
| RING_$STOP | `stop.pas` |
| RING_$PROC2_CLEANUP | `proc2_cleanup.pas` |
| RING_$IOCTL | `ioctl.pas` |
| ring_$open_internal | `open_internal.pas` |
| RING_$SVC_OPEN | `svc_open.pas` |
| RING_$SVC_CLOSE | `svc_close.pas` |
| ring_$copy_data | `copy_data.pas` |
| RING_$SVC_WRITE | `svc_write.pas` |
| ring_$copy_to_user | `copy_to_user.pas` |
| RING_$SVC_READ | `svc_read.pas` |
| RING_$SVC_IOCTL | `svc_ioctl.pas` |
| RING_$OPEN_OS | `open_os.pas` |
| RING_$CLOSE_OS | `close_os.pas` |
| RING_$SEND_OS | `send_os.pas` |
| (data) | the variables of `ring.pas`, `ring_wired.pas`, `ringlog_.pas`; the overlay in `ringlog.ins.pas` |

The helper routines lie in three runs of the image
(`clear_dma_channel.pas`, `setup_tx_dma.pas`, `setup_rx_dma.pas`;
`hdr_chksum.pas`; `wire_driver.pas`, `do_start.pas`,
`set_hw_mask.pas`).  RING_$RCV_FROM_UNIT_PRIV calls
ring_$receive_packet before its body: the `forward` heading in
ring.pas.

Headings (`ring_driver.ins.pas`, map order, each with its evidence): the
driver record's entries take the callers' shapes (NET_IO_$SEND,
NET_IO_$INIT, NET_IO_$DEVICE_STAT, NET_IO_$FREE_ASID;
NET_$OPEN/_$CLOSE/_$IOCTL/_$SEND/_$RCV; MAC_OS_$OPEN/_$CLOSE/_$SEND;
NETWORK_$SET_SERVICE), `val_param` where a word goes by value;
RING_$GET_ID, _$INIT, _$INT, _$POLL_STICKY_BPHERR, HDR_CHKSUM, _$START,
_$STOP, _$SET_TMASK and RINGLOG_$LOGIT, _$CNTL the default convention.
Functions: RING_$GET_ID (linteger), RING_$INIT (integer32: the status's
longword, as the DCTE's initialization routine type), RING_$INT,
RING_$POLL_STICKY_BPHERR (boolean), HDR_CHKSUM, RINGLOG_$LOGIT
(integer); the module-local ring_$init_internal (integer32),
ring_$process_rx_packet (an eventcount pointer in A0, its caller keeping
it in a register: no D0 parking), ring_$find_pkt_type and
_find_overlapping_pkt_type (integer), ring_$pkt_type_overlaps
(boolean).

## Insert files

- `ring.ins.pas` (users app/app.pas, net_io/net_io.pas and ring's files;
  sysbus/README.md names it for RING_INTERRUPT): the RING
  statuses (subsystem 0x31), the statistics and software-diagnostic
  records, the RING_WIRED block's map symbols, RING_$NETWORK_UID, the
  RING block's map-named counters.  Only base/base.ins.pas is needed (its
  users include it before ml, route, net_io).
- `ring_driver.ins.pas`: the controller's registers (`[device]`, the
  status words as sets), the ring header and its page, the channel,
  packet-type and unit records, the driver record (RING's own type with
  net_io_$driver_t's layout, its entries univ_ptr: RING_$SENDP's
  transmit status is a set, which net_io_$sendp_t's pinteger would
  refuse), the argument records, RING_$CTL and the block's other map
  symbols, the section markers, and every RING_ routine heading.  Needs
  base, ec, ml, time, pkt, io, route, sock, mac_os and ring.ins.pas
  first.
- `ringlog.ins.pas` (users net_io, route, ring): the entry's fields
  (`xmit_status`, `entries`, `index`, `ringlog_$data` and
  `ring_$logging_now` keep their names and offsets), the buffer's last
  word `unused_11fa` (0x11FC bytes), the buffer as the overlay section
  (`var (ringlog_$data)`), the RINGLOG_ block's map symbols,
  RINGLOG_$CNTL's heading and its parameter's type; the entries begin at
  +2.  NET_IO's `ringlog_$data.entries[i].xmit_status` is the same word.
- `../pkt/pkt.ins.pas`: pkt_$hdr_flags_t's `info_bits` (byte 4 as a set,
  the type mask; its member 7, `pkt_$hdr_broadcast`, is the broadcast
  bit); pkt_$hdr_t's `dest_node` and `src_node` linteger, for
  RINGLOG_$LOGIT's unmasked merges (truncations to 20 bits, logit.pas).
- `../time/time.ins.pas`: TIME_$ABS_CLOCK's clock `univ`
  (ring_$receive_packet passes a socket record's six bytes at +4).
- `../network/network.ins.pas`: four statuses, NETWORK_$ACTIVITY_FLAG,
  NETWORK_$DO_CHKSUM, NETWORK_$FAILURE_REC and its record.
- `../io/io.ins.pas`: io_$do_io_t, the controllers' interrupt routine
  type (RING_INTERRUPT's call).
- Used as they are: base, ec, ml, misc/crash_system, os, node, proc1,
  netbuf, netlog, route, sock, net, rip, net_io, mac_os, fim, mst, mmu,
  parity, cal (ADD48, SUB48), dma; wp in RINGLOG_.

## Other SAUs

The SAU5's RING is the SAU2's source with three parts
(`base/config.ins.pas`), all its blocks the SAU2's sizes and
bytes (RING_DATA 0x5D0, OS_INIT_DATA 4, RING_WIRED 0xAC):

- `ring_controller_dma` (SAU5, SAU6): the controller moves its packets
  itself.  `ring_driver.ins.pas` extends `ring_$regs_t` to 0x52 bytes
  (the buffers' addresses and counts, the vector registers);
  ring_$process_rx_packet (`process_rx_packet.pas`) and
  ring_$validate_receive (`rcv_from_unit_priv.pas`) read the lengths
  from the counts and re-arm through them; ring_$setup_tx_dma and
  ring_$setup_rx_dma (`setup_tx_dma.pas`, `setup_rx_dma.pas`) take the
  registers first and set them;
  ring_$clear_dma_channel and its five calls (`sendp.pas`,
  `rcv_from_unit_priv.pas`) are not compiled.  The SAU5's RING_PROC
  segment is 0x29B4 bytes.
- `ring_vector_regs` (SAU5): ring_$init_internal (`init_internal.pas`)
  sets the three vector registers to 16#3D00.
- `ring_owner_test_reversed` (SAU5, SAU7..SAU9): RING_$SVC_WRITE's owner
  test with the channel on the left (`svc_write.pas`).

RING_$RCV0 and RING_$RCV1 do not load A5 in the SAU5 image (their worker
does), where the SAU2's do; the source is the same.
RING_$IOCTL differs from the SAU2's only in call displacements.

The SAU3's RING is the SAU2's source, with the SAU2's DMA controller
form and the SAU2's block sizes and bytes (RING_DATA 0x5D0,
OS_INIT_DATA 4, RING_WIRED 0xAC), less one part:

- `ring_xmit_light` (every SAU but the SAU3): RING_$SENDP toggles the
  memory control register's transmit light when a send completes
  (`sendp.pas`).  The SAU3's RING_PROC segment is 0x2B24 bytes, 0x10
  less than the SAU2's.

The SAU7..SAU9 drive another controller, with packet buffers and a
command block of its own (`ring8_controller`): the map's RING8_$INT in
place of RING_$INT, RING_$CCB, RING_ASM (RING_$RB_FROM, RING_$RB_TO,
hand assembly, extern headings in `ring_driver.ins.pas`) and a
0xAB0-byte RING_DATA block of 0x4A4-byte unit records.  Translated for
the SAU9 (`ring_driver.ins.pas`'s `ring8_$csr_t`, `ring8_$rx_buf_t`,
`ring8_$ccb_t` and the unit record's `ring8_controller` fields from
0x236; `ring.pas`'s RING_DATA block, with the units' receive pages,
and ring_$init_internal's OS_INIT_DATA tables, both byte-compared with
the image):

- conditional arms: ring_$init_internal (`init_internal.pas`: the I/O
  descriptor's two CSR windows, IO_$ACQUIRE with RING8_$INT, the
  command block, the buffers laid out by the controller type's
  parameters), ring_$process_rx_packet (`process_rx_packet.pas`: the
  packet in the controller's buffer, the paging fast path for
  header-only packets, the next buffer given), RING_$SENDP (`sendp.pas`:
  the copy into the controller under the buffer lock, the command
  word, RING_$FROM_ERR and RING_$SCRUB), ring_$rcv_from_unit_priv
  (`rcv_from_unit_priv.pas`: the buffers taken in turn, a stopped
  receive restarted, with the nested ring_$rearm_rx and its own
  ring_$validate_receive);
- new: RING8_$INT with its nested ring8_$unit_int and ring8_$start_rx
  (`ring8_int.pas`), and the module-local ring_$set_timer,
  ring_$read_timer, ring_$set_rx_buffer, ring_$set_ccb, ring_$setup_tx
  and ring_$copy_rx;
- RING_$POLL_STICKY_BPHERR (`poll_sticky_bpherr.pas`) reads the
  controller's status word through the DCTE's I/O descriptor;
- RING_$GET_ID (`get_id.pas`) reads the node id PROM (`nodeid_prom`,
  the SAU9 only);
- RING_$INIT, RING_$RCV0 and RING_$RCV1 are the SAU2's source (the unit
  record's size changes with the part).

Without `ring8_controller` none of the new routines is compiled; with
it RING_$INT, ring_$clear_dma_channel, ring_$setup_tx_dma and
ring_$setup_rx_dma are not.

## Open items

### Behavior the image settles

- ring_$init_internal stores the register block into the unit, probes
  it with TESTPAGE, returns status_$io_controller_not_in_system
  (16#00100002) when the probe faults and clears both status words
  otherwise.
- ring_$process_rx_packet returns the wake eventcount for every packet
  it leaves to the receive process, delivers network paging packets
  itself through SOCK_$PUT_INT_INT and returns nil for them (so RING_$INT
  counts them), counts the software diagnostic's packets, retries a full
  paging socket 2 as socket 6, crashes when no buffer can be taken, and
  re-arms the receive DMA.
- ring_$clear_dma_channel aborts channels 0 and 1 when bit 0 of the
  unit's receive status is set, channel 2 when it is clear, and checks
  the channel's error bit (a crash) on every channel it did not abort.
- ring_$do_start creates the receive process (PROC1_$CREATE_P with the
  unit's RING_$RCV0/1), returns its status, waits for its first advance
  of ready_ec or two ticks and crashes with 16#00110005 on the time-out.
- ring_$set_hw_mask does nothing for an unchanged mask, sets or clears
  the running bit by the mask's bits other than 0 and 7, sets the busy
  bit, counts RING_$UNIT_TMASK_CHG_CNT and advances an initialized
  unit's rx_wake_ec.
- RING_$KICK_DRIVER sets both units' busy bits and advances each
  initialized one's rx_wake_ec.  No caller in the image.
- RING_$SET_TMASK takes one mask by address and updates both units in
  place, counting RING_$SET_TMASK_CHG_CNT.  No caller in the image.
- RING_$SVC_WRITE builds the ring header in a header page, gathers the
  caller's bytes, sends with RING_$SENDP and/or loops back through the
  channel's socket, and returns pages; it refuses data over 0x400 bytes
  and a packet type the channel does not own, and tests bit 0 of the
  transmit mask.
- RING_$SVC_READ does not clear the result at entry; it tests bit 0 of
  the transmit mask; a packet with more than 0x400 data bytes is dropped
  and the call returns status_$network_msg_exceeds_max_size
  (16#0011001E); its fault path returns the pages held.
- The transmit status's bits are named after the RING_$SENDP arms that
  set them (ring_driver.ins.pas).
- The stats field `last_success` holds the negation of RING_$SENDP's
  activity: true after a send the ring did not take.
- The register block's first word is the transmit status and the second
  the receive status.
- RINGLOG's entries are at +2 of the buffer (ringlog.ins.pas).
- RING_$SVC_READ's hdr_len and data_len are named by the image's use.
- RING_$RCV_FROM_UNIT_PRIV and RINGLOG_$STOP_LOGGING are names with the
  global form; the map has no symbol for either (module-local and
  nested).
- The SAU8 (and SAU7) RING_$GET_ID probes a node id PROM in the page of
  PIC1 (TESTPAGE, a byte read) and takes the id from its first four
  words' high bytes when it answers and its first word is zero, from
  RING2's first four words otherwise; the PROM has no map symbol
  (`node_id_prom` in `ring_driver.ins.pas`).  The SAU8's other RING
  routines are the SAU9's but for ring_$setup_tx's PARITY_ calls.

### TODO(pascal)

- `ring_driver.ins.pas`: five words of the unit record no field of the
  word rules explains.
- `ring.pas`: 16 bytes of the RING block (the clocks' 2-byte gaps, the
  word before the receive table); the frames not checked against dpc's
  layout routine by routine (the list there).
- `get_id.pas`: 4 frame bytes and the register copy of RING_$GET_ID.
- `init.pas`: 12 frame bytes of RING_$INIT (the stand-ins unused_18,
  unused_1c).
- (not ring's) `process_rx_packet.pas` reads the DMA status bits as `&'
  on the char registers' ordinals; the set reading is the TODO(pascal) in
  `../dma/check.pas`.

## Named dispatch codes

ring/ringlog.ins.pas names RINGLOG_$CNTL's commands (`ringlog_$cmd_*`),
used in ring/cntl.pas and by ASKNODE_$INTERNET_INFO; ring/ring.ins.pas
names RING_$SVC_IOCTL's commands (`ring_$ioctl_*`).  RING_$INIT creates its
port with route/route.ins.pas's `route_$port_type_ring`, and RING_$INT
tests the routing type with pkt/pkt.ins.pas's `pkt_$routing_local`.
