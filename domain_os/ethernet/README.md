# The ETHERNET module in Domain Pascal

The Ethernet controller driver.  Configured out of the SR10.2 SAU2
kernel: there the map's ETHERNET code segment (0x10 bytes) in the
ETHER_PROC section holds only `ETHERNET_$INIT`, which returns
status_$io_controller_not_in_system (the same code as SCSI_$CINIT).
With the driver (`ethernet_driver`, `base/config.ins.pas`), on the SAU9
(DN2500): the driver of the 3Com 3C505 (EtherLink Plus) adapter on the
AT bus, the map's ETHERNET code segment of 0x4684 bytes.

## Layout

One module, `ethernet.pas`, `module ethernet, ether_proc, ether_data;`
(the driver's block is module variables, through A5).

| section | contents |
|---------|----------|
| ETHER_PROC | the ETHERNET code segment: SAU2 0x10 bytes (ETHERNET_$INIT); SAU9 0x4684 bytes, SAU8 0x465C (43 module-local routines, two nested routines and the 22 map routines ETHERNET_$INIT .. ETHERNET_$RCV1) |
| ETHER_PROC (ETHERNET_ASM) | SAU9 and SAU8 0x80 bytes: ETHERNET_$$PIO_READ, ETHERNET_$$PIO_WRITE, hand assembly (`m68k/ethernet_asm.s`) |
| ETHER_DATA | SAU2 empty; SAU9 0xE0 bytes: the wired pages, the driver record, the ports, the wiring counts, the receive processes' table (`ethernet.pas` tables them) |
| ETHER_UCB | SAU9 0x2570 bytes: the two units' records (`ethernet_$unit_t`, 0x12B8 bytes each), an overlay section |
| ETHERNET_$BUFFER | SAU9 0x1000 bytes, an overlay section |

The driver's declarations are `ethernet_3c505.ins.pas` (statuses,
registers, command blocks, the unit and driver records, the headings);
`ethernet.ins.pas` keeps ETHERNET_$INIT's heading for both forms.

## Routines and their fragments (image order)

| routine | fragment |
|---------|----------|
| ethernet_swap32 | `swap32.pas` |
| ethernet_check_status | `check_status.pas` |
| ethernet_wire_driver | `wire_driver.pas` |
| ethernet_unwire_driver | `unwire_driver.pas` |
| ethernet_probe | `probe.pas` |
| ethernet_reset | `reset.pas` |
| ethernet_get_pcb | `get_pcb.pas` |
| ethernet_send_pcb | `send_pcb.pas` |
| ethernet_start_cmd | `start_cmd.pas` |
| ethernet_wait_cmd | `wait_cmd.pas` |
| ethernet_do_cmd | `do_cmd.pas` |
| ethernet_get_rcv_bufs | `get_rcv_bufs.pas` |
| ethernet_start_rcv | `start_rcv.pas` |
| ethernet_configure | `configure.pas` |
| ethernet_do_cmd_polled | `do_cmd_polled.pas` |
| ethernet_setup | `setup.pas` |
| ethernet_start_unit | `start_unit.pas` |
| ethernet_stop_rcv | `stop_rcv.pas` |
| ethernet_download | `download.pas` |
| ethernet_execute | `execute.pas` |
| ethernet_transmit | `transmit.pas` |
| drain (nested in ethernet_rcv_packet), ethernet_rcv_packet | `rcv_packet.pas` (the first nested, before its parent) |
| ethernet_arp_request | `arp_request.pas` |
| ethernet_arp_reply | `arp_reply.pas` |
| ethernet_arp_find | `arp_find.pas` |
| ethernet_arp_input | `arp_input.pas` |
| ethernet_arp_resolve | `arp_resolve.pas` |
| ethernet_range_overlaps | `range_overlaps.pas` |
| ethernet_find_adjacent | `find_adjacent.pas` |
| ethernet_find_range | `find_range.pas` |
| ethernet_rtn_bufs | `rtn_bufs.pas` |
| ethernet_demux | `demux.pas` |
| ethernet_mcast_listed | `mcast_listed.pas` |
| ethernet_mcast_add | `mcast_add.pas` |
| ethernet_load_mcast | `load_mcast.pas` |
| ethernet_read_stats | `read_stats.pas` |
| ETHERNET_$INIT | `init.pas` |
| ETHERNET_$START | `start.pas` |
| ETHERNET_$STOP | `stop.pas` |
| ETHERNET_$LOAD | `load.pas` |
| ETHERNET_$SEND | `send.pas` |
| ETHERNET_$GET_STATS | `get_stats.pas` |
| ETHERNET_$GET_STATS2 | `get_stats2.pas` |
| ETHERNET_$IOCTL | `ioctl.pas` |
| ethernet_open | `open.pas` |
| ETHERNET_$SVC_OPEN | `svc_open.pas` |
| ETHERNET_$SVC_CLOSE | `svc_close.pas` |
| ethernet_copy_to_user | `copy_to_user.pas` |
| ETHERNET_$SVC_READ | `svc_read.pas` |
| ethernet_copy_data | `copy_data.pas` |
| ETHERNET_$SVC_WRITE | `svc_write.pas` |
| set_station (nested in ETHERNET_$SVC_IOCTL), ETHERNET_$SVC_IOCTL | `svc_ioctl.pas` (the first nested, before its parent) |
| ETHERNET_$PROC2_CLEANUP | `proc2_cleanup.pas` |
| ETHERNET_$OPEN_OS | `open_os.pas` |
| ETHERNET_$CLOSE_OS | `close_os.pas` |
| ETHERNET_$SEND_OS | `send_os.pas` |
| ethernet_start_rcv_cond | `start_rcv_cond.pas` |
| ethernet_arp_input_cond | `arp_input_cond.pas` |
| ethernet_demux_int | `demux_int.pas` |
| ethernet_get_rcv_bufs_cond | `get_rcv_bufs_cond.pas` |
| ETHERNET_$INT_DEFERRED | `int_deferred.pas` |
| ETHERNET_$INTERRUPT | `interrupt.pas` |
| ethernet_rcv_process | `rcv_process.pas` |
| ETHERNET_$RCV0 | `rcv0.pas` |
| ETHERNET_$RCV1 | `rcv1.pas` |
| ETHERNET_$$PIO_READ | none: hand assembly, `m68k/ethernet_asm.s` |
| ETHERNET_$$PIO_WRITE | none: hand assembly, `m68k/ethernet_asm.s` |

