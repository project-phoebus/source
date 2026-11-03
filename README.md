# Domain/OS SR10.2 kernel source

A reconstruction, in Domain Pascal and 68000-family assembly, of the
kernel of Apollo Computer's Domain/OS SR10.2, made from the compiled
kernel images for digital preservation and study.

The aim is fidelity: every routine does what the original's machine code
does, the data structures have the original's layout, and the names are the
original link maps' wherever the maps have a symbol.  The kernel is built
per SAU (Apollo's system architecture units, one image per family of
machines):

| SAU  | machines             | state                                               |
|------|----------------------|-----------------------------------------------------|
| sau2 | DN300, DN320, DN330  | boots an SR10.2 volume to the Display Manager login |
| sau3 | DSP80, DSP80A, DSP90 | builds and passes its checks                        |
| sau5 | DN550/DN560 family   | builds and passes its checks                        |
| sau9 | DN2500               | boots an SR10.2 volume to the Display Manager login |

The running kernels were tested under MAME's Apollo machines.

## Layout

- `domain_os/`: the kernel, one directory per subsystem (`domain_os/<sub>/`,
  each with a `README.md`), one routine per file.  Assembly that is
  shared by every 68000-family SAU is in `<sub>/m68k/`, per-SAU assembly in
  `<sub>/sau#/`.
- `domain_os/tools/`: the build, layout and checking tools, and the MAME
  boot harnesses.

## Building

In `domain_os/`: `make` builds the SAU2 kernel (`dist/sau2/domain_os`);
`make TARGET_SAU=sau3`, `sau5` and `sau9` build the others, and
`make check` runs the layout and image checks.  The build needs the GNU
binutils for `m68k-elf` and Python 3, and the Domain Pascal compiler
`dpc` (set `DPC` to its path), a separate project.  The checks that compare
against the original image need reference data extracted from your own copy
of it; without that data they are skipped.

## How this was made

The analysis and translation were done by the project's author working with
AI coding agents (Anthropic's Claude), checked against the original images.
