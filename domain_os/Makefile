
TARGET_SAU := sau2

# Another SAU: `make TARGET_SAU=sau5' (and `... check').  Its Pascal is
# compiled with -config sau5, its hand assembly is */m68k/*.s and
# */sau5/*.s, its linker script sau5.ld (INCLUDEing kernel.ld), and the
# tools take --sau 5 for their per-SAU tables.

# The kernel is built from the Domain Pascal tree: every module file is
# compiled with dpc, and the objects are linked with the hand-written
# assembly and dpc's run-time library.
#
# The SAU2 image is one binary for the DN300/DN320 (68010) and the DN330
# (68020): the 10.2 kernel's compiled code is 68010-clean (no bit-field,
# extb.l, 32-bit mul/div or scaled-index instructions; MST_$PRE_INIT at
# 0xE309F4 is plain 68000 code) and takes the 68020 paths only behind
# PROM_$MACHINE_ID checks in hand assembly.  dpc's output is assembled for
# the 68010 (PAS_ASFLAGS); the transcribed assembly keeps whatever the image
# has, so its assembler accepts 68020 and 68881 instructions (ASFLAGS).

AS := m68k-elf-as
ASFLAGS := -mcpu=68020 -m68881
# The SAU9 (DN2500) is an MC68030: its hand assembly has the 68030's PMMU
# instructions (pmove to TC/CRP/TT0), so it is assembled for that CPU.
ifeq ($(TARGET_SAU),sau9)
ASFLAGS := -m68030 -m68881
endif
PAS_ASFLAGS := -m68010
NM := m68k-elf-nm
LD := m68k-elf-ld
# The SAU's linker script: its constants and its own checks, INCLUDEing
# kernel.ld, the output sections and checks every SAU shares.
LINK_SCRIPT := $(TARGET_SAU).ld
LINK_SCRIPTS := $(LINK_SCRIPT) kernel.ld
LDFLAGS := -T $(LINK_SCRIPT)
AR := m68k-elf-ar

BUILD_DIR := build/$(TARGET_SAU)
DIST_DIR := dist/$(TARGET_SAU)

