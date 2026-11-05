# The VME subsystem in Domain Pascal

The VME bus's interrupt routines, their vectors and the bus error state,
on the SAUs whose kernel has a VME bus (the part `vme_bus`,
`../base/config.ins.pas`: the SR10.2 SAU5 and SAU6). Translated from the
SAU5 image, and the turbo boards' form (`vme_vectored_ints`) from the
SAU6 image; the SAU2 build compiles the module to an empty object.

## Layout

One module, `vme.pas`, `module vme_, wired_proc, wired_data;` (the map
segment's name), its whole body under `%if vme_bus`:

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | VME_, 0x304 bytes | VME_$UNDEF_INT, VME_$DEFINE_INT, VME_$INT, VME_$USER_INT, VME_$ERR_INT, VME_$DEFINE_USERINT, VME_$SAVE_VME, MBUS_$ENABLE_DEV, MBUS_$DISABLE_DEV | none (the heading's) |
| OS_INIT_PROC | VME_, 0xAC bytes | VME_$INIT | `[section(os_init_proc, os_init_data)]` |
| WIRED_DATA | VME_ data, 0xD8 bytes | VME_$SAVE, VME_$USER_VEC, VME_$INT_VEC | module variables (defined, the vectors initialized) |
| WIRED_DATA | VME_ASM, 0xC bytes | VME_$SPURIOUS_INT | hand assembly, `sau5/vme_asm.s` |

With `vme_vectored_ints` (the SAU6) the module is the turbo boards'
form, with its own define list and fragments' arms:

| section | SAU6 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | VME_, 0x84 bytes | VME_$INT, VME_$DEFINE_USERINT, VME_$UNDEF_INT | none (the heading's) |
| OS_INIT_PROC | VME_, 0x48 bytes | VME_$INIT | `[section(os_init_proc, os_init_data)]` |
| WIRED_DATA | VME_ data, 0x40 bytes | VME_$USER_VEC (user interrupts 8..15) | module variable (defined, the handlers initialized) |
| WIRED_DATA | VME_ASM, 0x4C bytes | VME_$SAVE_VME, VME_$SAVE | hand assembly, `sau6/vme_asm.s` |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| VME_$UNDEF_INT | `undef_int.pas` |
| VME_$DEFINE_INT | `define_int.pas` |
| VME_$INT | `int.pas` |
| VME_$USER_INT | `user_int.pas` |
| VME_$ERR_INT | `err_int.pas` |
| VME_$DEFINE_USERINT | `define_userint.pas` |
| VME_$SAVE_VME | `save_vme.pas` |
| MBUS_$ENABLE_DEV | `../mbus/enable_dev.pas` |
| MBUS_$DISABLE_DEV | `../mbus/disable_dev.pas` |
| VME_$INIT | `init.pas` |
| VME_$SPURIOUS_INT | none: hand assembly, `sau5/vme_asm.s` |
| VME_$SAVE_VME (SAU6) | none: hand assembly, `sau6/vme_asm.s` |

`vme.ins.pas` holds the statuses, the vectors' and registers' types
(VME_CTL's `vme_$ctl_t`, WIN's `vme_$dt_ctl_t`), the module's variables,
the headings, and GPU_$INTERRUPT's (hand-written GPU code, for
VME_$INIT).  The headings of VME_$INIT and VME_$DEFINE_USERINT
(IO_$BUS_EPV's entry 1) are io/io.ins.pas's; a temporary copy is in
`vme.ins.pas` until the two SAU5 translation groups' work is merged.

`sau5/vme_asm.s` is assembled only by a SAU5 build, `sau6/vme_asm.s`
only by a SAU6 build (the Makefile takes `*/$(TARGET_SAU)/*.s`).

## Open items

- TODO(pascal): `addr(pbu_ctl)` to LOG_$ADD's univ data (dpc refuses
  the 192-byte conversion; a stand-in local), `int.pas`.
- TODO(merge): the id word compared unsigned (`define_int.pas`); the
  cartridge tape's controller type (`vme.ins.pas`).
- The I/O symbols the SAU5 modules use (VME_CTL, WIN, PBU_CTL) are the
  map's I/O definitions, which a SAU5 build's `arch/m68k/sau5/` will
  have to define.
