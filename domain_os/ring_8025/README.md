# The RING_8025 module in Domain Pascal

The IEEE 802.5 token-ring driver for the AT-bus adapter of the SAU9
(DN2500): an adapter built on a TMS380-family ring controller, which the
host drives through the controller's system interface (the SIF
registers) and through the system command and status blocks in the
host's memory.  Only the SAU7, SAU8 and SAU9 maps have the module (the
part `ring_8025_driver`, `base/config.ins.pas`); on the other SAUs the
module file compiles to nothing.

## Layout

One module, `ring_8025.pas`, `module ring_8025, ring8025_proc,
ring8025_data;` (the driver's block is module variables, through A5).

| section | contents |
|---------|----------|
| RING8025_PROC | the RING_8025 code segment: SAU9 0x4814 bytes (module-local routines and the 21 map routines RING_8025_$NULLSAP_HELPER .. RING_8025_$RCV1) |
| RING8025_DATA | SAU9 0x168 bytes: the largest-frame sizes, the wired pages, the driver record, the wiring counts (`ring_8025.pas` tables them) |
| RING8025_UCB | SAU9 0x868 bytes: the two units' records (`ring_8025_$unit_t`, 0x434 bytes each), an overlay section |
| RING8025_$AUX_DA | SAU9 0x8000 bytes: the units' window pages, a map page, the units' control areas (six contiguous pages each: the transmit and receive lists, the system status and command blocks, the open parameters, the receive frame buffer) and route caches (64 buckets of three routes each), an overlay section |

The driver's declarations are `ring_8025.ins.pas` (statuses, registers,
the initialization parameters, the command block, the unit and driver
records, the headings).  Unlike ETHERNET, the SAU2..SAU6 maps have no
RING_8025 segment at all, so there is no stub.

## Routines and their fragments (image order)

| routine | fragment |
|---------|----------|
| ring_8025_swap16 | `swap16.pas` |
| ring_8025_wait | `wait.pas` |
| ring_8025_check_status | `check_status.pas` |
| ring_8025_wire_driver | `wire_driver.pas` |
| ring_8025_unwire_driver | `unwire_driver.pas` |
| ring_8025_vtop | `vtop.pas` |
| ring_8025_probe | `probe.pas` |
| ring_8025_reset | `reset.pas` |
| ring_8025_initialize | `initialize.pas` |
| ring_8025_scb_cmd | `scb_cmd.pas` |
| ring_8025_scb_cmd_addr | `scb_cmd_addr.pas` |
| ring_8025_wait_scb | `wait_scb.pas` |
| ring_8025_open | `open.pas` |
| ring_8025_close | `close.pas` |
| ring_8025_start_xmit | `start_xmit.pas` |
| ring_8025_start_rcv | `start_rcv.pas` |
| ring_8025_xmit_halt | `xmit_halt.pas` |
| ring_8025_start_unit | `start_unit.pas` |
| ring_8025_stop_rcv | `stop_rcv.pas` |
| ring_8025_transmit | `transmit.pas` |
| ring_8025_find_type | `find_type.pas` |
| ring_8025_range_overlaps | `range_overlaps.pas` |
| ring_8025_find_adjacent | `find_adjacent.pas` |
| ring_8025_find_range | `find_range.pas` |
| ring_8025_send_xid | `send_xid.pas` |
| ring_8025_learn_route | `learn_route.pas` |
| ring_8025_learn_local | `learn_local.pas` |
| ring_8025_find_route | `find_route.pas` |
| RING_8025_$NULLSAP_HELPER | `nullsap_helper.pas` |
| ring_8025_queue_nullsap | `queue_nullsap.pas` |
| copy_data (nested in ring_8025_receive_frame) | `receive_frame.pas` |
| ring_8025_receive_frame | `receive_frame.pas` |
| ring_8025_close_socket | `close_socket.pas` |
| ring_8025_read_stats | `read_stats.pas` |
| RING_8025_$INIT | `init.pas` |
| RING_8025_$START | `start.pas` |
| RING_8025_$STOP | `stop.pas` |
| RING_8025_$LOAD | `load.pas` |
| RING_8025_$SEND | `send.pas` |
| RING_8025_$GET_STATS | `get_stats.pas` |
| RING_8025_$GET_STATS2 | `get_stats2.pas` |
| RING_8025_$IOCTL | `ioctl.pas` |
| ring_8025_open_channel | `open_channel.pas` |
| RING_8025_$SVC_OPEN | `svc_open.pas` |
| RING_8025_$SVC_CLOSE | `svc_close.pas` |
| ring_8025_copy_to_user | `copy_to_user.pas` |
| RING_8025_$SVC_READ | `svc_read.pas` |
| ring_8025_copy_data | `copy_data.pas` |
| RING_8025_$SVC_WRITE | `svc_write.pas` |
| RING_8025_$SVC_IOCTL | `svc_ioctl.pas` |
| RING_8025_$PROC2_CLEANUP | `proc2_cleanup.pas` |
| RING_8025_$OPEN_OS | `open_os.pas` |
| RING_8025_$CLOSE_OS | `close_os.pas` |
| RING_8025_$SEND_OS | `send_os.pas` |
| RING_8025_$INT | `int.pas` |
| ring_8025_rcv_process | `rcv_process.pas` |
| RING_8025_$RCV0 | `rcv0.pas` |
| RING_8025_$RCV1 | `rcv1.pas` |

## Open items

- The SAU7 and SAU8 have the driver too (0x49A4 and 0x471C bytes);
  `tools/sau_catalog.py` puts the SAU8 and SAU9 forms of most map
  routines in one family.  RING_8025_$NULLSAP_HELPER, _$INT,
  _$SVC_IOCTL, _$RCV0 and _$RCV1 are the SAU9's own; the SAU7 and SAU8
  segments end with RING_8025_ASM (RING_8025_$$MOVB2B), which the SAU9's
  lacks.
- TODO(pascal): the size of a range of the unit's frame-type table
  (12 bytes apart, 10 copied by RING_8025_$SVC_CLOSE,
  RING_8025_$SVC_IOCTL and RING_8025_$PROC2_CLEANUP;
  `ring_8025.ins.pas`).
- The unit record's unused_ fields (the word after each exclusion lock,
  0x00A and 0x0F2) and the auxiliary area's are addressed by no routine
  of the module.
- The module does not include `mmu/mmu.ins.pas`: the SAU9's
  MMU_$REMOVE takes a second argument, and `ring_8025.ins.pas` declares
  the six MMU routines the driver calls (as ETHERNET and WIN_SCSI do).
- The interrupt routine makes the transfers the adapter asks for itself
  (the data word at 0, the byte at 2), a page at a time through the
  auxiliary area's map page; it hands the ring status and the adapter
  check to the receive process through the unit's flags 7..10.
- The adapter is reset through the control byte at 6 and polled for
  its bring-up diagnostics (ring_8025_reset); the eleven words of the
  initialization parameters go to the controller's memory at 0x0A00
  through the system interface (ring_8025_initialize).
