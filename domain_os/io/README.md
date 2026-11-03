# The IO subsystem in Domain Pascal

The I/O manager's controller list, unit table and initialization.

## Layout

One module, `io.pas`, `module io_, wired_proc, wired_data;` (the map
segments' name), in three code sections:

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | 0x5D0 bytes (SAU3 0xB9C, SAU5 0xBB8) | CHK (misc/), IO_$GET_DCTE, the module-local io_$check_unit, IO_$ACQUIRE (with the nested int_ids_match) .. IO_$ALLOC | none (the heading's) |
| OS_INIT_PROC | 0x22C bytes (SAU3 0x278, SAU5 0x270, SAU9 0x4D0) | io_$build_dcte_list (module-local), io_$match_device (module-local, `prom_config_record`), IO_$INIT, IO_$LOG_SELF_TESTS (`prom_config_record`) | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ | 0x8C bytes (SAU3 0xA4, SAU5 0xB8) | IO_$GET_CONFIG | `[section(procedure$, data$)]` |

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

- `get_config.pas`: IO_$GET_CONFIG's form on the SAU4.
- `dctes.pas`: the DCTES blocks of the SAUs other than the SAU2, SAU3,
  SAU5 and SAU9.
- The SAU8's I/O map routines (IO_$ALLOC_MAP, IO_$FREE_MAP and
  IO_$FREE_MAP_REGION without the region list) are not written: the
  `pbu_driver` arms assume `io_regions`.
