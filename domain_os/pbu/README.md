# The PBU subsystem in Domain Pascal

The processor bus unit support in Domain Pascal: configured out of the
SR10.2 SAU2 and SAU9 kernels but for its eventcount pool, and the
user-device manager with `pbu_driver` (`../base/config.ins.pas`: the
SAU3..SAU8), translated from the SAU5, SAU3 and SAU8 images.

## Layout

| module file | map module | section | SAU2 | SAU3 | SAU5 |
|-------------|-----------|---------|------|------|------|
| `pbu.pas`, `module pbu;` | PBU | .TEXT | 0x18 bytes: PBU_$FREE_ASID (empty), PBU_$FAULTED_UNITS, PBU_$INIT (empty) | 0x1ADC bytes: four module-local routines (one nested) and 32 globals | 0x1FC0 bytes: five module-local routines (two nested) and 32 globals |
| `pbu.pas` | PBU | .DATA | none | 0x5C bytes, as the SAU5's | 0x5C bytes: the PBU page's wired pages, their count, the default transfer control |
| `ec2_pbu.pas`, `module ec2_pbu, pbu_wired_proc, pbu_wired_data;` | EC2_PBU | PBU_WIRED_PROC, PBU_WIRED_DATA | 0x60 + 0x300 bytes | the same | the same |
| `pbu_map.pas`, `module pbu_map, pbu_wired_proc, pbu_wired_data;` | PBU_MAP | PBU_WIRED_PROC, PBU_WIRED_DATA | none (empty object) | 0x450 bytes, the SAU5's routines with word I/O map entries; 0xC bytes of data | 0x44C bytes: two module-local routines, the DMA entries, PBU2_$MAP, PBU2_$UNMAP, PBU_$WAIT; 0xC bytes of data |
| `sau3/pbu_asm.s`, `sau5/pbu_asm.s` | PBU_ASM | PBU_PAGE (data) | none | 0x7A4 bytes, hand assembly: the SAU5's with 8 units and PBU_$GET_STATUS | 0x770 bytes, hand assembly: SM_$CB, PBU_$MCB, PBU_$INT_COM, PBU_$TRAP6, PBU_$DCTES, PBU_$DCTE_TABLE and the DCTEs, PBU_$ENABLE_DEVICE ... |

