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

## Open items

- TODO(sau): the SAU6's COLOR2 code, and its COLOR2_$INT_INIT, which
  cannot call COLOR_ASM's COLOR_$VECTOR_INIT there (`color2.pas`,
  `int_init.pas`).
