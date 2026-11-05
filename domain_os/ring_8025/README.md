# The RING_8025 module in Domain Pascal

The IEEE 802.5 token-ring driver for the AT-bus adapter of the SAU7,
SAU8 and SAU9: an adapter built on a TMS380-family ring controller, which
the host drives through the controller's system interface (the SIF
registers) and through the system command and status blocks in the
host's memory.  Only the SAU7, SAU8 and SAU9 maps have the module (the
part `ring_8025_driver`, `base/config.ins.pas`); on the other SAUs the
module file compiles to nothing.

On the SAU7 and SAU8 (`ring_8025_dma_channel`) the adapter makes its
transfers itself through the unit's DMA channel in cascade mode, which
the driver starts at each initialization and stops before each reset
and when the unit goes off line; the SAU9's interrupt routine makes the
transfers the adapter asks for, through a map page of the auxiliary
area that the other two do not have.  The SAU8's adapter is initialized
with other options (`ring_8025_no_data_bursts`).  The SAU7's adapter
reaches memory through the I/O map (`ring_8025_iomap`): each unit has a
region of eleven bus pages, into which the driver maps every buffer it
gives the adapter.

## Layout

One module, `ring_8025.pas`, `module ring_8025, ring8025_proc,
ring8025_data;` (the driver's block is module variables, through A5).

| section | contents |
|---------|----------|
| RING8025_PROC | the RING_8025 code segment: SAU9 0x4814 bytes, SAU8 0x471C, SAU7 0x49A4 (module-local routines and the 21 map routines RING_8025_$NULLSAP_HELPER .. RING_8025_$RCV1); on the SAU8 and SAU7 then RING_8025_ASM, 0x38 bytes: RING_8025_$$MOVB2B, hand assembly (`m68k/ring_8025_asm.s`) |
| RING8025_DATA | SAU9 0x168 bytes, SAU8 and SAU7 0x164 (no map page's page table entry): the largest-frame sizes, the wired pages, the driver record, the wiring counts (`ring_8025.pas` tables them) |
| RING8025_UCB | SAU9 and SAU8 0x868 bytes, SAU7 0x870: the two units' records (`ring_8025_$unit_t`, 0x434 bytes each, 0x438 on the SAU7), an overlay section |
| RING8025_$AUX_DA | SAU9 0x8000 bytes, SAU8 and SAU7 0x7C00 (no map page): the units' window pages, a map page, the units' control areas (six contiguous pages each: the transmit and receive lists, the system status and command blocks, the open parameters, the receive frame buffer) and route caches (64 buckets of three routes each), an overlay section |

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
| ring_8025_map_pa | `map_pa.pas` (SAU7, `ring_8025_iomap`) |
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
| RING_8025_$$MOVB2B | none: hand assembly, `m68k/ring_8025_asm.s` (SAU8 and SAU7; nothing calls it) |

## Open items

- The SAU7's driver is the SAU8's source with `ring_8025_iomap`
  (base/config.ins.pas): the unit record's iomap_page at 0x424, the
  fields after it 4 bytes on; the region allocated by
  ring_8025_start_unit and freed by ring_8025_rcv_process; the new
  ring_8025_map_pa (a physical address's page mapped at a bus page) and
  ring_8025_vtop's other form (a virtual range mapped from a bus page),
  which give the bus addresses the adapter is passed; the control
  area's pages uncached by ring_8025_wire_driver; bit 1 of the third
  control register cleared by the start.  Each transmit maps the
  frame's header at the region's first page and its data pages at the
  next; the control blocks and lists go to page 10
  (`r8025_map_ctl`), the receive frame buffer to pages 5..9.  And with
  `ring_8025_rif_sum_reversed` ring_8025_receive_frame's one sum in the
  other order.  The rest differs from the SAU8's only in the record's
  size and offsets and in addresses.
- Of the SAU8's routines only ring_8025_initialize,
  ring_8025_start_unit, RING_8025_$INT and ring_8025_rcv_process have
  source of their own (`ring_8025_dma_channel`,
  `ring_8025_no_data_bursts`); the others differ from the SAU9's only
  by the data block's and the auxiliary area's offsets and by the
  addresses of their callees.
- TODO(pascal): the size of a range of the unit's frame-type table
  (12 bytes apart, 10 copied by RING_8025_$SVC_CLOSE,
  RING_8025_$SVC_IOCTL and RING_8025_$PROC2_CLEANUP;
  `ring_8025.ins.pas`).
- TODO(pascal): 8 frame bytes of ring_8025_start_unit with
  `ring_8025_iomap` (`start_unit.pas`).
- The unit record's unused_ fields (the word after each exclusion lock,
  0x00A, 0x0F2 and the SAU7's 0x426) and the auxiliary area's are addressed by no routine
  of the module.
- The module does not include `mmu/mmu.ins.pas`: the SAU9's
  MMU_$REMOVE takes a second argument, and `ring_8025.ins.pas` declares
  the seven MMU routines the driver calls (as ETHERNET and WIN_SCSI do).
- The SAU9's interrupt routine makes the transfers the adapter asks for
  itself (the data word at 0, the byte at 2), a page at a time through
  the auxiliary area's map page; it hands the ring status and the
  adapter check to the receive process through the unit's flags 7..10.
- The adapter is reset through the control byte at 6 and polled for
  its bring-up diagnostics (ring_8025_reset); the eleven words of the
  initialization parameters go to the controller's memory at 0x0A00
  through the system interface (ring_8025_initialize).