# The original SR10.2 files the build and the checks read live outside this
# repository, by default in directories beside it (REPO_PARENT: the
# directory holding this repository's checkout; from a git worktree, the
# main checkout's).
REPO_PARENT := $(or $(shell d=$$(git -C '$(CURDIR)' rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && cd "$$d/../.." && pwd),$(abspath $(CURDIR)/../..))
# Link-order fragment (see the layout rules below).  SAU2_MAP is the link map
# of the SR10.2 SAU2 image.
SAU2_MAP ?= $(REPO_PARENT)/sau2-maps/domain_os.10.2.map
SAU2_IMAGE ?= $(REPO_PARENT)/sr10.2-install/install/ri.apollo.os.v.10.2/sau2/domain_os
# The map and image of the SAU being built (TARGET_SAU): the SAU2's above,
# the others' from the SR10.2 install tree (sau<N>/domain_os.map and
# sau<N>/domain_os).  check-asm, the layout and check-rfc use them.
SR102_INSTALL ?= $(REPO_PARENT)/sr10.2-install/install/ri.apollo.os.v.10.2
ifeq ($(TARGET_SAU),sau2)
SAU_MAP := $(SAU2_MAP)
SAU_IMAGE := $(SAU2_IMAGE)
else
SAU_MAP ?= $(SR102_INSTALL)/$(TARGET_SAU)/domain_os.map
SAU_IMAGE ?= $(SR102_INSTALL)/$(TARGET_SAU)/domain_os
endif
# The SAU's number, for the tools' --sau (their address tables are keyed
# by SAU).
SAU_NUM := $(patsubst sau%,%,$(TARGET_SAU))
LAYOUT_GEN := tools/gen_layout_ld.py
LAYOUT_GEN_FLAGS := --sau $(SAU_NUM) --map $(SAU_MAP)
LAYOUT_LD := $(BUILD_DIR)/layout.ld
LAYOUT_CHECK_ELF := $(BUILD_DIR)/layout-check.elf

# The kernel ELF ($(LINK_SCRIPT); --emit-relocs keeps the relocations the fixup
# table is made from) and the RFC image made from it.
KERNEL_ELF := $(BUILD_DIR)/domain_os.elf
RFC_FIXUPS := tools/gen_rfc_fixups.py
RFC_ELF := tools/rfc_elf.py

.PHONY: all clean domain_os pascal pascal-report check check-layout check-asm check-rfc

all:: domain_os

# ---------------------------------------------------------------------------
# The hand-written assembly
# ---------------------------------------------------------------------------
# The routines the images have as hand assembly:
# <subsystem>/m68k/*.s: shared by two or more SAUs.  Where the SAUs' code
#   differs in a few places the file tests base/config.ins.pas's parts
#   with gas conditionals (`.include
#   "base/config.inc"', `.if mt_driver'); tools/gen_asm_config.py writes
#   $(ASM_CONFIG) from config.ins.pas for the SAU being built.
# <subsystem>/sau2/*.s, <subsystem>/sau5/*.s, ...: one SAU's own.
# arch/m68k/sau2/*.s: per-SAU objects with no bytes (iodefs.s: the map's
# absolute symbols - I/O pages, PTT, PROT, TRAP_PAGE - that the hand-written
# cold-start code references by name so its cells are relocations).
ASM_SRCS := $(filter-out build/% dist/% arch/%,$(wildcard */m68k/*.s)) \
            $(filter-out build/% dist/%,$(wildcard */$(TARGET_SAU)/*.s))
ASM_OBJS := $(patsubst %.s,$(BUILD_DIR)/%.o,$(ASM_SRCS))
ARCH_ASM_SRCS := $(wildcard arch/m68k/$(TARGET_SAU)/*.s)
ARCH_ASM_OBJS := $(patsubst %.s,$(BUILD_DIR)/%.o,$(ARCH_ASM_SRCS))

# svc/m68k/*.s share instruction-encoding macros through a gas .include
# (svc/m68k/svc_macros.inc, resolved relative to this directory).  The
# generic %.o: %.s rule cannot see that, so state the dependency here.
$(filter $(BUILD_DIR)/svc/%,$(ASM_OBJS)): svc/m68k/svc_macros.inc

ASM_CONFIG := $(BUILD_DIR)/base/config.inc
$(ASM_CONFIG): base/config.ins.pas tools/gen_asm_config.py
	@echo "[GEN] $@"
	@python3 tools/gen_asm_config.py --sau $(TARGET_SAU) -o $@

$(BUILD_DIR)/%.o: %.s $(ASM_CONFIG)
	@mkdir -p $(dir $@)
	@echo "[AS] $<"
	@$(AS) $(ASFLAGS) -I $(BUILD_DIR) -o $@ $<

# ---------------------------------------------------------------------------
# dpc's run-time library
# ---------------------------------------------------------------------------
# The Pascal compiler's run-time routines come from dpc's runtime archive
# (dpc --print-runtime=m68k): m_arith.o is M$ARITH (M$MIS$LLW, M$DIU$LLL, ...;
# the image's bytes, symbols and section, .text.M$ARITH), pas_set_build.o is
# PAS_$SET_BUILD.  They are extracted into the build directory and linked like
# hand-written routines, and check-asm compares M$ARITH with the image.
# The compiler repo's stable build (its `make stable': a release build of a
# commit, with its runtime), not its working target/debug.
DPC ?= $(REPO_PARENT)/domain-pascal/target/stable/bin/dpc
DPC_RUNTIME := $(shell $(DPC) --print-runtime=m68k 2>/dev/null)
# The SAU being built, as the conditional-compilation variable of that name
# (base/config.ins.pas; ref 4.7 and 6.4.8, `-config').  The flags go before
# `-o': -config takes every argument up to the next one starting with `-'.
# tools/pascal_check.sh reads DPC and DPC_FLAGS from here.
DPC_FLAGS := -config $(TARGET_SAU)
# The SAU6..SAU9 kernels were compiled for an MC68020-class CPU (bit-field
# instructions, scaled index operands, 32-bit multiply and divide); the
# SAU2..SAU5 kernels for an MC68010.  -cpu takes a name from the
# reference's Table 6-3 (ref 6.4.9, p. 6-16); any MC68020-class one
# selects that code.
ifneq ($(filter sau6 sau7 sau8 sau9,$(TARGET_SAU)),)
DPC_FLAGS += -cpu mathchip
endif
RUNTIME_OBJS := $(BUILD_DIR)/runtime/m_arith.o $(BUILD_DIR)/runtime/pas_set_build.o

$(RUNTIME_OBJS): $(DPC_RUNTIME)
	@test -n "$(DPC_RUNTIME)" || { echo "error: dpc --print-runtime=m68k gave no archive (DPC=$(DPC))"; exit 1; }
	@mkdir -p $(dir $@)
	@echo "[AR] $@ from $(DPC_RUNTIME)"
	@cd $(dir $@) && $(AR) x $(DPC_RUNTIME) $(notdir $@) && touch $(notdir $@)

# ---------------------------------------------------------------------------
# The Pascal tree
# ---------------------------------------------------------------------------
# Every module file (tools/pascal_modules.py: <subsystem>/<subsystem>.pas and
# a subsystem's other files with a module heading; the same list
# tools/pascal_check.sh checks) is compiled with `dpc -o' to assembly and
# assembled.  dpc emits one input section per map module and section
# (`.text.UID_.WIRED_PROC', plain `.text' for the default section,
# `.bss.moddata.UID_.WIRED_DATA'), and the fragments are included in image
# order, so gen_layout_ld.py lays the code out in map order and keys each
# data block by its module's data segment of the map.  A module dpc cannot
# compile fails the build with dpc's message; `make pascal-report'
# compiles them all and lists what fails.
PAS_BUILD_DIR := $(BUILD_DIR)/pascal
PAS_MODULES := $(shell python3 tools/pascal_modules.py)
PAS_SRCS_ALL := $(wildcard */*.pas)
PAS_OBJS := $(patsubst %.pas,$(PAS_BUILD_DIR)/%.o,$(PAS_MODULES))

# A module depends on every .pas of the tree (its fragments and the insert
# files it includes; dpc writes no dependency list), on dpc itself, and on
# this Makefile (DPC_FLAGS: a change of -config recompiles).
$(PAS_BUILD_DIR)/%.s: %.pas $(PAS_SRCS_ALL) $(DPC) Makefile
	@mkdir -p $(dir $@)
	@echo "[DPC] $<"
	@$(DPC) $(DPC_FLAGS) -o $@ $<

$(PAS_BUILD_DIR)/%.o: $(PAS_BUILD_DIR)/%.s
	@echo "[AS] $<"
	@$(AS) $(PAS_ASFLAGS) -o $@ $<

pascal: $(PAS_OBJS)

# Compile every module file, keep going, and list the ones dpc refuses with
# their first error and error count (build/sau2/pascal/report.txt).
pascal-report:
	@mkdir -p $(PAS_BUILD_DIR)
	@ok=0; bad=0; : > $(PAS_BUILD_DIR)/report.txt; \
	for m in $(PAS_MODULES); do \
	  s=$(PAS_BUILD_DIR)/$${m%.pas}.s; mkdir -p $$(dirname $$s); \
	  if $(DPC) $(DPC_FLAGS) -o $$s $$m > $$s.log 2>&1; then ok=$$((ok+1)); \
	  else bad=$$((bad+1)); rm -f $$s; \
	    printf '%s: %s error(s); first: %s\n' $$m "$$(grep -c 'error:' $$s.log)" \
	      "$$(grep -m1 'error:' $$s.log)" >> $(PAS_BUILD_DIR)/report.txt; fi; \
	done; \
	cat $(PAS_BUILD_DIR)/report.txt; \
	echo "$$ok of $$((ok+bad)) module files compile; $$bad refused (see $(PAS_BUILD_DIR)/report.txt)"

# ---------------------------------------------------------------------------
# The kernel
# ---------------------------------------------------------------------------
KERNEL_OBJS := $(PAS_OBJS) $(ASM_OBJS) $(ARCH_ASM_OBJS) $(RUNTIME_OBJS)

domain_os: $(DIST_DIR)/domain_os

# The RFC image: link the ELF, then tools/gen_rfc_fixups.py writes its
# loadable sections by load
# address (objcopy -O binary: COLD at file 0, DUMP at 0x800, the kernel from
# 0xC00) and appends the fixup table at RELOC: count.w, then the low address
# of every R_68K_32 cell of COLD, DUMP and the kernel.
$(KERNEL_ELF): $(KERNEL_OBJS) $(LINK_SCRIPTS) $(LAYOUT_LD)
	@mkdir -p $(dir $@)
	@echo "[LINK] $@"
	@$(LD) -L $(BUILD_DIR) $(LDFLAGS) --emit-relocs --no-warn-rwx-segments \
	    -o $@ $(KERNEL_OBJS)

$(DIST_DIR)/domain_os: $(KERNEL_ELF) $(RFC_FIXUPS) $(RFC_ELF)
	@mkdir -p $(dir $@)
	@echo "[RFC] $@"
	@python3 $(RFC_FIXUPS) --elf $(KERNEL_ELF) -o $@

# Link order.  Code and module data blocks are linked in the order of the
# SAU2 link map, not at fixed addresses.  kernel.ld INCLUDEs layout.ld inside its `.text' output
# section: one input-section statement per dpc code section, hand-written
# routine and module data block, in map order.  The generator also writes
# layout_data.ld (end of `.data'), layout_bss.ld (the image's own bss,
# NOBITS, in map order) and layout_vm.ld (the VM tables' run-time windows
# past OS_PAGE_END); see the bss rule in kernel.ld.
# tools/gen_layout_ld.py writes them from the map and the objects' symbol
# tables and sections.  It is regenerated before every link.
# The link map is an input from the original release, not built here.
$(LAYOUT_LD): $(KERNEL_OBJS) $(LAYOUT_GEN) $(RFC_ELF) $(wildcard $(SAU_MAP))
	@test -f $(SAU_MAP) || { echo "error: the link map $(SAU_MAP) is missing (set SAU2_MAP, or SAU_MAP / SR102_INSTALL for another SAU)"; exit 1; }
	@mkdir -p $(dir $@)
	@echo "[GEN] $@"
	@python3 $(LAYOUT_GEN) $(LAYOUT_GEN_FLAGS) -o $@ $(KERNEL_OBJS)

# `make check': static checks plus a scratch link.  The check links an ELF
# with --unresolved-symbols=ignore-all (so it works while symbols are still
# missing) and then verifies with m68k-elf-nm that every placed map symbol
# and block appears in map order, reporting the first inversion, the number
# placed and what fell into the catch-all.  (The ELF has an RWX segment
# because the module data blocks sit among the code in `.text'; the RFC
# image is made from the loaded bytes, so that is expected.)
check: check-layout check-asm check-rfc

check-layout: $(LAYOUT_LD) $(KERNEL_OBJS) $(LINK_SCRIPTS)
	@echo "[CHECK] layout: static checks"
	@python3 $(LAYOUT_GEN) $(LAYOUT_GEN_FLAGS) --check-only $(KERNEL_OBJS)
	@echo "[CHECK] layout: scratch link $(LAYOUT_CHECK_ELF)"
	@$(LD) -L $(BUILD_DIR) $(LDFLAGS) --oformat elf32-m68k --no-warn-rwx-segments \
	    --unresolved-symbols=ignore-all -o $(LAYOUT_CHECK_ELF) $(KERNEL_OBJS)
	@echo "[CHECK] layout: map order"
	@python3 $(LAYOUT_GEN) $(LAYOUT_GEN_FLAGS) --check-elf $(LAYOUT_CHECK_ELF) $(KERNEL_OBJS)

# Relocation-aware byte gate for the hand-written assembly: every
# hand-assembly object of the SAU being built (*/m68k/*.s and
# */$(TARGET_SAU)/*.s) and dpc's M$ARITH is compared run by run with that
# SAU's image, with the bytes under each relocation set aside and every
# relocated operand resolved against the image operand: encodings identical
# to the image; address operands resolve to our objects.  Documented
# widenings and deviations are listed by the script.  The SAU2's reference
# bytes are tools/asm_image_ref.txt, extracted from the original image (see
# tools/asm_compare.py: `--extract' from a Ghidra program of the image, and
# `make asm-ref-image' for the regions Ghidra does not hold); another SAU's
# are read from its image file through its map's `loaded at' sections
# (--image), with the script's address tables for that SAU (--sau):
# `make TARGET_SAU=sau5 check-asm'.  Without those files the gate is
# skipped, with a line saying so.
ASM_CHECK_OBJS := $(ASM_OBJS) $(BUILD_DIR)/runtime/m_arith.o
ASM_COMPARE := tools/asm_compare.py
ASM_IMAGE_REF := tools/asm_image_ref.txt
ifeq ($(TARGET_SAU),sau2)
ASM_COMPARE_REF := --ref $(ASM_IMAGE_REF)
ASM_COMPARE_DEPS := $(ASM_IMAGE_REF)
ASM_COMPARE_HOW := extract it with tools/asm_compare.py --extract and make asm-ref-image
else
ASM_COMPARE_REF := --sau $(SAU_NUM) --image $(SAU_IMAGE)
ASM_COMPARE_DEPS := $(SAU_IMAGE) $(SAU_MAP)
ASM_COMPARE_HOW := set SAU_IMAGE and SAU_MAP, or SR102_INSTALL
endif
ASM_COMPARE_MISSING := $(filter-out $(wildcard $(ASM_COMPARE_DEPS)),$(ASM_COMPARE_DEPS))

ifeq ($(ASM_COMPARE_MISSING),)
check-asm: $(ASM_CHECK_OBJS) $(ASM_COMPARE) $(ASM_COMPARE_DEPS)
	@echo "[CHECK] asm: relocation-aware compare with the image"
	@python3 $(ASM_COMPARE) --map $(SAU_MAP) $(ASM_COMPARE_REF) $(ASM_CHECK_OBJS)
else
check-asm:
	@echo "[SKIP] asm: the compare with the image needs $(ASM_COMPARE_MISSING) ($(ASM_COMPARE_HOW))"
endif

# The regions the kernel's Ghidra program does not hold (the RFC header and
# COLD_START, file 0x000..0x800 = 0x101400; the DUMP page, file 0x800..0xC00
# = VA 0xE00400) take their reference bytes from the image file itself:
# `make asm-ref-image' appends the runs of those regions that the reference
# file lacks.  Like --extract, a maintenance step.
.PHONY: asm-ref-image
asm-ref-image: $(ASM_CHECK_OBJS) $(ASM_COMPARE)
	@python3 $(ASM_COMPARE) --map $(SAU2_MAP) --ref $(ASM_IMAGE_REF) \
	    --extract-file $(SAU2_IMAGE):0x101400:0x0-0x800 \
	    --extract-file $(SAU2_IMAGE):0xDFFC00:0x800-0xC00 $(ASM_CHECK_OBJS)

# The RFC image: header, info block, COLD and DUMP against the original
# modulo relocations, the constant VA/LMA delta, every loaded section's
# bytes, the fixup table, the MMAP/PTTX/stack constraints, and a dry-run
# loader (sysboot's page placement + COLD's MMU map) that maps every kernel
# VA to its physical page; the same loader is run over the original image as
# the oracle (the SAU2's: tools/rfc_segments.json, tools/asm_image_ref.txt;
# the SAU's own with --sau, tools/check_rfc.py's tables keyed by SAU).
RFC_CHECK := tools/check_rfc.py

# The oracle json is decoded from the original image: tools/rfc_segments.json
# and tools/rfc_segments_<sau>.json by tools/rfc_decode.py [--sau N] --image
# IMAGE --map MAP -o FILE (the SAU9's by tools/check_rfc.py --sau 9
# --write-segments); with no reference extract of another SAU's image the
# oracle's loader is checked against its map's file segments (--map).
# Without the original image or the json the checks of our image still run
# and the oracle is skipped, with a line saying so.
ifeq ($(TARGET_SAU),sau2)
RFC_CHECK_ORACLE := --segments tools/rfc_segments.json --ref $(ASM_IMAGE_REF)
RFC_CHECK_NEEDS := $(SAU_IMAGE) tools/rfc_segments.json $(ASM_IMAGE_REF)
else
RFC_CHECK_ORACLE := --segments tools/rfc_segments_$(TARGET_SAU).json --map $(SAU_MAP)
RFC_CHECK_NEEDS := $(SAU_IMAGE) tools/rfc_segments_$(TARGET_SAU).json $(SAU_MAP)
endif
RFC_CHECK_MISSING := $(filter-out $(wildcard $(RFC_CHECK_NEEDS)),$(RFC_CHECK_NEEDS))

check-rfc: $(DIST_DIR)/domain_os $(KERNEL_ELF) $(RFC_CHECK) $(RFC_ELF)
	@echo "[CHECK] rfc: the load image and a dry-run of sysboot + COLD"
ifeq ($(RFC_CHECK_MISSING),)
	@python3 $(RFC_CHECK) --sau $(SAU_NUM) --image $(DIST_DIR)/domain_os --elf $(KERNEL_ELF) \
	    --orig $(SAU_IMAGE) $(RFC_CHECK_ORACLE)
else
	@echo "[SKIP] rfc: the original image as the oracle needs $(RFC_CHECK_MISSING) (set SAU2_IMAGE or SAU_IMAGE; decode the json with tools/rfc_decode.py)"
	@python3 $(RFC_CHECK) --sau $(SAU_NUM) --image $(DIST_DIR)/domain_os --elf $(KERNEL_ELF)
endif

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) build/host
