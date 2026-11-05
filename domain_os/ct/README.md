# The CT subsystem in Domain Pascal

The cartridge tape driver: configured out of the SR10.2
SAU2..SAU4 kernels (an empty CT_$RELEASE), and with `ct_driver`
(`../base/config.ins.pas`: the SAU5..SAU9) the driver in one of two
forms:

- the QIC-02 driver (`ct_qic02`), a QIC-02 drive behind the DN550/560's
  disk/tape controller, translated from the SAU5 image;
- the SCSI tape driver (`ct_scsi`), a SCSI tape drive (target 0 of bus
  0) driven through the SCSI_ driver (`../scsi/`), translated from the
  SAU9 image;
- the QIC-02 driver of an AT bus adapter (`ct_qic02` with
  `ct_atbus_qic02`): the adapter's ports, the drive's six status bytes,
  a DMA_ channel and a PBU unit's interrupt, translated from the SAU8
  image;
- both drivers in one module (`ct_scsi` with `ct_qic02` and
  `ct_atbus_qic02`): each global runs the SCSI driver's code for a drive
  CT_$ACQUIRE found on the SCSI bus and the AT bus adapter's otherwise,
  the adapter's DMA through the AT bus's I/O map (`ct_iomap`),
  translated from the SAU7 image;
- the QIC-02 driver of the turbo boards (`ct_qic02` with
  `ct_vectored_ctlr`, `ct_wait_ends_busy`, `ct_owner_test_reversed` and
  `win6_ct6_board`): the controller interrupts on its DCTE's vector, and
  a second controller on the WIN6 page, found by CT6_$CINIT, takes the
  tape's commands in the WIN6_ driver's command blocks (CT6_$INT ends
  them), translated from the SAU6 image.

## Layout

One module, `ct.pas`, `module ct;` (the map segment's name):

| section | SAU2 segment | SAU5 segment | SAU9 segment | routines | attribute |
|---------|--------------|--------------|--------------|----------|-----------|
| .TEXT (default) | CT, 4 bytes | CT, 0xDC0 bytes | CT, 0x130C bytes | SAU2: CT_$RELEASE (empty); SAU5: five module-local routines, CT_WAIT, RESET_DRIVE, DO_CTL_CMD, CT_$ACQUIRE, CT_$CONTROL, CT_$DIAG, CT_$READ, CT_$RELEASE, CT_$WAIT, CT_$WRITE, CT_$INT; SAU9: nine module-local routines, SCSI_WAIT, CT_$ACQUIRE .. CT_$WRITE (four with a nested routine) | none |
| OS_INIT_PROC | none | CT, 0x74 bytes | CT, 0x10 bytes | CT_$CINIT | `[section(os_init_proc, os_init_data)]` |

The SAU8's segments: CT in .TEXT, 0x136C bytes (six module-local
routines, CT_WAIT, RESET_DRIVE, DO_CTL_CMD, ct_transfer, CT_$ACQUIRE ..
CT_$INT); CT in OS_INIT_PROC, 0xC8 bytes (CT_$CINIT); CT data, 0xD44
bytes.  The shared fragments hold its arms under `ct_atbus_qic02`
(`%elseif` after the SCSI arm); ct_wait_ready, ct_status_cmd and
ct_read_status are its own.
| .DATA (default) | none | CT data, 0xD18 bytes | CT data, 0xD8C bytes | the driver's variables and the QIC-02 drive status table | module variables |

The SAU6's segments: CT in .TEXT, 0x1464 bytes (the SAU5's routines
with ct6_map_cmd and ct6_decode_status after ct_check_unit and CT6_$INT
after CT_$ACQUIRE); CT in OS_INIT_PROC, 0x174 bytes (CT_$CINIT,
CT6_$CINIT); CT data, 0xD64 bytes (`ct.pas`).  The QIC-02 fragments hold
the second controller's arms under `win6_ct6_board`, each a test of
ct6_page at run time.

