# The IIC subsystem in Domain Pascal

The internet interface controller's driver.  Where it is configured out
(the SR10.2 SAU2 and SAU4..SAU9 kernels) IIC_$INIT is empty and the
eight others are stubs that report "device not in system" (IIC_$EXISTS
and IIC_$RECEIVE_CHECK answer false).  With `iic_driver`
(`../base/config.ins.pas`: the SAU3) the driver of a controller on PBU
unit 6 with two lines; each line is a NET_IO port (port type 3) and a
channel for MAC_OS, has its own guardian process, and its own pages: a
command block shared with the controller, a transmit header and data
page, and a receive page.

## Layout

One module, `iic.pas`, `module iic;` (the map segment's name):

| section | SAU2 segment | SAU3 segment | routines | attribute |
|---------|--------------|--------------|----------|-----------|
| WIRED_PROC | none | IIC, 0xBC bytes | IIC_$EXISTS | `[section(wired_proc, wired_data)]` (SAU3) |
| OS_INIT_PROC | none | IIC, 0x74 bytes | IIC_$INIT | `[section(os_init_proc, os_init_data)]` (SAU3) |
| .TEXT (default) | IIC, 0xA0 bytes | IIC, 0xF2C bytes | SAU2: the nine stubs; SAU3: six module-local routines, CALL_GUARDIAN, iic_do_acquire, IIC_$ACQUIRE .. IIC_$SELF_TEST, iic_range_overlaps | none |
| PROC2_DELETE_PRO | none | IIC, 0x4C bytes | IIC_$PROC2_CLEANUP | `[section(proc2_delete_pro, proc2_delete_dat)]` |
| IIC_AQWRD_PROC | empty | IIC, 0xE10 bytes | iic_command (at IIC_$PROC_START), iic_map_iova, SEND_PACKET, iic_send_link, INTERRUPTER, IIC_$INT, GUARDIAN_PROCESS, IIC_$SENDP, iic_open_internal, IIC_$OPEN_OS, IIC_$CLOSE_OS, IIC_$SEND_OS | `[section(iic_aqwrd_proc, iic_aqwrd_data)]` |
| .DATA (default) | none | IIC data, 0xAC bytes | the driver's variables (`iic.pas`) | module variables |
| IIC_AQWRD_DATA | empty | IIC data, 8 bytes | IIC_$SENDP's static | routine static |
| IIC_AQWRD_DATA2 | none | no segment, 0x3B8 bytes | the two lines' records and the driver record | overlay section |
| IIC_$CONTROL_PAG | none | no segment, 0x2000 bytes | the lines' control pages (low region, no image bytes) | overlay section |

The SAU2 build compiles the `%else` arms, the nine stubs in the SAU2's
order, to the image's 0xA0 bytes.  The driver wires its IIC_AQWRD_PROC
code through its IIC_AQWRD_DATA data (IIC_$PROC_START .. IIC_$DATA_END,
layout marks of the build; IIC_$PROC_END is the IIC_AQWRD_DATA2
section's start).  The routines that are stubs elsewhere keep one
fragment each, with an `%if iic_driver` arm; the headings are the
driver's (the stubs read none of their arguments).

The stub module is also `../domain-pascal/tests/conformance/iic.pas`
(byte-identical in `make conform`), which declares its own status
record and constant and groups the unread parameters; the tree's SAU2
build is byte-identical with the image's 0xA0 bytes.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| IIC_$EXISTS | `exists.pas` |
| IIC_$INIT | `init.pas` |
| iic_wire_driver | `wire_driver.pas` |
| iic_unwire_driver | `unwire_driver.pas` |
| iic_release_pbu | `release_pbu.pas` |
| iic_setup_pbu | `setup_pbu.pas` |
| iic_stop | `stop.pas` |
| iic_start | `start.pas` |
| CALL_GUARDIAN | `call_guardian.pas` |
| iic_do_acquire | `do_acquire.pas` |
| IIC_$ACQUIRE | `acquire.pas` |
| IIC_$NET_START | `net_start.pas` |
| IIC_$RELEASE | `release.pas` |
| IIC_$$RELEASE | `release_internal.pas` |
| IIC_$SEND | `send.pas` |
| IIC_$RECEIVE | `receive.pas` |
| IIC_$RECEIVE_CHECK | `receive_check.pas` |
| IIC_$STATISTICS | `statistics.pas` |
| IIC_$INT_STATISTICS | `int_statistics.pas` |
| IIC_$SELF_TEST | `self_test.pas` |
| iic_range_overlaps | `range_overlaps.pas` |
| IIC_$PROC2_CLEANUP | `proc2_cleanup.pas` |
| iic_command (at the map's IIC_$PROC_START) | `command.pas` |
| iic_map_iova | `map_iova.pas` |
| SEND_PACKET | `send_packet.pas` |
| iic_send_link | `send_link.pas` |
| INTERRUPTER | `interrupter.pas` |
| IIC_$INT | `int.pas` |
| GUARDIAN_PROCESS | `guardian_process.pas` |
| IIC_$SENDP | `sendp.pas` |
| iic_open_internal | `open_internal.pas` |
| IIC_$OPEN_OS | `open_os.pas` |
| IIC_$CLOSE_OS | `close_os.pas` |
| IIC_$SEND_OS | `send_os.pas` |

`iic.ins.pas` holds the statuses, the driver's records (the line
record, the command block and control register, the counters, the
packet-type table, the driver record) and the headings.

## Open items

- The TODO(pascal) in `send.pas`: IIC_$SEND's packet info record is
  filled from a 14-byte constant in the code, which the Pascal writes
  as field stores.
- IIC_$EXISTS passes PBU_$ACQUIRE_INT the first longword of IIC_$INT's
  code as the handler; the Pascal reads it through a pointer to the
  routine (`exists.pas`).
