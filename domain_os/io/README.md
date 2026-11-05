# The IO subsystem in Domain Pascal

The I/O manager's controller list, unit table and initialization.

## Layout

One module, `io.pas`, `module io_, wired_proc, wired_data;` (the map
segments' name), in three code sections:

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | 0x5D0 bytes (SAU3 0xB9C, SAU4 0xB7C, SAU5 0xBB8, SAU8 0x9F0) | CHK (misc/), IO_$GET_DCTE, the module-local io_$check_unit, IO_$ACQUIRE (with the nested int_ids_match) .. IO_$ALLOC | none (the heading's) |
| OS_INIT_PROC | 0x22C bytes (SAU3 0x278, SAU4 0x270, SAU5 0x270, SAU8 0x23C, SAU9 0x4D0) | io_$build_dcte_list (module-local), io_$match_device (module-local, `prom_config_record`), IO_$INIT, IO_$LOG_SELF_TESTS (`prom_config_record`) | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ | 0x8C bytes (SAU3 0xA4, SAU4 0xB4, SAU5 0xB8, SAU8 0xC8) | IO_$GET_CONFIG | `[section(procedure$, data$)]` |

Data: the map's IO_ data segment, 0x554 bytes in WIRED_DATA (0x684 on
the SAU5, with PBU_$EXCLUSION_LOCK a sixth map symbol), with five
map symbols (`define`d, extern in `io.ins.pas`, IO_$DCTE_LIST already
there from SYSBUS) and the module's own variables; the layout is in
`io.pas`'s header.  IO_$BUS_EPV is initialized with its image values,
SYSBUS_$INIT's and SYSBUS_$DEFINE_INT's addresses among them
(`addr(...)`); the dynamic DCTE area's bounds with DCTE_END's and
DCTE_START's addresses.

The hand-written IO_$TBLS data segment (PAGE_INIT) holds IO_$TRAP,
IO_$SAVED_OS_SP, IO_$USE_INT_STACK, IO_$COND_SWITCH_BACK and
IO_$FLIH_TAB (`io/m68k/*.s`); the static DCTEs and DEV_DCTES are the
DCTES data segment (`dctes.pas`, a module of data only).  Neither is
IO_'s; `io.ins.pas` declares IO_$TRAP (SYSBUS's) and DEV_DCTES,
DCTE_START and DCTE_END extern.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| CHK | `misc/chk.pas` (written with misc/): `io.pas` includes it; its heading is in `io.ins.pas` |
| IO_$GET_DCTE | `get_dcte.pas` |
| io_$build_dcte_list | `build_dcte_list.pas` (`internal`) |
| io_$match_device | `match_device.pas` (`internal`; `prom_config_record`) |
| IO_$INIT | `init.pas` |
| IO_$LOG_SELF_TESTS | `log_self_tests.pas` (`prom_config_record`) |
| IO_$GET_CONFIG | `get_config.pas` |
| IO_$TRAP | none: hand assembly (IO_$TBLS), in `sau2/` |
| IO_$USE_INT_STACK | none: hand assembly, `m68k/use_int_stack.s` |
| IO_$COND_SWITCH_BACK | none: hand assembly, `m68k/cond_switch_back.s` |
| io_$probe | none: hand assembly, `m68k/probe.s` |
| (data) | IO_'s block in `io.pas`; IO_$TBLS and DCTES are other units' |

The other eleven routines of IO_'s WIRED_PROC segment are translated
from the image:

| routine | fragment |
|---------|----------|
| io_$check_unit | `check_unit.pas` (`internal`; no A5 load, the callers') |
| IO_$ACQUIRE | `acquire.pas`, with the nested int_ids_match |
| IO_$RELEASE | `release.pas` |
| IO_$DEVICE_INTERRUPTING | `device_interrupting.pas` |
| IO_$CLEAR_PENDING | `clear_pending.pas` |
| IO_$DISABLE_DEVICE | `disable_device.pas` |
| IO_$ENABLE_DEVICE | `enable_device.pas` |
| IO_$MAP_CSR | `map_csr.pas` |
| IO_$UNMAP_CSR | `unmap_csr.pas` |
| IO_$XLATE_IOVA | `xlate_iova.pas` |
| IO_$ALLOC | `alloc.pas` (the stub, or with `pbu_driver` the body, `base/config.ins.pas`) |

On the SAUs with the PBU (`pbu_driver`; translated from the SAU5 image)
the segment has nine more, all in `%if pbu_driver` in `io.pas` (the
region list's two under `io_regions`):

| routine | fragment |
|---------|----------|
| IO_$ATTR_CNTL | `attr_cntl.pas` |
| io_$alloc_region | `alloc_region.pas` (`internal`, with the nested fits) |
| io_$free_region | `free_region.pas` (`internal`) |
| IO_$FREE | `free.pas` |
| io_$add_region | `add_region.pas` (`internal`) |
| io_$remove_region | `remove_region.pas` (`internal`) |
| IO_$ALLOC_MAP | `alloc_map.pas` |
| IO_$FREE_MAP | `free_map.pas` |
| IO_$FREE_MAP_REGION | `free_map_region.pas` |

The SAU5 forms of the others are conditional arms in their fragments:
IO_$RELEASE frees the unit's regions (`io_regions`), IO_$INIT builds
the region free list and calls PBU_$INIT and MT_$PRESENT (and not
DMA_$INIT), IO_$GET_CONFIG tests the SAU's controllers.  The data
block's SAU5 layout (0x684 bytes: three I/O maps, the bus vectors of
VME_ and MBUS_, PBU_$EXCLUSION_LOCK, eight region nodes) is in
`io.pas`'s header; `dctes.pas` has the SAU5 DCTEs (CTAPE_DCTE,
SMD_DCTE_1, SMD_DCTE_0, RING_DCTE, WIN_DCTE).  The parts are in
`base/config.ins.pas`; the other modules' headings IO_ needs on the SAU5
are at the end of `io.ins.pas` (TODO(merge)).

The SAU3's IO_ is the SAU5's source (`pbu_driver`, `io_regions` with
64 region nodes, `mbus_bus`) with the SAU2's `dma_driver` and
`sysbus_routines`: its WIRED_PROC segment is 0xB9C bytes, OS_INIT_PROC
0x278, the data block 0x9BC (two I/O maps, bus 2's and bus 4's;
PBU_$EXCLUSION_LOCK), DCTES 0xD0 (SMD_DCTE_1, SMD_DCTE_0, RING_DCTE).
Most routines differ from the SAU5's only in the block's offsets.  The
arms (`base/config.ins.pas`):

- `mbus_map_reserved`: the Multibus map's initial value holds one range,
  16#70000 .. 16#80000 (`io.pas`);
- `mbus_dev_routines` (the SAU5 only): IO_$BUS_EPV's Multibus entry has
  MBUS_$ENABLE_DEV and MBUS_$DISABLE_DEV; the SAU3's has neither;
- `pbu_alloc_mbus`: IO_$ALLOC allocates in the Multibus's map below 1 MB
  whatever the unit's bus (`alloc.pas`);
- `vme_bus`: IO_$ALLOC_MAP's refusal of a VME unit is compiled only with
  the VME bus (`alloc_map.pas`);
- `winchester_config`: no WIN_DCTE (`dctes.pas`, and DEV_DCTES's bound
  in `io.ins.pas`) and no CHK(0) in IO_$GET_CONFIG without it;
- `iic_port_config`, `pbu_config_always`: IO_$GET_CONFIG's config2
  member 2 for an active port of the internet interface controller
  (ROUTE_$PORT, `route/route.ins.pas`'s `route_$port_type_iic`) and
  config3 := [1] (`get_config.pas`).

On the SAU9 the block is 0x5B4 bytes: the I/O maps of bus 3 and bus 4
(`atbus_map` with `atbus_routines`), SCSI_$EXCLUSION_LOCK after IO_'s
own lock (`scsi_driver`), no region nodes.  IO_$UNMAP_CSR removes each
page by its virtual address (`large_vm`, MMU_$REMOVE's two-argument
form, declared in `io.pas` for those SAUs); IO_$GET_CONFIG adds the
Ethernet's member (`ethernet_driver`) and config3 := [3]
(`atbus_routines`).  The other unit routines are the SAU2's source.

On the SAU8 the block has the SAU9's shape with PBU_$EXCLUSION_LOCK in
SCSI_$EXCLUSION_LOCK's place (`pbu_driver` without `scsi_driver`), and
the routines are the SAU9's and the SAU5's sources but for these arms
(`base/config.ins.pas`):

- `io_regions` (not on the SAU8): IO_$ALLOC_MAP, IO_$FREE_MAP and
  IO_$FREE_MAP_REGION are stubs, status_$pbu_not_supported (and a 0
  result); IO_$RELEASE still calls IO_$FREE_MAP for a unit with regions
  (its test is under `pbu_driver`);
- `pbu_alloc_atbus_windows`: IO_$ALLOC refuses a range that is not fixed
  and puts an AT bus unit's range in the window of 16#80000..16#100000 or
  16#900000..16#1000000 that holds iova (`alloc.pas`);
- `named_dctes` with `floppy_disk`, `winchester_ctlr` and `ct_qic02`:
  FLP_DCTE and WIN8_DCTE of kind 3, whose request IO_$MAP_CSR maps, and
  a kind-2 CTAPE_DCTE (`dctes.pas`); DEV_DCTES ends with the COLOR4_,
  COLOR5_ and MONO_ drivers' DCTEs (`color4_driver`, `color5_driver`,
  `mono_driver`); IO_DESC has the tape's, the floppy's and the
  Winchester's descriptors too (`io_desc.pas`).