The SAU7's segments: CT in .TEXT, 0x2684 bytes (the SAU9's module-local
routines and SCSI_WAIT, then the SAU8's from ct_wait_ready to
ct_transfer with ct_bus_address before it, the globals with the SCSI
driver's nested routines, CT_$INT); CT in OS_INIT_PROC, 0xE4 bytes
(CT_$CINIT); CT data, 0x15B8 bytes, both forms' variables in one order
(`ct.pas`).  The SCSI arms of the globals' fragments hold the QIC-02
code under `%if ct_qic02` (an `else` of the SCSI driver's test); CT_WAIT
and ct_transfer have arms under `ct_iomap`, CT_$CINIT one for both
drivers, and ct_scsi_reset's delay loop is `ct_reset_delay` (the
SAU9's).

The SAU2 build compiles the `%else` of `ct_driver` (CT_$RELEASE's empty
body) to the image's 4 bytes.  The map's CT_END_ADDR segment is hand
assembly, `m68k/end_addr.s` (the same on every SAU); CT_$PROC_START is
a marker at the module's first byte.

The two forms share the data block's middle and end (the wired page
lists, the status table, the DCTE, the owner, the flags), which the
SAU9's block keeps at the SAU5's relative places, with the SCSI
driver's command blocks and answers at its start and its own words
inserted (`ct.pas`).  The globals' fragments hold an arm per form
(`%if ct_scsi %then .. %else`); the module-local routines of each form
have fragments of their own, but for `touch_pages.pas`,
`unwire_pages.pas` and `check_unit.pas`, which both forms share
(`check_unit.pas` with an arm for its compare's operand order).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| ct_touch_pages (at the map's CT_$PROC_START) | `touch_pages.pas` |
| ct_unwire_pages | `unwire_pages.pas` |
| ct_check_unit | `check_unit.pas` |
| ct6_map_cmd (QIC-02, second controller) | `ct6_map_cmd.pas` |
| ct6_decode_status (QIC-02, second controller) | `ct6_decode_status.pas` |
| ct_decode_status (QIC-02) | `decode_status.pas` |
| ct_wait_ready (AT bus adapter) | `wait_ready.pas` |
| ct_status_cmd (AT bus adapter) | `status_cmd.pas` |
| ct_read_status (AT bus adapter) | `read_status.pas` |
| CT_WAIT (QIC-02) | `ct_wait.pas` |
| RESET_DRIVE (QIC-02) | `reset_drive.pas` |
| DO_CTL_CMD (QIC-02) | `do_ctl_cmd.pas` |
| ct_bus_address (I/O map) | `bus_address.pas` |
| ct_transfer (QIC-02) | `transfer.pas` |
| ct_to_24 (SCSI) | `to_24.pas` |
| ct_from_24 (SCSI) | `from_24.pas` |
| ct_init_cdb (SCSI) | `init_cdb.pas` |
| ct_request_sense (SCSI) | `request_sense.pas` |
| SCSI_WAIT (SCSI) | `scsi_wait.pas` |
| ct_scsi_reset (SCSI) | `scsi_reset.pas` |
| ct_scsi_transfer, its nested build_entry and do_xfer (SCSI) | `scsi_transfer.pas` |
| ct_scsi_control (SCSI) | `scsi_control.pas` |
| CT_$ACQUIRE (SCSI: nested ct_scsi_open) | `acquire.pas` |
| CT6_$INT (QIC-02, second controller) | `ct6_int.pas` |
| CT_$CONTROL (SCSI: nested ct_scsi_control_op) | `control.pas` |
| CT_$DIAG (SCSI: nested ct_scsi_diag) | `diag.pas` |
| CT_$READ | `read.pas` |
| CT_$RELEASE (SCSI: nested ct_scsi_release; SAU2: an empty procedure, the `%else`) | `release.pas` |
| CT_$WAIT (SCSI: nested ct_scsi_wait_op) | `wait.pas` |
| CT_$WRITE | `write.pas` |
| CT_$INT (QIC-02) | `int.pas` |
| CT_$CINIT | `cinit.pas` |
| CT6_$CINIT (QIC-02, second controller) | `ct6_cinit.pas` |
| CT_$PROC_END | none: hand assembly, `m68k/end_addr.s` |

`ct.ins.pas` holds CT_$RELEASE's heading (every SAU), under `ct_driver`
the cartridge tape statuses, the QIC-02 controller's commands,
CT_$CONTROL's operations and CT_$DIAG's modes, the window's and the
lists' types, the wired range's markers, and the globals' headings, and
under `ct_scsi` the SCSI tape driver's constants (its SCSI commands, its
own control operations, its time-outs), the sense and mode answers'
types, and SCSI_WAIT's heading.  The second controller's constants and
types (its command block and page, its command map's entry) are
`ct.pas`'s, under `win6_ct6_board`, which only the module uses; CT6_$INT's
and CT6_$CINIT's headings are `../io/io.ins.pas`'s.  Some of those are declared elsewhere
until the merge: CT_$CINIT
and CT_$INT in `../io/io.ins.pas` (CT_$INT under `ct_qic02`),
CT_$ACQUIRE, CT_$CONTROL, CT_$READ, CT_$WAIT and two statuses in
`../tape/tape.ins.pas`.

## Open items

- TODO(merge): the headings' home (above).
