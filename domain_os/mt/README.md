# The MT subsystem in Domain Pascal

The magnetic tape driver, configured out of the SR10.2 SAU2 kernel and
present on the SAU3..SAU6 (the part `mt_driver`,
`../base/config.ins.pas`). The SAU5 driver is being translated routine
by routine.

## Layout

Two modules: `mt.pas`, `module mt, , wired_data;`, and on the SAUs with
the driver `mt_sio.pas`, `module mt_$sio;` (the map's MT_$SIO code
segment in .TEXT, 0x2C0 bytes on the SAU5, no data; an empty object
elsewhere).  `mt.pas`'s sections:

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT (default) | MT, 4 bytes (SAU2) | MT_$RELEASE (an empty procedure, then the filler) | none |
| .TEXT (default) | MT, 0x1448 bytes (SAU5) | so far mt_$shutdown, mt_$queue_request, mt_$release_unit (module-local), MT_PURGE_UCB, MT_$ACQUIRE (with init_unit and mt_$set_iomap, nested), MT_$CHAIN_READ, MT_$CHAIN_WRITE, MT_$CONTROL, MT_$ERASE, MT_$PRESENT, MT_$PURGE_PB, MT_$READ, MT_$RELEASE, MT_$SET_MODE, MT_$SPACE, MT_$UNWIRE, MT_$WAIT, MT_$WIRE, MT_$WRITE | none |
| WIRED_DATA | MT data, 0x54 bytes (SAU5) | the wired pages' list and count (zero) | `module mt, , wired_data;` |

The heading names wired_data on every SAU; the SAU2 module has no
variables, so that changes nothing there (byte-identical).

On the SAU2 no data: the map has no MT data segment; MT_$DATA_START and
MT_$DATA_END (at one address) are markers of an empty area, and the map's MT_PAGE is
an empty section.  The map's MT_END_ADDR segment (four zero bytes holding
the markers MT_$PROC_START and MT_$PROC_END) is not compiled code: hand
assembly, `m68k/end_addr.s` (MT_$PROC_END; MT_$PROC_START is a layout
mark).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| mt_$shutdown (module-local) | `shutdown.pas` (SAU5) |
| mt_$queue_request (module-local) | `queue_request.pas` (SAU5) |
| mt_$release_unit (module-local) | `release_unit.pas` (SAU5) |
| MT_PURGE_UCB | `purge_ucb.pas` (SAU5) |
| MT_$ACQUIRE, init_unit (nested) | `acquire.pas` (SAU5) |
| mt_$set_iomap (nested in MT_$ACQUIRE) | `set_iomap.pas`, included by `acquire.pas` (SAU5; the long_iomap part) |
| MT_$CHAIN_READ | `chain_read.pas` (SAU5) |
| MT_$CHAIN_WRITE | `chain_write.pas` (SAU5) |
| MT_$CONTROL | `control.pas` (SAU5) |
| MT_$ERASE | `erase.pas` (SAU5) |
| MT_$PRESENT | `present.pas` (SAU5) |
| MT_$PURGE_PB | `purge_pb.pas` (SAU5) |
| MT_$READ | `read.pas` (SAU5) |
| MT_$SET_MODE | `set_mode.pas` (SAU5) |
| MT_$SPACE | `space.pas` (SAU5) |
| MT_$UNWIRE | `unwire.pas` (SAU5) |
| MT_$WAIT | `wait.pas` (SAU5) |
| MT_$WIRE | `wire.pas` (SAU5) |
| MT_$WRITE | `write.pas` (SAU5) |
| MT_$SIO | `sio.pas` (SAU5; the MT_$SIO module, `mt_sio.pas`) |
| MT_$GET_IOVA | `get_iova.pas` (SAU5; the MT_$SIO module, `mt_sio.pas`) |
| MT_$RELEASE | `release.pas` (SAU2: an empty procedure; SAU5: the mt_driver arm) |
| MT_$PROC_END | none: hand assembly, `m68k/end_addr.s` |

`mt.ins.pas` holds MT_$RELEASE's heading: three parameters by address,
from its one caller PROC2_$CLEANUP_HANDLERS_INTERNAL (two constant
cells, -1 and 1, and its status), `in unit: integer; in mode: integer;
out status_ret: status_$t`.  dpc compiles the module to the image's 4
bytes.

## Against the conformance unit

`../domain-pascal/tests/conformance/mt_release.pas` (not modified) has
the same heading modes and types, body and section.  It differs only in
the status parameter's name (`status` there, `status_ret` here) and in
declaring its own status_$t (an integer32 record) where this uses
base/base.ins.pas's, Apollo's.

Under `mt_driver`, `mt.ins.pas` adds the TESTPAGE kind, the PBU unit,
MT_$SCB's flags word (a set and a packed record over one word), the
register page at PBU_MT_PAGE, the two externals, and PBU_$DISABLE_DEVICE's
heading (TODO(merge): its home is `../pbu/pbu.ins.pas`).
MT_$PRESENT's heading is `../io/io.ins.pas`'s until the merge
(TODO(merge) there); its home is `mt.ins.pas`.

## Open items

- TODO(merge): the headings of PBU_$DISABLE_DEVICE, PBU_$ENABLE_DEVICE,
  PBU_$SAVE_PPN, PBU_$FREE, PBU_$DELETE_PPN, PBU_$RELEASE_INT,
  PBU2_$UNWIRE, PBU2_$WIRE and PBU_$WAIT, and
  status_$pbu_page_already_wired (`mt.ins.pas`); IOMAP, repeated from
  `../sm/sm.ins.pas` (`mt.ins.pas`).
- TODO(sau): mt_$set_iomap's word form for the SAU3 and SAU4
  (`set_iomap.pas`).