EC2_PBU has a 0x300-byte data segment in PBU_WIRED_DATA: EC2_$PBU_ECS
(32 records of 0x18 bytes, zero), a `define`d variable (extern in
`pbu.ins.pas`); PBU_$DATA_END is a marker.  The map's PBU_MAP module
(the SAU3..SAU8, exactly `pbu_driver`'s SAUs) is `pbu_map.pas`, whose
whole body is under `pbu_driver`; PBU_$PAGE_END, the map's symbol at its
first byte, is a marker.  The map's
PBU_TABLES data segment (PBU_$PPN_OWNERS, 0x1C00 bytes on the SAU5) is
a fixed address of the low region with no bytes in the image: the SAU5
linker script's, when there is one.

`ec2_pbu.pas` is a second module file of this subsystem;
`tools/pascal_check.sh`'s default list takes, besides
`<sub>/<sub>.pas`, every other `.pas` of a subsystem with a line
starting `module `.  `sau5/pbu_asm.s` is assembled by the Makefile's
`*/$(TARGET_SAU)/*.s` for a SAU5 build only, `sau3/pbu_asm.s` for a
SAU3 build; the bytes of each were checked against its image by linking
it alone at its address.

The SAU3's PBU is the SAU5's source with the parts of
`../base/config.ins.pas` ("The PBU units"): without `vme_bus` there are
no VME units, windows or refusals (PBU_$SETUP, PBU_$SETDOWN,
PBU2_$ASSOC and its nested window_free, PBU2_$ALLOCATE_MAP,
PBU_$CONTROL, PBU2_$WIRE_MAP, PBU_$DISSOC, PBU_$INIT); `pbu_8_units`
gives 8 units and a byte of owners per page (`pbu.ins.pas`); without
`long_iomap` an I/O map entry is a word and a unit's control its high
word (PBU_$CONTROL, PBU2_$WIRE_MAP, pbu_clear_iomap, PBU2_$MAP,
PBU2_$UNMAP); without `pbu_wire_special` PBU_$WIRE_SPECIAL only refuses.
The other routines are the SAU5's code.

The SAU8's PBU (0x18F0 bytes of code, 0x58 of data; PBU_MAP 0x5F4) is
the SAU5's source with its parts: the AT bus's units
(`pbu_atbus_units`: PBU_$SETUP's CSR pages as groups of 8 I/O ports, 16
DCTEs, PBU2_$ASSOC's AT bus unit, the CSR routines without TESTPAGE,
PBU_$WIRE_SPECIAL's contiguous buffer and its nested release_pages,
PBU_$SHUTDOWN's kept unit 3, PBU_$NONSYS_DEVICE, the PBU_MAP DMA entries
on the AT bus's DMA channels and pbu_map_dma_error); the large virtual
memory's I/O page mapping (`large_vm`); no Multibus (`mbus_bus`), no
transfer control (`pbu_transfer_control`: PBU_$CONTROL a stub, no
pbu_default_ctl), no I/O map space (`io_regions`: no pbu_clear_iomap,
PBU2_$ALLOCATE_MAP, PBU_$FREE_MAP, PBU2_$WIRE_MAP, PBU2_$MAP and
PBU2_$UNMAP stubs), no storage module (`smd_disk`), the PBU page wired
by OS_$INIT (`pbu_wire_at_boot`), PBU_$PPN_OWNERS from page 16#400
(`mmap_ppns_400`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| pbu_check_unit (module-local) | `check_unit.pas` |
| PBU_$ACQUIRE_INT | `acquire_int.pas` |
| PBU_$ALLOC | `alloc.pas` |
| PBU_$ADVANCE_EC | `advance_ec.pas` |
| PBU_$ALLOCATE_EC | `allocate_ec.pas` |
| PBU2_$ALLOCATE_MAP | `pbu2_allocate_map.pas` |
| window_free (nested in PBU2_$ASSOC) | `pbu2_assoc.pas` |
| PBU2_$ASSOC | `pbu2_assoc.pas` |
| PBU_$CONTROL | `control.pas` |
| PBU_$DISSOC | `dissoc.pas` |
| pbu_clear_iomap (module-local) | `clear_iomap.pas` |
| PBU_$FREE | `free.pas` |
| PBU_$FREE_MAP | `free_map.pas` |
| PBU_$GET_DCTE | `get_dcte.pas` |
| PBU_$GET_EC | `get_ec.pas` |
| PBU_$GET_INFO | `get_info.pas` |
| PBU_$GET_PTR | `get_ptr.pas` |
| PBU_$RELEASE_EC | `release_ec.pas` |
| PBU_$RELEASE_INT | `release_int.pas` |
| PBU_$SETDOWN | `setdown.pas` |
| PBU_$SETUP | `setup.pas` |
| PBU_$SHUTDOWN | `shutdown.pas` |
| PBU2_$UNWIRE | `pbu2_unwire.pas` |
| PBU_$DELETE_PPN | `delete_ppn.pas` |
| PBU_$UNWIRE_USER_PAGES | `unwire_user_pages.pas` |
| PBU_$SAVE_PPN | `save_ppn.pas` |
| PBU2_$WIRE | `pbu2_wire.pas` |
| PBU2_$WIRE_MAP | `pbu2_wire_map.pas` |
| release_pages (nested in PBU_$WIRE_SPECIAL, SAU8) | `wire_special.pas` |
| PBU_$WIRE_SPECIAL | `wire_special.pas` |
| PBU_$WIRE_PBU | `wire_pbu.pas` |
| pbu_access_csr (module-local) | `access_csr.pas` |
| PBU_$READ_CSR | `read_csr.pas` |
| PBU_$WRITE_CSR | `write_csr.pas` |
| map_owner_pages (nested in PBU_$INIT) | `init.pas` |
| PBU_$INIT | `init.pas` (SAU2: an empty procedure, the `%else`) |
| PBU_$FREE_ASID | `free_asid.pas` (SAU2: an empty procedure) |
| PBU_$FAULTED_UNITS | `faulted_units.pas` |
| PBU_$ADVANCE_EC_INT | `advance_ec_int.pas` (module EC2_PBU; the SAU5's the same code) |
| pbu_map_check_unit (module-local, at the map's PBU_$PAGE_END) | `map_check_unit.pas` (module PBU_MAP) |
| pbu_map_owned_ppn (module-local) | `map_owned_ppn.pas` |
| pbu_map_dma_error (module-local, SAU8) | `map_dma_error.pas` |
| PBU_$DMA_START | `dma_start.pas` |
| PBU_$DMA_STOP | `dma_stop.pas` |
| PBU_$DMA_STATUS | `dma_status.pas` |
| PBU2_$DMA_START | `pbu2_dma_start.pas` |
| PBU2_$DMA_STOP | `pbu2_dma_stop.pas` |
| PBU2_$MAP | `pbu2_map.pas` |
| PBU2_$UNMAP | `pbu2_unmap.pas` |
| PBU_$WAIT | `wait.pas` |
| (data) | PBU_$DCTE_INT_PTR, PBU_$VME_DISABLE_COUNT are `pbu_map.pas`'s defined variables |
| (data) | PBU_$NONSYS_DEVICE (SAU8) is `pbu.pas`'s defined variable |
| PBU_$PAGE_START, SM_$CB, SM_$CNT, PBU_$MCB | none: hand assembly, `sau5/pbu_asm.s` |
| PBU_$INT_COM, PBU_$ADVANCE_ONLY, PBU_$IGNORE_INT, PBU_$USER_SPACE_DRIVER | none: hand assembly, `sau5/pbu_asm.s` |
| PBU_$TRAP6, PBU_$GET_DIAG_PTR, PBU_$INT_FAULT_COM | none: hand assembly, `sau5/pbu_asm.s` |
| SM_BLK_HDR, PBU_$DCTES, PBU_$DCTE_TABLE | none: hand assembly, `sau5/pbu_asm.s` |
| PBU_$DEVICE_INTERRUPTING, PBU_$DISABLE_DEVICE, PBU_$ENABLE_DEVICE | none: hand assembly, `sau5/pbu_asm.s` |
| PBU_ASM on the SAU3, PBU_$GET_STATUS | none: hand assembly, `sau3/pbu_asm.s` |
| (data) | EC2_$PBU_ECS is `ec2_pbu.pas`'s defined variable |

`pbu.ins.pas`, the home of every PBU declaration: the statuses, the
DDF, DCTE, control and set types, PBU_$MCB, PBU_$DCTES,
PBU_$DCTE_TABLE, PBU_$PPN_OWNERS, IOMAP, the hand-written routines'
headings and every PBU routine's.  io/io.pas, fim/fim.pas, os/os.pas,
sm/sm.pas, sm_c/sm_c.pas, proc2/proc2.pas and ec/ec2.pas include it
(after ec/ec.ins.pas).  The I/O map statuses of the family are
io/io.ins.pas's.  `ec/ec.ins.pas`: Apollo's ec2_$bad_eventcount.
mt/mt.ins.pas still declares its own copies of some PBU headings and
IOMAP (mt/mt.pas does not include pbu.ins.pas).

## Against the conformance unit

`../domain-pascal/tests/conformance/pbu.pas` (not modified) is the SAU2
PBU module: the same three bodies.  Differences:
- PBU_$FREE_ASID has one parameter here, `asid: integer` by value
  (`options(val_param)`), from its one caller's push
  (PROC2_$CLEANUP_HANDLERS_INTERNAL pushes a word after the pad); the
  unit has none.  The body is the same bare return (an empty procedure
  with parameters by value).
- The unit declares its own status_$t with `all` only and its own
  constant; the tree uses base/base.ins.pas's status_$t and
  pbu.ins.pas's constant.  Same code.
EC2_PBU has no conformance unit.

## Open items

### Types and names

- PBU_$FREE_ASID takes a word: its caller pushes one.
- The map names one object, EC2_$PBU_ECS, in the EC2_PBU module's data,
  which this Pascal defines.
- The SAU5 DDF, DCTE and control layouts are inferred from the code
  (pbu.ins.pas), the SAU3's control and I/O map entry likewise.
- PBU_$WIRE_SPECIAL's SAU3 body: the TODO(pascal) in `wire_special.pas`.

### TODO(sau)

- The SAU4 and SAU6..SAU8 PBU and PBU_MAP code, each SAU's own
  (`pbu.pas`, `pbu_map.pas`);
  PBU_TABLES' size on the SAU4 and SAU7 (`pbu.ins.pas`).
