# The SCSI subsystem in Domain Pascal

The SCSI driver in Domain Pascal: configured out of the SR10.2 SAU2
kernel (two stubs and one variable), and with `scsi_driver`
(`../base/config.ins.pas`: the SAU7 and SAU9) one of two drivers: the
NCR 53C90 driver, translated from the SAU9 (DN2500) image, or with
`scsi_mailbox_ctlr` the driver of a host adapter on the AT bus that
takes 32-byte command blocks through mailboxes, translated from the SAU7
(DN3500, DN4000) image.

## Layout

One module, `scsi.pas`, `module scsi_, scsi_wired_proc,
scsi_wired_data;` (the map segments' name):

| section | SAU2 segment | SAU9 segment | routines | attribute |
|---------|--------------|--------------|----------|-----------|
| OS_INIT_PROC | SCSI_, 0x10 bytes | SCSI_, 0x408 bytes | SAU2: SCSI_$CINIT; SAU9: SCSI_$INIT, SCSI_$CINIT, scsi_init_ppn_owners | `[section(os_init_proc, os_init_data)]` |
| OS_INIT_DATA | none | SCSI_, 4 bytes | (zero, never addressed; the section's A5 is its end) | |
| SCSI_WIRED_PROC | SCSI_, 4 bytes | SCSI_, 0x2640 bytes | SAU2: SCSI_$FREE_ASID (empty); SAU9: 26 module-local routines and SCSI_$ABORT_OPERATION .. SCSI_$DO_SYS_DEVICE_CMD | none (the heading's) |
| SCSI_WIRED_DATA | SCSI_, 4 bytes | SCSI_, 0x374 bytes | SCSI_$PRESENT; SAU9: the driver's variables (`scsi.pas`'s table) | module variables |

The map's SCSI_ASM segments (SAU9 only: SCSI_$HP_WRITE in WIRED_PROC,
0xB4 bytes; SCSI_$HP_READ in WIRED_DATA, 0x50 bytes, after a cell
holding UTIL_PIO's address) are hand assembly, `sau9/scsi_asm.s`.
SCSI_$PROC_START is a marker on the module's first routine
(scsi_find_req), SCSI_$PROC_END, SCSI_$DATA_START and SCSI_$DATA_END
markers of the data block.

The SAU7's segments: SCSI_ in OS_INIT_PROC, 0x4B4 bytes (SCSI_$CINIT,
scsi_init_ppn_owners); SCSI_ in SCSI_WIRED_PROC, 0x17F4 bytes (the
module-local routines and SCSI_$ABORT_OPERATION .. SCSI_$DO_SYS_DEVICE_CMD
with SCSI_$INT); SCSI_ data in SCSI_WIRED_DATA, 0x6B8 bytes, and 4 bytes
in OS_INIT_DATA.  `scsi.pas` compiles that form under
`scsi_mailbox_ctlr`; its declarations are `scsi_mbox.ins.pas`, and the
globals' fragments hold its arms (`%if scsi_mailbox_ctlr %then .. %else`
the 53C90's).  scsi_va_to_ppn, scsi_wire_driver, scsi_unwire_driver,
scsi_wire_page, scsi_unwire_page, scsi_unwire_all and
scsi_init_ppn_owners are the 53C90 driver's fragments, unchanged.

The SAU2 build compiles the `%else` arms (SCSI_$FREE_ASID's empty body)
and SCSI_$CINIT, the same stub on every SAU, to the image's bytes.

Insert files: `scsi.ins.pas` (SCSI_$PRESENT, SCSI_$CINIT's and
SCSI_$FREE_ASID's headings on every SAU; under `scsi_driver` the
SCSI manager's statuses, the handle, command block, result and info
records, the system device routine's type, and the globals' headings);
`scsi_c90.ins.pas` (new, the driver's own: SCSI messages, the 53C90's
commands, phases and registers, the request, target and bus records,
the map's SCSI_ variables and regions, and the two interrupt routines'
headings).  PARITY's DMA-channel headings are `../parity/parity.ins.pas`'s,
under `parity_dma_pages`.  SCSI_$INIT's
heading and SCSI_$EXCLUSION_LOCK (in IO_'s data block) are
`../io/io.ins.pas`'s, under `scsi_driver`.

## Routines and their fragments

Image order within each section.

| routine | fragment |
|---------|----------|
| SCSI_$INIT | `init.pas` |
| SCSI_$CINIT | `cinit.pas` (every SAU) |
| scsi_init_ppn_owners | `init_ppn_owners.pas` |
| scsi_find_req (at the map's SCSI_$PROC_START) | `find_req.pas` |
| scsi_free_req | `free_req.pas` |
| scsi_remove_done_req | `remove_done_req.pas` |
| scsi_get_req | `get_req.pas` |
| scsi_queue_req | `queue_req.pas` |
| scsi_va_to_ppn | `va_to_ppn.pas` |
| scsi_wire_driver | `wire_driver.pas` |
| scsi_unwire_driver | `unwire_driver.pas` |
| SCSI_$ABORT_OPERATION | `abort_operation.pas` |
| SCSI_$DO_COMMAND_PHYS | `do_command_phys.pas` |
| SCSI_$DO_COMMAND | `do_command.pas` |
| SCSI_$FREE_ASID | `free_asid.pas` (SAU2: an empty procedure, the `%else`) |
| SCSI_$SET_SYS_DEVICE | `set_sys_device.pas` |
| SCSI_$GET_EC | `get_ec.pas` |
| SCSI_$GET_INFO | `get_info.pas` |
| SCSI_$C90_INT | `c90_int.pas` |
| scsi_msg_in | `msg_in.pas` |
| scsi_msg_out | `msg_out.pas` |
| scsi_msg_in_start | `msg_in_start.pas` |
| scsi_status_start | `status_start.pas` |
| scsi_xfer_pad | `xfer_pad.pas` |
| scsi_start_dma | `start_dma.pas` |
| scsi_send_cdb | `send_cdb.pas` |
| scsi_phase_dispatch | `phase_dispatch.pas` |
| SCSI_$C90_DMA | `c90_dma.pas` |
| scsi_enable_select | `enable_select.pas` |
| scsi_finish_data | `finish_data.pas` |
| SCSI_$RELEASE | `release.pas` |
| SCSI_$RESET_DEVICE | `reset_device.pas` |
| SCSI_$SETUP | `setup.pas` |
| scsi_wire_page | `wire_page.pas` |
| scsi_unwire_page | `unwire_page.pas` |
| scsi_unwire_all | `unwire_all.pas` |
| SCSI_$UNWIRE | `unwire.pas` |
| SCSI_$WAIT | `wait.pas` |
| SCSI_$WIRE | `wire.pas` |
| scsi_complete_req | `complete_req.pas` |
| scsi_start_cmd | `start_cmd.pas` |
| scsi_start_abort | `start_abort.pas` |
| scsi_start_next | `start_next.pas` |
| SCSI_$DO_SYS_DEVICE_CMD | `do_sys_device_cmd.pas` |
| SCSI_$HP_WRITE | none: hand assembly, `sau9/scsi_asm.s` |
| SCSI_$HP_READ | none: hand assembly, `sau9/scsi_asm.s` |

With the mailbox host adapter, in image order:

| routine | fragment |
|---------|----------|
| SCSI_$CINIT | `cinit.pas` |
| scsi_init_ppn_owners | `init_ppn_owners.pas` |
| scsi_va_to_ppn (at the map's SCSI_$PROC_START) | `va_to_ppn.pas` |
| scsi_get_tinfo | `get_tinfo.pas` |
| scsi_get_slot | `get_slot.pas` |
| scsi_map_vue | `map_vue.pas` |
| scsi_wait_cmd_ready | `wait_cmd_ready.pas` |
| scsi_send_reset | `send_reset.pas` |
| scsi_wire_driver | `wire_driver.pas` |
| scsi_unwire_driver | `unwire_driver.pas` |
| scsi_alloc_iova | `alloc_iova.pas` |
| scsi_free_iova | `free_iova.pas` |
| scsi_map_buffer | `map_buffer.pas` |
| SCSI_$ABORT_OPERATION | `abort_operation.pas` |
| scsi_post_cmd | `post_cmd.pas` |
| SCSI_$DO_COMMAND_PHYS | `do_command_phys.pas` |
| SCSI_$DO_COMMAND | `do_command.pas` |
| SCSI_$FREE_ASID | `free_asid.pas` |
| SCSI_$SET_SYS_DEVICE | `set_sys_device.pas` |
| SCSI_$GET_EC | `get_ec.pas` |
| SCSI_$GET_INFO | `get_info.pas` |
| SCSI_$INT | `int.pas` |
| SCSI_$RELEASE | `release.pas` |
| SCSI_$RESET_DEVICE | `reset_device.pas` |
| SCSI_$SETUP | `setup.pas` |
| scsi_wire_page | `wire_page.pas` |
| scsi_unwire_page | `unwire_page.pas` |
| scsi_unwire_all | `unwire_all.pas` |
| SCSI_$UNWIRE | `unwire.pas` |
| SCSI_$WAIT | `wait.pas` |
| SCSI_$WIRE | `wire.pas` |
| SCSI_$DO_SYS_DEVICE_CMD | `do_sys_device_cmd.pas` |
