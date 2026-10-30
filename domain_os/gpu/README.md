# The GPU subsystem in Domain Pascal

The graphics processor manager (the SAU2 has no graphics processor).

## Layout

One module, `gpu.pas`, `module gpu;` (the map segment's name).

On the SAU2:

| section | code | routines | attribute |
|---------|----------|-----------|
| .TEXT (default) | GPU, 0x14 bytes | GPU_$INIT, GPU_$TERM (an empty procedure) | none |

No data of its own.  The map's GPU_ASM data segment (0x10 bytes:
GPU_$PRESENT, GPU_$PAGE_EC) is the data of a hand-written module (the
`_ASM` name), gets no Pascal, and is not addressed by these routines
(`sau2/gpu_asm.s`).  Its one reader is ASKNODE_$INTERNET_INFO, through
the `extern` declaration of GPU_$PRESENT in `gpu.ins.pas`.

With `gpu_driver` (base/config.ins.pas: the SAU5 and SAU6) the module
is the graphics processor's driver; on the SAU5:

| section | code | routines | attribute |
|---------|----------|-----------|
| OS_INIT_PROC | GPU, 0x120 bytes | GPU_$COLD_INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT (default) | GPU, 0x116C bytes | eleven module-local routines, GPU_$INIT, GPU_$TERM, GPU_$DIAG_ACQUIRE, _$DIAG_RELEASE, _$FLUSH, _$SET_PAGE_LIMITS, _$CMND, _$DIAG_WIRE | none |

The .DATA block (0x5DC bytes, zero) is the module's variables
(`gpu.pas`); GPU_ASM (WIRED_DATA, 0x5C bytes: GPU_$DONE_EC,
GPU_$PAGE_EC, GPU_$USER_PID, GPU_$PRESENT, GPU_$ML_LOCK and the
interrupt handler GPU_$INTERRUPT) is hand assembly, `sau5/gpu_asm.s`.
The driver's types, the hardware and the GPU_ASM objects are
`gpu_internal.ins.pas` (included by `gpu.pas` only); the global
headings and the statuses `gpu.ins.pas`.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| GPU_$COLD_INIT | `cold_init.pas` |
| gpu_$lock (module-local) | `lock.pas` |
| gpu_$unlock (module-local) | `unlock.pas` |
| gpu_$wait_pio (module-local) | `wait_pio.pas` |
| gpu_$wait_pio_timed (module-local) | `wait_pio_timed.pas` |
| gpu_$pio_write (module-local) | `pio_write.pas` |
| gpu_$unwire_page (module-local) | `unwire_page.pas` |
| gpu_$unwire_process_pages (module-local) | `unwire_process_pages.pas` |
| gpu_$wire_page (module-local) | `wire_page.pas` |
| gpu_$service_page_fault (module-local) | `service_page_fault.pas` |
| GPU_$INIT | `init.pas` (the SAU2's stub the other arm) |
| gpu_$reset (module-local) | `reset.pas` |
| gpu_$unwire_buffers (module-local) | `unwire_buffers.pas` |
| GPU_$TERM | `term.pas` (the SAU2's empty body the other arm) |
| GPU_$DIAG_ACQUIRE | `diag_acquire.pas` |
| GPU_$DIAG_RELEASE | `diag_release.pas` |
| GPU_$FLUSH | `flush.pas` |
| GPU_$SET_PAGE_LIMITS | `set_page_limits.pas` |
| GPU_$CMND | `cmnd.pas` |
| GPU_$DIAG_WIRE | `diag_wire.pas` |
| GPU_$INTERRUPT | none: hand assembly (`sau5/gpu_asm.s`) |
| (data) GPU_ASM | none: hand assembly (`sau5/gpu_asm.s`) |

## Open items

- `cmnd.pas`: TODO(pascal) for the constant command lists GPU_$CMND and
  GPU_$COLD_INIT copy from their code (no structured constant in the
  reference); the words are assigned one by one.
- `gpu.pas`: TODO(pascal) for the stand-ins unused_40c and unused_5a4
  (the 8-byte alignment lead of smd/smd.pas).
- The statuses 16#2D000A and 16#2D000C: the SR10.2 database's texts
  ("illegal values for physical page use limits", "DMA command
  execution error") do not fit the SAU5 code's uses (a PIO error bit;
  GPU_$SET_PAGE_LIMITS's bad limits); the names follow the texts.
- TODO(merge) in `gpu_internal.ins.pas`: COLOR2_$INT_EC belongs in a
  COLOR2 insert.

SAU2: both routines byte-identical with the image
(as compiled by dpc); no dpc gap.