The receive path: ETHERNET_$INTERRUPT reads the adapter's block and
queues ETHERNET_$INT_DEFERRED (DI_$ENQ), which reads and delivers the
packet without waiting (the `_cond` and `_int` locals); what needs a
held lock or the process level is left in the unit's receive state for
the unit's receive process (ETHERNET_$RCV0, _RCV1, ethernet_rcv_process),
woken through the eventcount ETHERNET_$INT_DEFERRED returns.

## Open items

- SAU6, SAU7 and SAU8 have the driver too (0x48BC, 0x4660, 0x465C
  bytes); `tools/sau_catalog.py` puts the SAU7, SAU8 and SAU9 forms of
  most routines in one family, the SAU6's apart.  The SAU7, SAU8 and
  SAU9 segments hold the same 67 routines in the same order.  The
  SAU8's differ from the SAU9's in ETHERNET_$INTERRUPT, which leaves the
  command interrupt alone (`ethernet_int_unmasked`, the SAU7's too),
  and in the polling loops' counts (`ethernet_short_polls`: the reset,
  the program's start, a command block's bytes and answer, a reply's
  bytes, and ETHERNET_ASM's waits); the SAU7's counts are larger again
  (7500000, 87500, 50000 and 312500, 17500), not translated.  The
  rest is the SAU9's code but for addresses.
- TODO(pascal): the unit record's undecoded places
  (`ethernet_3c505.ins.pas`); the configure-memory command's 12-byte
  constant (`setup.pas`); the stand-in locals of ethernet_rtn_bufs,
  ethernet_arp_input, ethernet_read_stats and ETHERNET_$SEND_OS (frame
  bytes no instruction addresses, in the SAU7 and SAU8 copies of the
  routines either); MMU's SAU9 headings, declared in
  `ethernet_3c505.ins.pas` (MMU_$REMOVE's two-argument form) until
  `mmu/mmu.ins.pas` has that form.
- NET_IO_$PUT_IN_SOCK_INT is a boolean function (its one caller,
  ethernet_demux_int, tests the result); `net_io/put_in_sock_int.pas`.
- The driver keeps its own ARP cache (64 rows of 4 entries, RFC 826
  packets of Ethernet and Domain addresses): a node not yet resolved is
  sent to 08-00-1E and its node ID's low 24 bits, and its requests go to
  Apollo's multicast 09-00-1E-00-00-01.
- The adapter's program (/sys/ethernet8_microcode) is loaded by
  ETHERNET_$LOAD and by the first channel's open; a failure is logged
  (LOG_$ADD entry type 13) and the unit goes on without it.
- ETHER_PROC_START, ETHER_PROC_END (zero longwords) and ETHER_DATA_START,
  ETHER_DATA_END are layout marks, not this module's objects; the SAU9
  driver wires the pages from one to the other.