On the SAU4 the block has the SAU3's size and shape (0x9BC bytes, 64
region nodes) without its reserved Multibus range, IO_$INIT is the
SAU5's form, and the routines are the SAU3's sources but for these
arms:

- `pbu_alloc_mbus` with `mbus_map_64k`: IO_$ALLOC allocates in the
  Multibus's map below 16#10000; IO_$ALLOC_MAP's range is 16#0..16#10000
  for every unit, and the region's page is its start's page plus 192
  (`alloc.pas`, `alloc_map.pas`);
- `pbu_mcb_config` with `mcb_config_member_0`: IO_$GET_CONFIG reports
  PBU_$MCB's flag as member 0 of the third set;
- `floppy_dcte_request` and `sysbus_vectors_90`: FLP_DCTE of kind 3, with
  its request on the system bus, and the ring's and the Winchester's
  DCTEs with vector 16#90 (`dctes.pas`).

None is called in the SAU2 image (Ghidra's xrefs and a byte search of
the image file find no reference; the SVC tables do not name them).
On the SR10.2 SAU3 the user-device manager calls them (PBU_$SETUP
IO_$ACQUIRE, PBU_$SETDOWN IO_$RELEASE, PBU_$ALLOC IO_$ALLOC), with the
pushes the SAU2 bodies' slots imply.  The headings are `val_param` (a
word unit by value, the status by address).

What they are: a unit table, IO_$DCTES (32 slots of 0x20 bytes,
`io_$unit_entry_t`, from +0x118; despite the map's name), filled by
IO_$ACQUIRE from a request record (`io_$acquire_rec_t`: an interrupt
id and its flag, the CSR pages, a tag, the bus number) under the
exclusion lock at +0x518, and the per-bus routines of IO_$BUS_EPV
(`io_$bus_epv_t`: init, xlate_iova, define_int, enable_device,
disable_device, device_interrupting, clear_pending, csr_align).  The
field names of the vector are the bus routines' names in the other
SAUs' images (SAU9's ATBUS_$XLATE_IOVA ... ATBUS_$CLEAR_PENDING at
+4..+0x1C), and the bus numbers 1..4 are VME, MBUS, ATBUS and SYSBUS by
the modules whose routines fill the entries on the other SAUs.  On the
SAU2 only bus 4 has routines (SYSBUS_$INIT, SYSBUS_$DEFINE_INT); every
routine pointer the unit routines call through is nil but define_int.

The block's first 0x60 bytes: the I/O maps of the other SAUs' IO_$ALLOC
/ IO_$ALLOC_MAP, a pointer per bus number and, on the SAU2, one empty
map for bus 4 (`io_$iomap_area`, one record so that the pointer's
initializer can take the map's address).  `io.pas`'s header has the
reasoning (the SAU3 and SAU9 images have the same shape with two maps).

`io.ins.pas`: the unit routines' statuses (stcode.db.10.2's texts), the
bus numbers, io_$unit_num_t, the interrupt id, the request and slot
records, the bus routines' pointer types, the vector's fields, IO_$DCTES's
type and the ten headings; status_$io_controller_not_found and
status_$io_bad_dcte_length; dcte_t's csrsytr as the routine pointer type
`dcte_init_proc_t` (IO_$INIT calls through it); the configuration set;
the externs IO_$BUS_EPV, IO_$WIRING_EXCLUSION, IO_$IN_INIT, IO_$DCTES,
DEV_DCTES, DCTE_START, DCTE_END; the headings of CHK, IO_$GET_DCTE,
IO_$INIT and IO_$GET_CONFIG.  Include ml/ml.ins.pas before it (for
ml_$exclusion_t).  `sysbus/sysbus.ins.pas`: SYSBUS_$DEFINE_INT has the
three by-value parameters of the vector's define_int type (its body
never reads them), so the sysbus insert needs io.ins.pas before it.
`io.pas` includes `proc1/proc1.ins.pas` (PROC1_$CURRENT).

