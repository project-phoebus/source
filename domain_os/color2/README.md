# The COLOR2 subsystem in Domain Pascal

The driver of the color displays on the graphics board (the DN580's and
the DN570's) of the SAU5 and SAU6 (the part `gpu_driver`,
`../base/config.ins.pas`: the maps with COLOR2 are exactly those whose
GPU module is the real driver), translated from the SAU5 image.

## Layout

One module, `color2.pas`, `module color2;`; its whole body is under
`gpu_driver`, so other SAUs compile it to nothing.

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | COLOR2, 0x5C bytes | COLOR2_$VIDEO_CTL | `[section(wired_proc, wired_data)]` |
| .TEXT (default) | COLOR2, 0x458 bytes | COLOR2_$COLD_INIT .. COLOR2_$DISABLE_GPU_INT | none |
| .DATA (default) | COLOR2 data, 8 bytes | the two displays' owners, the associated flag | module variables |
| WIRED_DATA | COLOR2_ASM, 0x24 bytes | COLOR2_$INT_DECODE, COLOR2_$INT_EC | hand assembly, `sau5/color2_asm.s` |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR2_$VIDEO_CTL | `video_ctl.pas` |
| COLOR2_$COLD_INIT | `cold_init.pas` |
| COLOR2_$INT_INIT | `int_init.pas` |
| COLOR2_$ASSOC | `assoc.pas` |
| COLOR2_$DISSOC | `dissoc.pas` |
| COLOR2_$SHUTDOWN | `shutdown.pas` |
| COLOR2_$LOAD_CRSR | `load_crsr.pas` |
| COLOR2_$BUSY_WAIT | `busy_wait.pas` |
| COLOR2_$GET_EC | `get_ec.pas` |
| COLOR2_$ENABLE_GPU_INT | `enable_gpu_int.pas` |
| COLOR2_$DISABLE_GPU_INT | `disable_gpu_int.pas` |
| COLOR2_$INT_DECODE, COLOR2_$INT_EC | none: hand assembly, `sau5/color2_asm.s` |

`color2.ins.pas`, the home of the COLOR2 declarations: its status, the
cursor bitmap's formal type, COLOR2_$INT_EC, COLOR3_$CR_CONTENTS (SMD's
hand-written data's), COLOR2_$INT_DECODE's heading and the module's.
os/os.pas, smd/smd.pas and gpu/gpu.pas include it.  The board's
control block KOLOR_CTL is SMD's declaration
(`../smd/smd_internal.ins.pas` smd_kolor_ctl_t, now with the fields
COLOR2 uses), and the display memories SMD's (DISP_MEM_2KX1K,
DISP1_MEM); `color2.pas` includes those files.

## The SAU6

The SAU6's map has the SAU5's segments but .TEXT, 0x4E4 bytes, and
COLOR2_ASM's other code.  Two arms:

- COLOR2_$INT_INIT (`gpu_own_vectors`): COLOR2_$INT_DECODE goes in the
  board's own vector, COLOR2_DONE_VEC, where the SAU5 calls COLOR_ASM's
  COLOR_$VECTOR_INIT (the SAU6 has no COLOR module).
- COLOR2_$ASSOC (`vm_regions`, the region MMU's): the board's 64 pages
  mapped into the caller's special segment with MST_$MAP_SPECIAL and
  MMU_$INSTALL_SPECIAL (from page 16#1240 for the DN580, 16#180 for the
  DN570), and ctl that segment's address, as COLOR_$ASSOC does on the
  SAU4.

The other routines are the SAU5's source; the SAU6's code differs only
in the 68020's code generation, registers and the I/O addresses.
COLOR2_ASM is `sau6/color2_asm.s`: COLOR2_$INT_DECODE is entered by
its vector, raises the IPL, switches to the interrupt stack and
advances COLOR2_$INT_EC through PROC1_$INT_ADVANCE.  Its 0x24 bytes were
checked against the image by assembling the file with `m68k-elf-as
-m68020 -m68881` and linking it at the map's addresses.

## Open items

- TODO(sau): the SAU6 link needs COLOR2_DONE_VEC (the TRAP_PAGE's
  16#290) as an absolute symbol.