Changes to other shared insert files: `ml/ml.ins.pas` (ml_$exclusion_t,
ML_$EXCLUSION_INIT), `mmu/mmu.ins.pas` (MMU_$VTOP).

## The SAU6

The SAU6's IO_ (WIRED_PROC 0xB9C bytes, OS_INIT_PROC 0x26C, PROCEDURE$
0xD4, the data block 0x684) is the SAU5's logic in 68020 code, with the
SAU6's configuration words (no floppy, the Ethernet's `chk(6)`): no
source change.  Its DCTES block (0x268 bytes) is the kind-1 form with
nine DCTEs: two Ethernets (`ethernet_driver` without `named_dctes`), the
second tape and Winchester controller's CTAPE6_DCTE and WIN6_DCTE
(`win6_ct6_board`), and the SAU5's CTAPE_DCTE, SMD_DCTE_1, SMD_DCTE_0,
RING_DCTE and WIN_DCTE, their vectors `sysbus_vectors_88`'s (16#88 the
ring, 16#8C the Winchester and the tape, 16#90 the second pair, 16#F5
and 16#F6 the Ethernets) in disk_error_que's low byte; DEV_DCTES lists
the nine and nil (io_$dev_dctes_last 9).  The hand-written IO_$TBLS is
the SAU2's; IO_$PROBE clears bit 6 of the MMU's status byte
(`mmu_status_bit_6`), waits with two calls after a completed access
(`probe_settle_calls`) and leaves the VME state to FIM_$BUS_ERR
(`fim_vme_ack`).

## The SAU7

The SAU7's DCTES block (0x3A4 bytes) is the SAU8's with three more
DCTEs: WIN7_DCTE_1 and WIN7_DCTE_0 (`win_mailbox_ctlr`), of kind 3 with
their requests' attribute bit 0 set, before WIN8_DCTE, and SCSI7_DCTE
(`scsi_mailbox_ctlr`), of kind 2 with its I/O descriptor, after it, a
zero longword after each kind-3 DCTE that another follows; DEV_DCTES
lists SCSI7_DCTE, WIN8_DCTE and the two WIN7_ DCTEs first and has
COLOR6's three units' (`color6_driver`) and COLOR7's DCTE
(`color7_driver`) among the display drivers' (io_$dev_dctes_last 24).
The per-target SCSI DCTEs and SCSI9_DCTE are the NCR 53C90 driver's, not
the mailbox adapter's, though `ct_scsi` is on.

IO_ (WIRED_PROC 0xC54 bytes, OS_INIT_PROC 0x268, PROCEDURE$ 0xC8, the
data block 0x9D4) has the region list (`io_regions`) and the SAU8's AT
bus arms (`pbu_alloc_atbus_windows`), and `io_atbus_map_windows`:
IO_$ALLOC allocates an iova of 0 anywhere in the AT bus's first 16#80000
and its second window is 16#100000..16#1000000; IO_$ALLOC_MAP allocates
only for an AT bus unit, a bus master (`io_$attr_bus_master`) in the
map's first 16#80000, another from 16#80000 to 16#90000 (16#A0000 with
`io_$attr_wide_iomap`).  The other routines are the existing source.  IO_DESC (0x1A0 bytes) is
the SAU8's with SCSI_IO_DESC first and WIN7_IO_DESC before WIN_IO_DESC.

The hand-written IO_$TBLS (IO_$TRAP, IO_$SAVED_OS_SP, IO_$USE_INT_STACK,
IO_$COND_SWITCH_BACK, the first-level handler table) and TESTPAGE
(`m68k/`) assemble to the SAU7 image's bytes.

## Open items

### Form

- IO_$INIT's skips (`continue`s in another rendering) are nested `if`s
  in the image.
- IO_$GET_DCTE's and IO_$INIT's list walks are `if p <> nil then repeat
  ... until p = nil` in the image's shape.
- IO_$INIT's first parameter is never read; OS_$INIT passes a longword
  0 cell there.

### TODO(pascal)

- `check_unit.pas`: 4 frame bytes (stand-in `unused_c`; a lead: a word
  local for the tag).
- `acquire.pas`: 4 frame bytes not accounted for (no stand-in).
- `get_dcte.pas`: 8 frame bytes (stand-in `unused_14`).
- `build_dcte_list.pas`: 8 frame bytes (stand-ins `unused_8`,
  `unused_5c`).
- `init.pas`: 16 frame bytes (stand-ins `unused_18`, `unused_1c`).

### TODO(sau)

- `dctes.pas`: the DCTES block of the SAU7.
