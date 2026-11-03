#!/usr/bin/env python3
#
# tools/asm_compare.py - relocation-aware byte gate for the hand-written
# assembly (<subsystem>/m68k/*.s and <subsystem>/sau<N>/*.s)
#
# One gate for every SAU: --sau N (default 2) picks the SAU whose image the
# objects of that SAU's build are compared with, and the address tables
# below are keyed by SAU (each SAU's entries at its own image addresses,
# with their evidence).  The SAU2's reference bytes are
# tools/asm_image_ref.txt (--ref, below); any SAU's can instead be read
# from its image file through its map's `loaded at' sections (--image,
# image_file.Image), so no Ghidra extract is needed:
#
#   python3 tools/asm_compare.py --sau 5 --map SAU5_MAP --image SAU5_IMAGE \
#       OBJ...                              (make TARGET_SAU=sau5 check-asm)
#
# The SAU2 objects give the same result with --image IMAGE as with --ref.
#
# The hand-written routines are transcribed from the SAU2 image with their
# ENCODINGS unchanged (abs.l stays abs.l, #imm.l stays #imm.l, no switch to
# PC-relative or shorter forms), but the kernel is placed in map order,
# not at the image's addresses, so their address operands must resolve to
# OUR objects: they are symbol references and carry relocations.  The rule
# this
# script enforces:
#
#   encodings identical to the image; address operands resolve to our
#   objects.
#
# Every global symbol must be defined by one object of the set (for a given
# SAU a routine has one home: <sub>/m68k/ or <sub>/sau<N>/).
#
# For every code section of every hand-assembly object:
#
#   1. The section is split into RUNS at each symbol with a known image
#      address (a map symbol, or LOCAL_SYMBOLS below for module-local
#      labels; a section named only by a map SEGMENT starts there); each
#      run is compared with the image at that address.  Several files keep
#      code the image has elsewhere (the SMD trampoline bodies, shared crash
#      stubs); the runs follow them.  Runs starting at
#      an ADDITIONS symbol (C-callable shims that are not image code) are
#      skipped and counted.
#   2. The two byte streams are walked in step.  They must be equal except:
#      - relocation fields (their image operand is recorded for step 3);
#      - WIDENINGS our files document, where an operand the image reached
#        PC-relatively or through a module base register is written as an
#        absolute long: (d16,PC) -> (xxx).l, bsr/bra -> jsr/jmp (xxx).l,
#        Bcc.b -> Bcc.w, (d16,An) -> (xxx).l with An a known base
#        (REGISTER_BASES); the image's target is recorded for step 3;
#      - branches and (d16,PC) operands whose displacement changed because
#        a widening moved code between them and their target (step 3 checks
#        that both land on the same image address);
#      - CMP/SUB/ADD/AND/OR #imm,Dn in the Apollo assembler's <ea>=#imm
#        spelling where gas emits CMPI/SUBI/ADDI/ANDI/ORI (same length,
#        same operation);
#      - (d16,An) displacements on a module base the file rebased to one of
#        our objects (REBASES: misc/m68k/crash_system.s sets A5 to
#        CRASH_REPORT instead of the code base).
#      Anything else is a failure, reported as the first differing offset,
#      unless the run is listed in KNOWN_DEVIATIONS (restructured code with
#      a reason), where the comparison of that run stops and is reported.
#   3. Every relocation and widened operand is RESOLVED in the image's
#      address space and checked against the operand the image has there:
#      the target is another assembly routine (its aligned run), a map
#      symbol, a MODULE_DATA block at its declared image address
#      (tools/gen_layout_ld.py's ordering key) or an IMAGE_ALIASES entry;
#      R_68K_32/16/8 must equal S + A, R_68K_PC32/16/8 must equal S + A - P.
#      A relocation whose target has no image address is reported as
#      unverified (it does not fail the gate); one that resolves to a
#      different cell fails it.  This is what proves a `.set NAME, BLOCK +
#      off' alias points at the same cell the image instruction addressed.
#
#   4. Where two consecutive runs of a section are not contiguous in the
#      image, the image bytes between them are compared with nothing (a run
#      that ends early is invisible to step 2, since the next run re-anchors
#      at its own image address).  Those boundaries are printed as notes and
#      counted, not failed: a file that gathers routines from several places
#      in the image, or whose neighbours are C in our tree, has real gaps.
#      A new note after a change to a file is worth a look.
#
# The image bytes come from a reference file, tools/asm_image_ref.txt,
# extracted from a copy of the original SAU2 image, so `make check' needs
# neither Ghidra nor the image: one line per run, `<address> <length> <hex
# bytes>'.  `make check' skips the gate when the file is absent.  Produce it
# (Ghidra running with the image loaded, gsk on the PATH), and again after
# adding or re-cutting a hand-written routine:
#
#   python3 tools/asm_compare.py --map MAP --extract tools/asm_image_ref.txt OBJ...
#
# Check (make check):
#
#   python3 tools/asm_compare.py --map MAP --ref tools/asm_image_ref.txt OBJ...
#
# Regions the kernel's Ghidra program does not hold: the RFC
# header and COLD_START (cold/sau2/cold_start.s, image file 0x000..0x800,
# image address 0x101400) and the DUMP page (dump/sau2/dump.s, file
# 0x800..0xC00, VA 0xE00400) take their reference bytes from the image
# file itself (sr10.2-install/install/ri.apollo.os.v.10.2/sau2/domain_os):
#
#   python3 tools/asm_compare.py --map MAP --ref tools/asm_image_ref.txt \
#       --extract-file IMAGE:0x101400:0x0-0x800 \
#       --extract-file IMAGE:0xDFFC00:0x800-0xC00 OBJ...      (make asm-ref-image)
#
# Each --extract-file IMAGE:BASE[:LO-HI] says that file byte `off' of IMAGE
# is image address BASE + off, for file offsets LO..HI (default: the whole
# file).  COLD is at 0x101400 + off; the DUMP page and the kernel follow the
# map's `loaded at' rule, VA = off + 0xDFFC00 (0xCFE800 + 0x101400).  With
# --ref and no --extract, every run of the objects that the reference file
# does not cover and a window does is APPENDED to it, under a provenance
# comment naming the file, offsets and base; existing lines are left alone
# and nothing is checked.  With --extract, runs inside a window are read
# from the file instead of from Ghidra.  The check mode does not care where
# a line came from.

import argparse
import bisect
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_ld  # noqa: E402  (LinkMap, ANCHORS)
import image_file  # noqa: E402  (Image: the image file by address)

# The SAU whose image the objects are compared with (--sau; 2 by default).
# Every address table below is keyed by SAU first: {2: {...}, 5: {...}};
# an entry's address is that SAU's image address, with its evidence.
SAU = 2
SAUS = (2, 3, 5, 9)

# Module data block names that the hand-written assembly references and
# that are not map symbols, with their image addresses.  The Pascal tree
# does not define them (its blocks hold the map's names), so the
# assembly's references to them are link blockers until they are renamed
# or defined; the compare only needs their addresses.
C_BLOCK_ADDRS = {
    2: {
        'PEB_$INFO': 0xE24C78,
    },
    3: {
        # the SAU3 map's PEB_$INFO
        'PEB_$INFO': 0xE23BC4,
    },
    5: {
        # the SAU5 map's PEB_$INFO
        'PEB_$INFO': 0xE25AD0,
    },
    9: {
        # the SAU9 map's PEB_$INFO
        'PEB_$INFO': 0x3C428478,
    },
}

# Image addresses of routines and labels the map does not name (module-
# local code, or a routine the map files under its segment name only),
# each cited from the file that defines it.  A run starts at every symbol
# with a known image address, so a file that gathers code from several
# places in the image is compared piece by piece.
LOCAL_SYMBOLS = {
    2: {
        # smd/sau2/smd_utils.s, the SMD_UTILS bodies in `I E702F4
        # SMD_UTILS size = 508' (the map names only SMD_$INVERT_DISP there;
        # the entries are the .DATA stubs)
        'smd_$copy_font_to_hdm_body': 0x00E702F4,
        'smd_$write_str_clip_body': 0x00E70390,
        'smd_$clear_window_body': 0x00E706C0,
        'smd_$horiz_line_body': 0x00E70760,
        'smd_$vert_line_body': 0x00E707C4,
        # svc/m68k/svc_tables.s: the SVC dispatch tables (names the C's; the
        # map has none), each the target of its dispatcher's `lea'
        'SVC_$TRAP0_TABLE': 0xE7B2DE,
        'SVC_$TRAP1_TABLE': 0xE7B35E,
        'SVC_$TRAP2_TABLE': 0xE7B466,
        'SVC_$TRAP3_TABLE': 0xE7B67A,
        'SVC_$TRAP4_TABLE': 0xE7B8E6,
        'SVC_$TRAP5_TABLE': 0xE7BAF2,
        'SVC_$TRAP7_TABLE': 0xE7BC7E,
        'SVC_$TRAP8_TABLE': 0xE7BD6A,
        'SVC_$TRAP8_ARGCOUNT': 0xE7BE4A,
        'proc1_$pcb_pool': 0xE1EBD2,   # the 64 PCBs after PROC1_$READY_COUNT
        'io_$probe': 0x00E29138,                # io/m68k/probe.s
        # io/m68k/trap.s: the first-level interrupt dispatcher in IO_$TBLS
        'io_$flih_dispatch': 0x00E2E85C,
        'mmu_$installi': 0x00E2409C,            # mmu/m68k/installi.s
        'mmu_$remove_internal': 0x00E23DCC,     # mmu/m68k/internal.s
        # proc1/m68k/dispatch.s: the crash stub is the tail of
        # PROC1_$BEGIN_ATOMIC_OP in the image (bne.b 0xE209EE at 0xE20A32)
        'atomic_op_error': 0x00E209EE,
        # proc1/m68k/set_lock.s and clr_lock.s: copies of the shared crash stub
        # at 0x00E20B56 and its status cell
        'set_lock_crash': 0x00E20B56,
        'clr_lock_crash': 0x00E20B56,
        'Illegal_lock_err': 0x00E20DE4,
        # fim/m68k/bus_err.s: the trampoline whose operand is BUS_ERROR_SWITCH
        'JMP_TO_BUS_ERR': 0x00E218CA,
        # fp/m68k/fp_context.s header
        'fp_$switch_owner': 0x00E21B10,
        'fp_$restore_state': 0x00E21B30,
        'fp_$save_state': 0x00E21B5C,
        'fp_$check_owner': 0x00E21D70,
        # stop/m68k/watch.s header (inside the map's STOP_WATCH segment)
        'STOP_$MEASURE_LOOP': 0x00E81916,
        'STOP_$NULL_PROC': 0x00E8193E,
        'STOP_$UNHOOK': 0x00E819E2,
        'STOP_$HOOK': 0x00E81A0A,
        'STOP_$READ_CPUT': 0x00E81B54,
        'STOP_$READ_CLOCK': 0x00E81B5C,
        'stop_$watch_trace_exit': 0x00E81B72,   # the exit-trap arm
        # smd/sau2/*.s: the trampolines in SMD_WIRED jump to bodies that the
        # image keeps in the SMD code segment
        'Lsmd_wired_set_lock': 0x00E27222,      # cursor_thunks.s
        'Lxor_entry': 0x00E15B90,               # cursor_thunks.s
        'Lstart_scroll_body': 0x00E15C68,       # scroll.s
        'Lcontinue_scroll_body': 0x00E15C9C,    # scroll.s
        'Lstart_blt_body': 0x00E15D1E,          # start_blt.s
        # time/m68k/timer_handler.s: the level-6 timer interrupt, which the map
        # counts into TIME_ASM without a symbol
        'TIME_$TIMER_HANDLER': 0x00E2B130,
        # fim/m68k/com.s, soft_fault.s, fp_exceptions.s: points inside the map's
        # FIM_UNWIRED segment that other routines branch to
        'FIM_COMMON_FAULT': 0x00E213A0,         # segment start, falls into FIM_$COM
        'FIM_COM': 0x00E213A4,                  # alias of FIM_$COM
        'FIM_SOFT_FAULT_TAIL': 0x00E21458,      # FIM_$SOFT_FAULT+0xC (FIM_$GENERATE)
        'FIM_SOFT_FAULT_PUSH': 0x00E21462,      # FIM_$SOFT_FAULT+0x16 (FIM_$TRACE)
        'fim_fp_frame_pc': 0x00E2151E,          # FP stub helper inside FIM_$FP_SIG_NAN
        # pchist/pchist_data.c: our name for the map segment `D E2C204 PCHIST
        # size = 128' (fim/m68k/trace.s reaches PCHIST_$ADDR as +0x20)
        'PCHIST_$CONTROL': 0x00E2C204,
        # module-local labels of the hand-written PROC1_ASM and
        # TIME_ASM segments (names of ours; the map has none)
        'proc1_$ec_waitn': 0x00E2065A,              # ec/m68k/wait.s
        'proc1_$get_current_cpu_time': 0x00E208D0,  # proc1/m68k/get_cput.s
        'proc1_$set_lock_body': 0x00E20AE8,         # proc1/m68k/set_lock.s
        'proc1_$clr_lock_body': 0x00E20B9E,         # proc1/m68k/clr_lock.s
        'proc1_$release_tail': 0x00E20EB6,          # ml/m68k/exclusion.s
        'time_$read_cal_body': 0x00E2ADFC,          # time/m68k/time_asm.s
        'time_$read_cal_delay_20': 0x00E2AF54,      # time/m68k/time_asm.s
        'time_$read_cal_delay': 0x00E2AF58,         # time/m68k/time_asm.s
        # misc/m68k/crash_report.s: the report block, the start of its section
        # (the map names only its fields)
        'CRASH_REPORT': 0x00E1E97E,
    },
    3: {
        # The SAU3's addresses of the SAU2's labels, each at the SAU2's
        # distance from the same map symbol (`SYMBOL + off'), the bytes
        # there the same.
        # io/m68k/trap.s: IO_$COND_SWITCH_BACK + 0x16, in `D E2D400
        # IO_$TBLS'
        'io_$flih_dispatch': 0x00E2D45C,
        # fim/m68k/com.s, soft_fault.s, fp_exceptions.s: `D E202D8
        # FIM_UNWIRED size = 4F0', the SAU2's laid out the same
        'FIM_COMMON_FAULT': 0x00E202D8,         # segment start
        'FIM_COM': 0x00E202DC,                  # alias of FIM_$COM
        'FIM_SOFT_FAULT_TAIL': 0x00E20390,      # FIM_$SOFT_FAULT+0xC
        'FIM_SOFT_FAULT_PUSH': 0x00E2039A,      # FIM_$SOFT_FAULT+0x16
        'fim_fp_frame_pc': 0x00E20456,          # FIM_$FP_SIG_NAN+0xE
        # fim/m68k/bus_err.s: `jmp (BUS_ERROR_SWITCH).l' after the
        # SAU3's CPU_B_PBU_SWITCH word (0xE20802), its operand the cell
        # BUS_ERROR_SWITCH (0xE20806), as on the SAU5
        'JMP_TO_BUS_ERR': 0x00E20804,
        # fim/m68k/bus_err.s: the two zero bytes after FP_$OWNER + 0x12
        # that align FIM_$BUS_ERR (0xE20824), as on the SAU5
        'fim_bus_err_align': 0x00E20822,
        # mmu/m68k/installi.s, internal.s: MMU_$INSTALL + 0x54,
        # MMU_$REMOVE_LIST + 0x3A in `D E22D00 MMU_ASM size = 5B8'
        'mmu_$installi': 0x00E23070,
        'mmu_$remove_internal': 0x00E22DA0,
        # PROC1_ASM (`D E1DA00 PROC1_ASM size = 24A4', the SAU2's size):
        # each label at the SAU2's distance from the map symbol before it
        'proc1_$pcb_pool': 0x00E1DB0A,          # PROC1_$READY_COUNT + 2
        'atomic_op_error': 0x00E1F926,          # PROC1_$BEGIN_ATOMIC_OP + 8
        'set_lock_crash': 0x00E1FA8E,           # ML_$LOCK + 0x44
        'clr_lock_crash': 0x00E1FA8E,
        'Illegal_lock_err': 0x00E1FD1C,         # LOCK_$EVENT_LISTS + 0x200
        'proc1_$ec_waitn': 0x00E1F592,          # EC_$WAITN + 0x1C
        'proc1_$get_current_cpu_time': 0x00E1F808,  # PROC1_$GET_CPU_USAGE + 0x26
        'proc1_$set_lock_body': 0x00E1FA20,     # PROC1_$SET_LOCK + 4
        'proc1_$clr_lock_body': 0x00E1FAD6,     # PROC1_$CLR_LOCK + 0xC
        'proc1_$release_tail': 0x00E1FDEE,      # PROC1_$INHIBIT_END + 0x14
        # svc/m68k/svc_tables.s: the dispatch tables after the trap
        # dispatchers in `D E7C708 SVC_CATCHER size = E40' (the SAU2's
        # distances from SVC_$TRAP8)
        'SVC_$TRAP0_TABLE': 0x00E7C9A2,
        'SVC_$TRAP1_TABLE': 0x00E7CA22,
        'SVC_$TRAP2_TABLE': 0x00E7CB2A,
        'SVC_$TRAP3_TABLE': 0x00E7CD3E,
        'SVC_$TRAP4_TABLE': 0x00E7CFAA,
        'SVC_$TRAP5_TABLE': 0x00E7D1B6,
        'SVC_$TRAP7_TABLE': 0x00E7D342,
        'SVC_$TRAP8_TABLE': 0x00E7D42E,
        'SVC_$TRAP8_ARGCOUNT': 0x00E7D50E,
        # time/m68k/time_asm.s, timer_handler.s: `D E29768 TIME_ASM size
        # = 474' (the calendar read 0xE bytes shorter, `calendar_own_page')
        'time_$read_cal_body': 0x00E29768,
        'time_$read_cal_delay_20': 0x00E298B2,  # TIME_$READ_CAL - 0xA
        'time_$read_cal_delay': 0x00E298B6,
        'TIME_$TIMER_HANDLER': 0x00E29A8C,      # TIME_$DI_RTE + 0x10
        # io/m68k/probe.s: `D E27AA4 TESTPAGE size = 60'
        'io_$probe': 0x00E27AA4,
        # `D E2AAE8 PCHIST size = 128' (PCHIST_$ADDR at +0x20)
        'PCHIST_$CONTROL': 0x00E2AAE8,
        # misc/m68k/crash_report.s: the report block after FIM_$CRASH's
        # template in the SAU3's CRASH_SYSTEM (FIM_$CRASH + 0x11A, as on
        # the SAU2)
        'CRASH_REPORT': 0x00E1D97E,
        # fp/m68k/fp_context.s: the SAU2's distances from FIM_$FLINE
        # (0xE20A1C) and FP_$GET_FP (0xE20C98)
        'fp_$switch_owner': 0x00E20A60,
        'fp_$restore_state': 0x00E20A80,
        'fp_$save_state': 0x00E20AAC,
        'fp_$check_owner': 0x00E20CC0,
        # stop/m68k/watch.s: the SAU2's distances from STOP_$WATCH and
        # STOP_$WATCH_TRACE
        'STOP_$MEASURE_LOOP': 0x00E8302A,
        'STOP_$NULL_PROC': 0x00E83052,
        'STOP_$UNHOOK': 0x00E830F6,
        'STOP_$HOOK': 0x00E8311E,
        'STOP_$READ_CPUT': 0x00E83268,
        'STOP_$READ_CLOCK': 0x00E83270,
        'stop_$watch_trace_exit': 0x00E83286,
    },
    5: {
        # io/m68k/trap.s: the dispatcher after IO_$COND_SWITCH_BACK in
        # `D E2FC00 IO_$TBLS size = 480' (IO_$FLIH_TAB 0xE2FC80 - 0x24; the
        # SAU2's IO_$TBLS + 0x5C, the same bytes but PROC1_$INT_EXIT's)
        'io_$flih_dispatch': 0x00E2FC5C,
        # smd/sau5/smd_utils.s: the SMD_UTILS bodies in `I E72838
        # SMD_UTILS size = 4C0' (the map names only SMD_$INVERT_DISP
        # there, at +0x82; the entries are the .DATA stubs at 0xE8BD5C)
        'smd_$copy_font_to_hdm_body': 0x00E72838,
        'smd_$write_str_clip_body': 0x00E728FC,
        'smd_$clear_window_body': 0x00E72BE2,
        'smd_$horiz_line_body': 0x00E72C6E,
        'smd_$vert_line_body': 0x00E72CC6,
        # smd/sau5/wired_proc.s: the bodies of the SMD_WIRED code segment
        # `I E15D3C SMD_WIRED size = 69C' (the map names only
        # SMD_$LOCK_DISPLAY and SMD_$BIT_SET there), reached by absolute
        # address from the trampolines of the data segment
        'smd_$xor_cursor_body': 0x00E15D3C,     # the segment start
        'smd_$or_cursor_body': 0x00E15D46,
        'smd_$start_scroll_body': 0x00E162BA,
        'smd_$continue_scroll_body': 0x00E162EE,
        'smd_$start_blt_body': 0x00E16370,
        # fim/m68k/com.s, soft_fault.s, fp_exceptions.s: the same points of
        # the SAU5's FIM_UNWIRED (`D E22068 FIM_UNWIRED size = 4F0', the
        # SAU2's laid out 0xCC8 higher; the bytes at each are the SAU2's)
        'FIM_COMMON_FAULT': 0x00E22068,         # segment start
        'FIM_COM': 0x00E2206C,                  # alias of FIM_$COM
        'FIM_SOFT_FAULT_TAIL': 0x00E22120,      # FIM_$SOFT_FAULT+0xC
        'FIM_SOFT_FAULT_PUSH': 0x00E2212A,      # FIM_$SOFT_FAULT+0x16
        'fim_fp_frame_pc': 0x00E221E6,          # inside FIM_$FP_SIG_NAN
        # fim/m68k/bus_err.s: `jmp (BUS_ERROR_SWITCH).l' (4ef9 at 0xE22594,
        # its operand the cell BUS_ERROR_SWITCH 0xE22596), after the
        # SAU5's CPU_B_PBU_SWITCH word (0xE22592)
        'JMP_TO_BUS_ERR': 0x00E22594,
        # fim/m68k/bus_err.s: the SAU5's two zero bytes after FP_$EXCLUSION
        # (0xE225A0 + 0x12) that align FIM_$BUS_ERR (0xE225B4)
        'fim_bus_err_align': 0x00E225B2,
        # misc/m68k/crash_system.s: the register-argument console routine
        # FIM_$CRASH calls, CRASH_SHOW_STRING + 0x10 as on the SAU2
        # (0xE1F3B8 + 0x10; FIM_$CRASH's `jsr (d16,PC)' reaches it)
        'crash_puts_string': 0x00E1F3C8,
        # mmu/m68k/installi.s, internal.s: the same module-local entries of
        # the SAU5's MMU_ASM (`D E24B84 MMU_ASM size = 5B8', the SAU2's laid
        # out 0xE58 higher): MMU_$INSTALL + 0x54, MMU_$REMOVE_LIST + 0x3A
        'mmu_$installi': 0x00E24EF4,
        'mmu_$remove_internal': 0x00E24C24,
        # proc1/, ec/, ml/: the SAU2's PROC1_ASM labels in the SAU5's
        # (`D E1F790 PROC1_ASM size = 24A4', every map symbol of the
        # segment 0xCC8 above the SAU2's, same size)
        'proc1_$pcb_pool': 0xE1F89A,
        'atomic_op_error': 0x00E216B6,
        'set_lock_crash': 0x00E2181E,
        'clr_lock_crash': 0x00E2181E,
        'Illegal_lock_err': 0x00E21AAC,
        'proc1_$ec_waitn': 0x00E21322,
        'proc1_$get_current_cpu_time': 0x00E21598,
        'proc1_$set_lock_body': 0x00E217B0,
        'proc1_$clr_lock_body': 0x00E21866,
        'proc1_$release_tail': 0x00E21B7E,
        # svc/m68k/svc_tables.s: the dispatch tables after the trap
        # dispatchers in the SAU5's SVC_CATCHER (`D E82308 SVC_CATCHER size
        # = E40', the SAU2's laid out 0x72C4 higher, same size)
        'SVC_$TRAP0_TABLE': 0x00E825A2,
        'SVC_$TRAP1_TABLE': 0x00E82622,
        'SVC_$TRAP2_TABLE': 0x00E8272A,
        'SVC_$TRAP3_TABLE': 0x00E8293E,
        'SVC_$TRAP4_TABLE': 0x00E82BAA,
        'SVC_$TRAP5_TABLE': 0x00E82DB6,
        'SVC_$TRAP7_TABLE': 0x00E82F42,
        'SVC_$TRAP8_TABLE': 0x00E8302E,
        'SVC_$TRAP8_ARGCOUNT': 0x00E8310E,
        # time/m68k/time_asm.s, timer_handler.s: the SAU5's TIME_ASM (`D
        # E2BF38 TIME_ASM size = 484', the SAU2's 0x113C higher, same size)
        'time_$read_cal_body': 0x00E2BF38,
        'time_$read_cal_delay_20': 0x00E2C090,
        'time_$read_cal_delay': 0x00E2C094,
        'TIME_$TIMER_HANDLER': 0x00E2C26C,      # after TIME_$DI_RTE + 0x12
        # io/m68k/probe.s: the SAU5 map's TESTPAGE (`D E2A260 TESTPAGE size
        # = 74')
        'io_$probe': 0x00E2A260,
        # the SAU5 map's `D E2D340 PCHIST size = 128' (PCHIST_$ADDR at +0x20)
        'PCHIST_$CONTROL': 0x00E2D340,
        # misc/m68k/crash_report.s: the report block after FIM_$CRASH's
        # template in the SAU5's CRASH_SYSTEM (as IMAGE_ALIASES below)
        'CRASH_REPORT': 0x00E1F648,
        # fp/m68k/fp_context.s: the same routines of the SAU5's FIM_$FLINE
        # and FP_$GET_FP runs (FIM_$FLINE 0xE227E8 + 0x44 .. FIM_$FP_ABORT
        # 0xE2289C, FP_$GET_FP 0xE22A64 + 0x28; the SAU2's distances)
        'fp_$switch_owner': 0x00E2282C,
        'fp_$switch_owner_d2': 0x00E22832,     # fp_$switch_owner + 6
        'fp_$restore_state': 0x00E2284C,
        'fp_$save_state': 0x00E22878,
        'fp_$check_owner': 0x00E22A8C,
    },
    9: {
        # The SAU9's addresses of the SAU2's labels, each at the SAU2's
        # distance from the same map symbol (`SYMBOL + off'), the bytes
        # there the same.
        # io/m68k/trap.s: IO_$COND_SWITCH_BACK + 0x16, in the second
        # `D 3C434400 IO_$TBLS size = 488'
        'io_$flih_dispatch': 0x3C43445C,
        # fim/m68k/com.s, soft_fault.s, fp_exceptions.s: `D 3C423FB0
        # FIM_UNWIRED size = 4F0', the SAU2's laid out the same
        'FIM_COMMON_FAULT': 0x3C423FB0,         # segment start
        'FIM_COM': 0x3C423FB4,                  # alias of FIM_$COM
        'FIM_SOFT_FAULT_TAIL': 0x3C424068,      # FIM_$SOFT_FAULT+0xC
        'FIM_SOFT_FAULT_PUSH': 0x3C424072,      # FIM_$SOFT_FAULT+0x16
        'fim_fp_frame_pc': 0x3C42412E,          # FIM_$FP_SIG_NAN+0xE
        # fim/m68k/bus_err.s: `jmp (BUS_ERROR_SWITCH).l' at FIM_$TRACE_BIT
        # + 0x3A (its operand the cell BUS_ERROR_SWITCH 0x3C4244DC)
        'JMP_TO_BUS_ERR': 0x3C4244DA,
        # PROC1_ASM (`D 3C4216C4 PROC1_ASM size = 24B8'): each label at
        # the SAU2's distance from the map symbol before it
        'proc1_$pcb_pool': 0x3C4217CE,          # PROC1_$READY_COUNT + 2
        'proc1_$ec_waitn': 0x3C423256,          # EC_$WAITN + 0x1C
        'proc1_$get_current_cpu_time': 0x3C4234CC,  # PROC1_$GET_CPU_USAGE + 0x26
        'atomic_op_error': 0x3C4235EA,          # PROC1_$BEGIN_ATOMIC_OP + 8
        'proc1_$set_lock_body': 0x3C4236F8,     # PROC1_$SET_LOCK + 4
        'set_lock_crash': 0x3C423766,           # ML_$LOCK + 0x44
        'clr_lock_crash': 0x3C423766,
        'proc1_$clr_lock_body': 0x3C4237AE,     # PROC1_$CLR_LOCK + 0xC
        'Illegal_lock_err': 0x3C4239F4,         # LOCK_$EVENT_LISTS + 0x200
        'proc1_$release_tail': 0x3C423AC6,      # PROC1_$INHIBIT_END + 0x14
        # svc/m68k/svc_tables.s: the dispatch tables after the trap
        # dispatchers in `D 3C48C308 SVC_CATCHER size = E40' (the SAU2's
        # distances from SVC_$TRAP8)
        'SVC_$TRAP0_TABLE': 0x3C48C5A2,
        'SVC_$TRAP1_TABLE': 0x3C48C622,
        'SVC_$TRAP2_TABLE': 0x3C48C72A,
        'SVC_$TRAP3_TABLE': 0x3C48C93E,
        'SVC_$TRAP4_TABLE': 0x3C48CBAA,
        'SVC_$TRAP5_TABLE': 0x3C48CDB6,
        'SVC_$TRAP7_TABLE': 0x3C48CF42,
        'SVC_$TRAP8_TABLE': 0x3C48D02E,
        'SVC_$TRAP8_ARGCOUNT': 0x3C48D10E,
        # io/m68k/probe.s: `D 3C42C830 TESTPAGE size = 74'
        'io_$probe': 0x3C42C830,
        # `D 3C4306DC PCHIST size = 128' (PCHIST_$ADDR at +0x20)
        'PCHIST_$CONTROL': 0x3C4306DC,
        # misc/m68k/crash_report.s: the report block after FIM_$CRASH's
        # template in the SAU9's CRASH_SYSTEM (FIM_$CRASH + 0x106)
        'CRASH_REPORT': 0x3C421602,
        # stop/m68k/watch.s: the SAU2's distances from STOP_$WATCH and
        # STOP_$WATCH_TRACE
        'STOP_$MEASURE_LOOP': 0x3C49A09A,
        'STOP_$NULL_PROC': 0x3C49A0C2,
        'STOP_$UNHOOK': 0x3C49A166,
        'STOP_$HOOK': 0x3C49A18E,
        'STOP_$READ_CPUT': 0x3C49A2D8,
        'STOP_$READ_CLOCK': 0x3C49A2E0,
        'stop_$watch_trace_exit': 0x3C49A2F6,
        # time/sau9/time_asm.s: the calendar register's cell and the
        # calendar read's body at the start of `D 3C42E508 TIME_ASM size =
        # 560', and the tick interrupt after TIME_$DI_RTE (+ 0x12)
        'time_$read_cal_cal': 0x3C42E508,
        'time_$read_cal_body': 0x3C42E50C,
        'TIME_$TIMER_HANDLER': 0x3C42E8C8,
        # mono9/sau9/mono9_asm.s: the two cells before DISP_QUERY at the
        # start of `D 3C43348C MONO9_ASM size = 100'
        'vtga_addr': 0x3C43348C,
        # scsi/sau9/scsi_asm.s: UTIL_PIO's cell before SCSI_$HP_READ at the
        # start of `D 3C43358C SCSI_ASM size = 50'
        'scsi_$util_pio': 0x3C43358C,
        # fim/m68k/fline.s: FIM_$BUS_ERR's FPU entry, 8 bytes ahead of
        # FIM_$FLINE (0x3C42471C) in its section
        'fim_fline_fault_entry': 0x3C424714,
        # fp/m68k/fp_context.s: the FP context helpers after FIM_$FLINE's
        # code (FIM_$FLINE + 0x5E .. FIM_$FP_ABORT 0x3C4247EC) and after
        # FP_$GET_FP (+ 0x28); the SAU2's distances, FIM_$FLINE's 0x1A
        # bytes of memory-error clearing and MMU_CCR's 2 more bytes added
        'fp_$switch_owner': 0x3C42477A,
        'fp_$switch_owner_d2': 0x3C424780,
        'fp_$restore_state': 0x3C42479C,
        'fp_$save_state': 0x3C4247C8,
        'fp_$check_owner': 0x3C4249DC,
        # fim/sau9/nmi.s: FIM_$NMI's fault path after FIM_$SPUR_CNT's
        # cells (FIM_$SPUR_CNT 0x3C424BEA + 6)
        'fim_$nmi_fault': 0x3C424BF0,
    },
}

# Runs whose code is restructured relative to the image (not a matter of
# address operands): the comparison stops at the first difference in the
# run, which is reported with the reason.  {(object path suffix, run
# symbol): reason}.  An entry that no longer diverges fails the check, so
# the list cannot go stale.
KNOWN_DEVIATIONS = {
    2: {
    },
    3: {
    },
    5: {
    },
    9: {
    },
}

# Base registers a routine addresses its module data through, where our
# file writes the cell as an absolute (symbol) operand instead of the
# image's (d16,An): {section: {address register number: image value}}.
REGISTER_BASES = {
    2: {
        # stop/m68k/watch.s: A2 = A5 = STOP_$WATCH (0xE81814), the STOP_WATCH
        # module base; the cells are STOP_$DATA fields
        '.text.STOP_$WATCH_UII': {2: 0x00E81814, 5: 0x00E81814},
        # smd/sau2/cursor_thunks.s: the shared cursor body's A5 = A0 =
        # SMD_$DISP1_INT (0xE26F20), handed in by the trampolines; the dispatch
        # cells and SMD_$CURSOR_TABLE are named instead of (d16,A5)
        '.text.SMD_$OR_CURSOR': {5: 0x00E26F20},
        # mmu/m68k/init.s: A5 = M68020 (0xE23D2E); (0x5a6,A5) is CACHE_$CLEAR
        '.text.MMU_$INIT': {5: 0x00E23D2E},
        # fim/m68k/crash.s: A5 = CRASH_SYSTEM (0xE1E700), the base of the
        # image's CRASH_SYSTEM module; the report fields FIM_$CRASH stores are
        # named (its own template, CRASH_REPORT + 0x68)
        '.text.FIM_$CRASH': {5: 0x00E1E700},
        # fim/m68k/deliver_trace_fault.s, clear_trace_fault.s, exit.s: the
        # FIM_WIRED base FIM_$TRACE_BIT (0xE21890) in A1 / A5; (0x76e,An) is
        # PENDING_TRACE_FAULTS, (0x102c,An) FIM_$EXIT
        '.text.FIM_$DELIVER_TRACE_FAULT': {1: 0x00E21890},
        '.text.FIM_$CLEAR_TRACE_FAULT': {1: 0x00E21890},
        '.text.FIM_$EXIT': {5: 0x00E21890},
    },
    3: {
        # stop/m68k/watch.s: A2 = A5 = STOP_$WATCH (0xE82F28), as on the
        # SAU2
        '.text.STOP_$WATCH_UII': {2: 0x00E82F28, 5: 0x00E82F28},
        # fim/m68k/crash.s: A5 = CRASH_SYSTEM (`D E1D700 CRASH_SYSTEM size
        # = 2F8'), as on the SAU2
        '.text.FIM_$CRASH': {5: 0x00E1D700},
        # fim/m68k/deliver_trace_fault.s, clear_trace_fault.s, exit.s: the
        # FIM_WIRED base FIM_$TRACE_BIT (0xE207C8) in A1 / A5, as on the SAU2
        '.text.FIM_$DELIVER_TRACE_FAULT': {1: 0x00E207C8},
        '.text.FIM_$CLEAR_TRACE_FAULT': {1: 0x00E207C8},
        '.text.FIM_$EXIT': {5: 0x00E207C8},
        # mmu/m68k/init.s: A5 = M68020 (0xE22D02), as on the SAU2
        '.text.MMU_$INIT': {5: 0x00E22D02},
    },
    5: {
        # fim/m68k/crash.s: A5 = CRASH_SYSTEM (`D E1F300 CRASH_SYSTEM size =
        # 3BC'), as on the SAU2
        '.text.FIM_$CRASH': {5: 0x00E1F300},
        # fim/m68k/deliver_trace_fault.s, clear_trace_fault.s, exit.s: the
        # FIM_WIRED base FIM_$TRACE_BIT (0xE22558) in A1 / A5, as on the SAU2
        '.text.FIM_$DELIVER_TRACE_FAULT': {1: 0x00E22558},
        '.text.FIM_$CLEAR_TRACE_FAULT': {1: 0x00E22558},
        '.text.FIM_$EXIT': {5: 0x00E22558},
        # mmu/m68k/init.s: A5 = M68020 (0xE24B86), as on the SAU2
        '.text.MMU_$INIT': {5: 0x00E24B86},
    },
    9: {
        # fim/m68k/deliver_trace_fault.s, clear_trace_fault.s, exit.s: the
        # FIM_WIRED base FIM_$TRACE_BIT (0x3C4244A0) in A1 / A5, as on the
        # SAU2
        '.text.FIM_$DELIVER_TRACE_FAULT': {1: 0x3C4244A0},
        '.text.FIM_$CLEAR_TRACE_FAULT': {1: 0x3C4244A0},
        '.text.FIM_$EXIT': {5: 0x3C4244A0},
    },
}

# Code in the hand-written files that is NOT image code: a run starting at
# one of these symbols is not compared (it is counted and reported).
ADDITIONS = {
    2: {
        # C-callable register-marshalling shims for stop/watch.c
        'stop_$measure_loop': 'stop/m68k/watch.s C-callable wrappers',
    },
    3: {
    },
    5: {
    },
    9: {
    },
}

# C objects whose names are not the map's, with the image address of the
# cell they stand for (used only to verify relocations).
IMAGE_ALIASES = {
    2: {
        # smd/smd_data.c: the map's SMD_$DISPLAY_COM (gen_layout_ld ANCHORS).
        'SMD_DISPLAY_INFO': 0x00E27376,
        # misc/crash_system.c: the report block and SR stash inside the image's
        # CRASH_SYSTEM segment (the map names neither)
        'CRASH_REPORT': 0x00E1E97E,
        'CRASH_SAVED_SR': 0x00E1E7B6,
        # log/log_data.c: map segment `D E00000 CRASH_RECORD size = C'
        'CRASH_$RECORD': 0x00E00000,
        # svc/svc_internal.h: the dispatch tables after the trap dispatchers
        # inside SVC_CATCHER
        'SVC_$TRAP0_TABLE': 0x00E7B2DE,
        'SVC_$TRAP1_TABLE': 0x00E7B35E,
        'SVC_$TRAP2_TABLE': 0x00E7B466,
        'SVC_$TRAP3_TABLE': 0x00E7B67A,
        'SVC_$TRAP4_TABLE': 0x00E7B8E6,
        'SVC_$TRAP5_TABLE': 0x00E7BAF2,
        'SVC_$TRAP7_TABLE': 0x00E7BC7E,
        'SVC_$TRAP8_TABLE': 0x00E7BD6A,
        'SVC_$TRAP8_ARGCOUNT': 0x00E7BE4A,
        # proc1/proc1.h: PROC1_ASM cells the map does not name
        'PROC1_$ATOMIC_OP_DEPTH': 0x00E2060E,
        'DAT_00e20606': 0x00E20606,
        # proc1/proc1_data.c: the crash status reached by `pea (0x3f8,PC)' at
        # 0x00E209EE
        'Bad_atomic_operation_err': 0x00E20DE8,
        # time/time_data.c: the TIME_ASM cells TIME_$TIMER_HANDLER reaches that
        # the map does not name (TIME_$CURRENT_TIME + 4, and the word before
        # TIME_$SET_VECTOR)
        'TIME_$CURRENT_USEC': 0x00E2B0F4,
        'time_$mcr_countdown': 0x00E2B100,
    },
    3: {
        # misc's report block and SR stash in the SAU3's CRASH_SYSTEM (the
        # SAU2's distances from CRASH_SYSTEM, 0x1000 lower)
        'CRASH_REPORT': 0x00E1D97E,
        'CRASH_SAVED_SR': 0x00E1D7B6,
        # PROC1_ASM cells the map does not name, at the SAU2's distances
        'PROC1_$ATOMIC_OP_DEPTH': 0x00E1F546,   # PROC1_$PID_TN + 2
        'DAT_00e20606': 0x00E1F53E,             # DI_$Q_HEAD + 4
        'Bad_atomic_operation_err': 0x00E1FD20,  # LOCK_$EVENT_LISTS + 0x204
        # the SVC dispatch tables (as LOCAL_SYMBOLS above)
        'SVC_$TRAP0_TABLE': 0x00E7C9A2,
        'SVC_$TRAP1_TABLE': 0x00E7CA22,
        'SVC_$TRAP2_TABLE': 0x00E7CB2A,
        'SVC_$TRAP3_TABLE': 0x00E7CD3E,
        'SVC_$TRAP4_TABLE': 0x00E7CFAA,
        'SVC_$TRAP5_TABLE': 0x00E7D1B6,
        'SVC_$TRAP7_TABLE': 0x00E7D342,
        'SVC_$TRAP8_TABLE': 0x00E7D42E,
        'SVC_$TRAP8_ARGCOUNT': 0x00E7D50E,
        # TIME_ASM cells the map does not name
        'TIME_$CURRENT_USEC': 0x00E29A52,       # TIME_$CURRENT_TIME + 4
        'time_$mcr_countdown': 0x00E29A5E,      # TIME_$CURRENT_DELTA + 4
    },
    5: {
        # misc's report block, after FIM_$CRASH's template in the SAU5's
        # CRASH_SYSTEM (FIM_$CRASH 0xE1F52C + 0x11C: "\n\n\n\r\r\nCrash_Status")
        'CRASH_REPORT': 0x00E1F648,
        # PROC1_ASM cells the map does not name, 0xCC8 above the SAU2's
        'PROC1_$ATOMIC_OP_DEPTH': 0x00E212D6,
        'DAT_00e20606': 0x00E212CE,
        'Bad_atomic_operation_err': 0x00E21AB0,
        # the SVC dispatch tables (as LOCAL_SYMBOLS above)
        'SVC_$TRAP0_TABLE': 0x00E825A2,
        'SVC_$TRAP1_TABLE': 0x00E82622,
        'SVC_$TRAP2_TABLE': 0x00E8272A,
        'SVC_$TRAP3_TABLE': 0x00E8293E,
        'SVC_$TRAP4_TABLE': 0x00E82BAA,
        'SVC_$TRAP5_TABLE': 0x00E82DB6,
        'SVC_$TRAP7_TABLE': 0x00E82F42,
        'SVC_$TRAP8_TABLE': 0x00E8302E,
        'SVC_$TRAP8_ARGCOUNT': 0x00E8310E,
        # TIME_ASM cells the map does not name, 0x113C above the SAU2's
        'TIME_$CURRENT_USEC': 0x00E2C230,
        'time_$mcr_countdown': 0x00E2C23C,
    },
    9: {
        # misc's report block (as LOCAL_SYMBOLS above)
        'CRASH_REPORT': 0x3C421602,
        # PROC1_ASM cells the map does not name, at the SAU2's distances
        'PROC1_$ATOMIC_OP_DEPTH': 0x3C42320A,   # PROC1_$PID_TN + 2
        'DAT_00e20606': 0x3C423202,             # DI_$Q_HEAD + 4
        'Bad_atomic_operation_err': 0x3C4239F8,  # LOCK_$EVENT_LISTS + 0x204
        # the SVC dispatch tables (as LOCAL_SYMBOLS above)
        'SVC_$TRAP0_TABLE': 0x3C48C5A2,
        'SVC_$TRAP1_TABLE': 0x3C48C622,
        'SVC_$TRAP2_TABLE': 0x3C48C72A,
        'SVC_$TRAP3_TABLE': 0x3C48C93E,
        'SVC_$TRAP4_TABLE': 0x3C48CBAA,
        'SVC_$TRAP5_TABLE': 0x3C48CDB6,
        'SVC_$TRAP7_TABLE': 0x3C48CF42,
        'SVC_$TRAP8_TABLE': 0x3C48D02E,
        'SVC_$TRAP8_ARGCOUNT': 0x3C48D10E,
        # TIME_ASM cells the map does not name
        'TIME_$CURRENT_USEC': 0x3C42E870,       # TIME_$CURRENT_TIME + 4
    },
}

# Sections whose module base register points at a different object in our
# file than in the image: {section: (register, image base, our base symbol)}.
# Every (d16,An) displacement then differs by the same amount (our base's
# image address - the image base), and the `lea ...,An' that sets it up
# names our base.  misc/m68k/crash_system.s: A5 = CRASH_REPORT (0xE1E97E)
# instead of the code base 0xE1E700, so (0x28e,A5) is written (0x10,A5).
REBASES = {
    2: {
        '.text.CRASH_SYSTEM': (5, 0x00E1E700, 'CRASH_REPORT'),
    },
    3: {
        # misc/m68k/crash_system.s: as on the SAU2, A5 = CRASH_REPORT
        # (0xE1D97E) for the image's CRASH_SYSTEM base (0xE1D700)
        '.text.CRASH_SYSTEM': (5, 0x00E1D700, 'CRASH_REPORT'),
    },
    5: {
        # misc/m68k/crash_system.s: as on the SAU2, A5 = CRASH_REPORT
        # (0xE1F648) for the image's CRASH_SYSTEM base (0xE1F300)
        '.text.CRASH_SYSTEM': (5, 0x00E1F300, 'CRASH_REPORT'),
    },
    9: {
    },
}

RELOC_RE = re.compile(r'^([0-9a-f]{8}) (R_68K_\S+)\s+(\S+?)(?:([+-])0x([0-9a-f]+))?$')


def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True,
                          text=True).stdout


class Obj:
    def __init__(self, path, objdump):
        self.path = path
        self.sections = {}      # name -> (size, bytes)
        self.symbols = {}       # name -> (section, value)
        self.relocs = {}        # section -> [(offset, type, sym, addend)]
        hdr = run([objdump, '-h', path])
        for line in hdr.splitlines():
            f = line.split()
            if len(f) >= 7 and f[0].isdigit() and \
                    gen_layout_ld.is_code_section(f[1]) and int(f[2], 16):
                self.sections[f[1]] = int(f[2], 16)
        self.data = {}
        for sec in self.sections:
            out = run([objdump, '-s', '-j', sec, path])
            data = bytearray()
            for line in out.splitlines():
                m = re.match(r'^ ([0-9a-f]{4,}) ((?:[0-9a-f]{2,8} ?){1,4})', line)
                if m:
                    data += bytes.fromhex(m.group(2).replace(' ', ''))
            self.data[sec] = bytes(data[:self.sections[sec]])
        self.globals = set()    # global symbols this object defines
        for line in run([objdump, '-t', path]).splitlines():
            m = gen_layout_ld.SYMTAB_RE.match(line)
            if not m:
                continue
            flags = m.group('flags')
            if flags[0] in 'gu' and m.group('sec') not in ('*UND*', '*COM*'):
                self.globals.add(m.group('name').strip())
            if flags[6] == 'f':
                continue
            sec = m.group('sec')
            if sec not in self.sections:
                continue
            name = m.group('name').strip()
            if flags[5] == 'd':
                name = sec
            self.symbols.setdefault(name, (sec, int(m.group('value'), 16)))
        self.insns = {}         # section -> instruction start offsets
        for sec in self.sections:
            starts = []
            for line in run([objdump, '-d', '-m', 'm68k:68020', '-j', sec,
                             path]).splitlines():
                # an instruction line has a mnemonic after the hex; a long
                # instruction's continuation line has none
                m = re.match(r'^\s+([0-9a-f]+):\t[0-9a-f]{4}[0-9a-f ]*\t\S',
                             line)
                if m:
                    starts.append(int(m.group(1), 16))
            self.insns[sec] = sorted(starts)
        cur = None
        for line in run([objdump, '-r', path]).splitlines():
            m = re.match(r'^RELOCATION RECORDS FOR \[(.*)\]:', line)
            if m:
                cur = m.group(1)
                continue
            m = RELOC_RE.match(line.strip())
            if m and cur in self.sections:
                add = int(m.group(5), 16) if m.group(5) else 0
                if m.group(4) == '-':
                    add = -add
                self.relocs.setdefault(cur, []).append(
                    (int(m.group(1), 16), m.group(2), m.group(3), add))


RELOC_SIZE = {'R_68K_32': 4, 'R_68K_16': 2, 'R_68K_8': 1,
              'R_68K_PC32': 4, 'R_68K_PC16': 2, 'R_68K_PC8': 1}


_SEGS = {}


def segment_addr(linkmap):
    """{segment name: address} of the first segment of each name (the
    code segment comes first: `I E6B0A4 VFMT_$WRITEN' precedes the data
    segment of the same name at 0xE825F4)."""
    if not _SEGS:
        for start, size, name in linkmap.segments:
            _SEGS.setdefault(name, start)
    return _SEGS


def known_addr(sym, linkmap):
    if sym in ADDITIONS[SAU]:
        return -1
    if sym in LOCAL_SYMBOLS[SAU]:
        return LOCAL_SYMBOLS[SAU][sym]
    if sym in linkmap.symbols:
        return linkmap.symbols[sym][0]
    return None


def runs_of(obj, sec, linkmap):
    """[(offset, length, image address, name)] covering the section.

    Runs start at the section's symbols with a known image address, in
    offset order.  The first must be at offset 0 (main() fails a section
    whose bytes ahead of it would go uncompared: a label of the file
    missing from that SAU's LOCAL_SYMBOLS).  None of the hand-written
    files has an alignment pad there.
    A section whose own name is only a map SEGMENT
    name (NULLPROC, VFMT_$WRITEN) starts at that segment."""
    name = sec[len('.text.'):]
    syms = sorted((v, n) for n, (s, v) in obj.symbols.items()
                  if s == sec and n != sec
                  and known_addr(n, linkmap) is not None)
    if not syms or syms[0][0] != 0:
        if known_addr(name, linkmap) is None and \
                name in segment_addr(linkmap):
            syms = [(0, name)] + syms
    if not syms:
        return None
    cuts = {}
    for value, sym in syms:
        addr = known_addr(sym, linkmap)
        if addr is None:
            addr = segment_addr(linkmap)[sym]
        prev = [o for o in cuts if o <= value]
        # a symbol that continues the current run needs no cut
        if prev and addr >= 0 and \
                cuts[max(prev)][0] + (value - max(prev)) == addr:
            continue
        cuts[value] = (addr, sym)
    offs = sorted(cuts)
    size = obj.sections[sec]
    out = []
    for i, o in enumerate(offs):
        end = offs[i + 1] if i + 1 < len(offs) else size
        out.append((o, end - o, cuts[o][0], cuts[o][1]))
    return out


def load_ref(path):
    ref = []
    with open(path) as f:
        for line in f:
            if not line.strip() or line.startswith('#'):
                continue
            a, n, h = line.split(None, 2)
            data = bytes.fromhex(h.strip())
            assert len(data) == int(n, 16), line
            ref.append((int(a, 16), data))
    return ref


def ref_bytes(ref, addr, n):
    if isinstance(ref, ImageRef):
        # --image: the image file, read through the map's `loaded at'
        # sections (None where the image has no bytes: its bss)
        return ref.read(addr, n)
    for a, data in ref:
        if a <= addr and addr + n <= a + len(data):
            return data[addr - a:addr - a + n]
    return None


class ImageFile:
    """One --extract-file window: file offsets lo..hi of an image file,
    file byte `off' at image address base + off."""
    def __init__(self, spec):
        parts = spec.split(':')
        if len(parts) not in (2, 3):
            raise SystemExit('asm_compare: --extract-file %s: expected '
                             'IMAGE:BASE[:LO-HI]' % spec)
        self.path = parts[0]
        self.base = int(parts[1], 0)
        with open(self.path, 'rb') as f:
            self.data = f.read()
        if len(parts) == 3:
            lo, hi = parts[2].split('-')
            self.lo, self.hi = int(lo, 0), int(hi, 0)
        else:
            self.lo, self.hi = 0, len(self.data)
        if not 0 <= self.lo < self.hi <= len(self.data):
            raise SystemExit('asm_compare: --extract-file %s: window outside '
                             'the file (%d bytes)' % (spec, len(self.data)))

    def covers(self, addr, n):
        off = addr - self.base
        return self.lo <= off and off + n <= self.hi

    def read(self, addr, n):
        off = addr - self.base
        return self.data[off:off + n]

    def provenance(self, addr, n):
        off = addr - self.base
        return ('# %06X..%06X: %s file 0x%X..0x%X (image address = file '
                'offset + 0x%X), --extract-file'
                % (addr, addr + n, os.path.basename(self.path), off, off + n,
                   self.base))


def image_file_for(files, addr, n):
    for f in files:
        if f.covers(addr, n):
            return f
    return None


def gsk_read(addr, n):
    out = run(['gsk', 'read', '0x%x' % addr, str(n)])
    data = bytearray()
    for line in out.splitlines():
        m = re.match(r'^([0-9a-f]{8})\s+((?:[0-9a-f]{2}\s+)+)', line)
        if m:
            data += bytes.fromhex(''.join(m.group(2).split()))
    if len(data) < n:
        raise SystemExit('asm_compare: gsk read 0x%x %d returned %d bytes'
                         % (addr, n, len(data)))
    return bytes(data[:n])


class ImageRef(image_file.Image):
    """--image: the SAU's image file, read by address through the map's
    `loaded at' sections (image_file.Image).  A run may also reach
    into the file's padding after a section, up to the next section's
    file offset: COLD's 0x800 bytes are the map's 0x7FC and the image's
    four zero bytes before DUMP at file 0x800 (cold/sau2/cold_start.s),
    the bytes `make asm-ref-image' takes for the SAU2 from file 0..0x800."""

    def read(self, va, n):
        got = super().read(va, n)
        if got is not None:
            return got
        offs = sorted({off for sva, size, off in self.secs})
        for sva, size, off in self.secs:
            if not sva <= va < sva + size:
                continue
            nxt = [o for o in offs if o > off]
            end = min(nxt[0] if nxt else len(self.data), len(self.data))
            o = off + (va - sva)
            if o + n <= end:
                return self.data[o:o + n]
        return None


class Alignment:
    """How one section lines up with the image."""
    def __init__(self):
        self.points = []    # (our offset, image address), ascending
        self.checks = []    # (off, size, P, image value, pcrel, widened)
        self.branches = []  # (insn off, our target off, image target)
        self.rebased = []   # (field off, our displacement, image cell)
        self.widened = 0
        self.aliases = 0
        self.additions = 0
        self.deviations = []  # (run, offset, image address, detail, reason)
        self.error = None

    def image_addr(self, off):
        pts = sorted(self.points)
        best = None
        for o, a in pts:
            if o <= off:
                best = a + (off - o) if a >= 0 else None
        if best is None and pts and off < pts[0][0] and pts[0][1] >= 0:
            # ahead of the first run: bytes before a section's first
            # known symbol, or a PC-relative target in front of the
            # section (a module base such as FIM_$CRASH's CRASH_SYSTEM)
            best = pts[0][1] - (pts[0][0] - off)
        return best


def sext(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


# ALU op with an #imm source in its <ea> form (high nibble) -> the opcode
# base of the matching immediate instruction gas emits for #imm,Dn
ALU_IMM = {0xB: 0x0C00,     # cmp  -> cmpi
           0x9: 0x0400,     # sub  -> subi
           0xD: 0x0600,     # add  -> addi
           0xC: 0x0200,     # and  -> andi
           0x8: 0x0000}     # or   -> ori


def ea_ext_len(mode, reg, size_bytes):
    """Extension bytes of an effective address (brief-format index)."""
    if mode in (5, 6):
        return 2
    if mode == 7:
        return {0: 2, 1: 4, 2: 2, 3: 2,
                4: 4 if size_bytes == 4 else 2}.get(reg, 0)
    return 0


def rebased_fields(opcode, reg):
    """Offsets of the (d16,A<reg>) extension words of an instruction."""
    out = []
    code = 0x28 | reg
    if opcode & 0x3F == code:
        out.append(pc_ext(opcode))
    if 0x1000 <= opcode < 0x4000 and (opcode >> 6) & 0x3F == \
            ((reg << 3) | 5):
        size = {1: 1, 3: 2, 2: 4}[opcode >> 12]
        out.append(2 + ea_ext_len((opcode >> 3) & 7, opcode & 7, size))
    return out


def pc_ext(opcode):
    """Offset of the extension word of the effective address in bits 0-5:
    right after the opcode, or after the register mask of movem, the bit
    number of a static bit operation (btst #n,...) or the immediate of
    cmpi/andi/ori/... (#imm,<ea>)."""
    if opcode & 0xFB80 == 0x4880:
        return 4
    if opcode & 0xFF00 == 0x0800:
        return 4
    if opcode & 0xF100 == 0x0000 and opcode & 0xFF00 != 0x0800:
        return 6 if (opcode >> 6) & 3 == 2 else 4
    return 2


def align(o, sec, runs, ref):
    """Walk our section and the image in step.  Bytes must be equal except
    (a) relocation fields, whose image operand is recorded for pass 2, and
    (b) documented WIDENINGS, where the image's 16-bit PC-relative operand
    was written as an absolute long in our file (the operand's target lives
    in another object, e.g. mmu/m68k/init.s `lea M68020,%a5' for the
    image's `lea (-0xe,PC),A5'); the image's PC-relative target is recorded
    and pass 2 checks that our absolute operand names the same cell.
    Recognised widenings: an effective address (d16,PC) (mode 7/2) written
    as (xxx).l (mode 7/1) in the same opcode word, `bsr' written as
    `jsr (xxx).l' and `bra' as `jmp (xxx).l'."""
    res = Alignment()
    data = o.data[sec]
    starts = o.insns.get(sec, [])
    rel = {off: RELOC_SIZE.get(typ, 0)
           for off, typ, sym, add in o.relocs.get(sec, [])}
    for off, typ, sym, add in o.relocs.get(sec, []):
        if typ not in RELOC_SIZE:
            res.error = 'unhandled relocation %s at +0x%x' % (typ, off)
            return res
    res.points = [(r_off, r_addr) for r_off, r_len, r_addr, r_name in runs]
    for r_off, r_len, r_addr, r_name in runs:
        if res.error:
            break
        if r_addr < 0:
            res.additions += r_len
            continue
        img = ref_bytes(ref, r_addr, r_len)
        if img is None:
            res.error = ('image 0x%06X..0x%06X (%s) is not in the %s'
                         % (r_addr, r_addr + r_len, r_name,
                            "image file's loaded sections"
                            if isinstance(ref, ImageRef)
                            else 'reference file; rerun --extract'))
            return res
        i, j, end = r_off, 0, r_off + r_len

        def fail(at_i, at_j):
            res.error = ('differs at +0x%x (image 0x%06X): ours %s, image %s'
                         % (at_i, r_addr + at_j, data[at_i:at_i + 8].hex(),
                            img[at_j:at_j + 8].hex()))

        while i < end:
            if i in rel:
                n = rel[i]
                want = int.from_bytes(img[j:j + n], 'big')
                res.checks.append((i, n, r_addr + j, want, False, False))
                i += n
                j += n
                continue
            if j < len(img) and data[i] == img[j]:
                i += 1
                j += 1
                continue
            # the instruction holding the difference (our disassembly gives
            # the boundaries); everything before the difference in it is
            # equal, so its image counterpart starts at the same distance
            k = bisect.bisect_right(starts, i) - 1
            oi = starts[k] if k >= 0 and starts[k] >= r_off else i
            oj = j - (i - oi)
            if oj < 0 or oj + 2 > len(img) or oi + 2 > len(data):
                fail(i, j)
                break
            ours = int.from_bytes(data[oi:oi + 2], 'big')
            theirs = int.from_bytes(img[oj:oj + 2], 'big')
            bcc_b = (ours & 0xF000 == 0x6000 and ours >> 8 == theirs >> 8
                     and ours & 0xFF not in (0, 0xFF)
                     and theirs & 0xFF not in (0, 0xFF))
            if ours == theirs or bcc_b:
                # same instruction, different PC-relative displacement: a
                # branch or (d16,PC) operand spanning a widening.  Pass 2
                # checks that both land on the same image address.
                rb = REBASES[SAU].get(sec)
                fields = rebased_fields(ours, rb[0]) if rb else []
                hit = [f for f in fields if oi + f <= i < oi + f + 2]
                if hit and not bcc_b:
                    # (d16,An) on a rebased module base: pass 2 checks that
                    # both displacements name the same image cell
                    f = hit[0]
                    d_ours = sext(int.from_bytes(data[oi + f:oi + f + 2],
                                                 'big'), 16)
                    d_img = sext(int.from_bytes(img[oj + f:oj + f + 2],
                                                'big'), 16)
                    res.rebased.append((oi + f, d_ours, rb[1] + d_img))
                    i = oi + f + 2
                    j = oj + f + 2
                    continue
                if bcc_b:
                    ext, n = 1, 1           # Bcc.b: displacement in the opcode
                elif ours & 0xF000 == 0x6000 and ours & 0xFF == 0:
                    ext, n = 2, 2           # Bcc.w
                elif ours & 0xF0F8 == 0x50C8:
                    ext, n = 2, 2           # DBcc
                elif ours & 0x3F == 0x3A:
                    ext, n = pc_ext(ours), 2  # (d16,PC) source operand
                else:
                    fail(i, j)
                    break
                if not (oi + ext <= i < oi + ext + n) or \
                        data[oi + 2:oi + ext] != img[oj + 2:oj + ext]:
                    fail(i, j)
                    break
                base = 2 if ext == 1 else ext
                d_ours = sext(int.from_bytes(data[oi + ext:oi + ext + n], 'big'), 8 * n)
                d_img = sext(int.from_bytes(img[oj + ext:oj + ext + n], 'big'), 8 * n)
                res.branches.append((oi, oi + base + d_ours,
                                     r_addr + oj + base + d_img))
                i = oi + ext + n
                j = oj + ext + n
                continue
            alu = ALU_IMM.get(theirs >> 12)
            if alu is not None and theirs & 0x13F == 0x03C and \
                    (theirs >> 6) & 3 != 3 and \
                    ours == alu | (theirs & 0xC0) | ((theirs >> 9) & 7):
                # CMP/SUB/ADD/AND/OR #imm,Dn (the Apollo assembler's
                # <ea>=#imm form) written by gas as CMPI/SUBI/ADDI/ANDI/
                # ORI #imm,Dn: same operation, operand, size and flags,
                # same length.  The immediate is compared as usual.
                res.aliases += 1
                i = oi + 2
                j = oj + 2
                continue
            if theirs & 0xF000 == 0x6000 and theirs & 0xFF not in (0, 0xFF) \
                    and ours == theirs & 0xFF00:
                # Bcc.b -> Bcc.w (the target is in another object, or moved
                # out of 8-bit reach by an earlier widening)
                ext, ilen = 2, 2
                target = r_addr + oj + 2 + sext(theirs & 0xFF, 8)
                if oi + 2 not in rel:
                    d = sext(int.from_bytes(data[oi + 2:oi + 4], 'big'), 16)
                    res.branches.append((oi, oi + 2 + d, target))
                else:
                    res.checks.append((oi + 2, 2, r_addr + oj + 2, target,
                                       True, True))
                res.widened += 1
                i = oi + 4
                j = oj + ilen
                res.points.append((i, r_addr + j))
                continue
            rb = REBASES[SAU].get(sec)
            if rb and theirs & 0x3F == 0x3A and \
                    ours == (theirs & 0xFFC0) | 0x28 | rb[0]:
                # (d16,PC) written as (d16,An) on the rebased module base
                f = pc_ext(theirs)
                if data[oi + 2:oi + f] != img[oj + 2:oj + f]:
                    fail(i, j)
                    break
                d_ours = sext(int.from_bytes(data[oi + f:oi + f + 2], 'big'), 16)
                d_img = sext(int.from_bytes(img[oj + f:oj + f + 2], 'big'), 16)
                res.rebased.append((oi + f, d_ours, r_addr + oj + f + d_img))
                i = oi + f + 2
                j = oj + f + 2
                continue
            bases = dict(REGISTER_BASES[SAU].get(sec, {}))
            if rb:
                bases[rb[0]] = rb[1]    # the image's own base value
            dreg = (theirs >> 9) & 7
            if 0x1000 <= theirs < 0x4000 and (theirs >> 6) & 7 == 5 and \
                    dreg in bases and \
                    ours == (theirs & 0xF03F) | 0x03C0:
                # move to (d16,An), An = a known module base -> to (xxx).l
                size = {1: 1, 3: 2, 2: 4}[theirs >> 12]
                ext = 2 + ea_ext_len((theirs >> 3) & 7, theirs & 7, size)
                if oi + ext + 4 > len(data) or \
                        data[oi + 2:oi + ext] != img[oj + 2:oj + ext]:
                    fail(i, j)
                    break
                disp = sext(int.from_bytes(img[oj + ext:oj + ext + 2],
                                           'big'), 16)
                target = bases[dreg] + disp
                ilen = ext + 2
            elif theirs & 0x38 == 0x28 and (theirs & 7) in bases and \
                    ours == (theirs & 0xFFC0) | 0x39:
                # (d16,An) with An = a known module base -> (xxx).l
                ext = pc_ext(theirs)
                if oi + ext + 4 > len(data) or \
                        data[oi + 2:oi + ext] != img[oj + 2:oj + ext]:
                    fail(i, j)
                    break
                disp = sext(int.from_bytes(img[oj + ext:oj + ext + 2],
                                           'big'), 16)
                target = bases[theirs & 7] + disp
                ilen = ext + 2
            elif theirs & 0x3F == 0x3A and ours == theirs - 1:
                # (d16,PC) -> (xxx).l in the same opcode word
                ext = pc_ext(theirs)
                if oi + ext + 4 > len(data) or \
                        data[oi + 2:oi + ext] != img[oj + 2:oj + ext]:
                    fail(i, j)
                    break
                disp = sext(int.from_bytes(img[oj + ext:oj + ext + 2],
                                           'big'), 16)
                target = r_addr + oj + ext + disp
                ilen = ext + 2
            elif ours in (0x4EB9, 0x4EF9) and \
                    theirs >> 8 == (0x61 if ours == 0x4EB9 else 0x60):
                ext = 2     # bsr/bra -> jsr/jmp (xxx).l
                d8 = theirs & 0xFF
                if d8 == 0:
                    disp = sext(int.from_bytes(img[oj + 2:oj + 4], 'big'), 16)
                    ilen = 4
                else:
                    disp = sext(d8, 8)
                    ilen = 2
                target = r_addr + oj + 2 + disp
            else:
                fail(i, j)
                break
            # our operand: 4 bytes at oi+ext, literal or relocated
            res.checks.append((oi + ext, 4, r_addr + oj + ext, target,
                               False, True))
            res.widened += 1
            i = oi + ext + 4
            j = oj + ilen
            res.points.append((i, r_addr + j))
        if res.error:
            key = (o.path, r_name)
            dev = next(((pth, run) for (pth, run) in KNOWN_DEVIATIONS[SAU]
                        if o.path.endswith(pth) and run in (r_name, '*')),
                       None)
            if dev is None:
                return res
            # a documented structural deviation: the run is compared up to
            # its first difference and the rest is reported, not failed
            res.deviations.append((r_name, i, r_addr + j, res.error, dev))
            res.error = None
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--map', required=True)
    ap.add_argument('--sau', type=int, default=2, choices=SAUS,
                    help='the SAU whose image and address tables to use '
                    '(default 2)')
    ap.add_argument('--ref', help='reference image bytes (check mode)')
    ap.add_argument('--image', metavar='IMAGE',
                    help="check mode: take the reference bytes from the "
                    "SAU's image file, read through the map's `loaded at' "
                    "sections, instead of a --ref file")
    ap.add_argument('--extract', metavar='OUT',
                    help='write the reference file from Ghidra (gsk read)')
    ap.add_argument('--extract-file', metavar='IMAGE:BASE[:LO-HI]',
                    action='append', default=[],
                    help='take reference bytes from an image file window '
                    '(file byte off = image address BASE + off); with --ref '
                    'and no --extract, append the missing runs to REF')
    ap.add_argument('--objdump', default='m68k-elf-objdump')
    ap.add_argument('-v', '--verbose', action='store_true')
    ap.add_argument('objects', nargs='+')
    args = ap.parse_args()
    global SAU
    SAU = args.sau
    if args.image and (args.ref or args.extract or args.extract_file):
        raise SystemExit('asm_compare: --image is a check mode of its own '
                         '(no --ref, --extract or --extract-file)')

    linkmap = gen_layout_ld.LinkMap(args.map)
    block_addr = C_BLOCK_ADDRS[SAU]

    objs = [Obj(p, args.objdump) for p in sorted(args.objects)]
    allruns = {}
    errors = []
    # One definition per routine for a given SAU: a global symbol defined
    # by two objects of the check set (a */m68k/*.s file and a */sau<N>/*.s
    # file both holding it) is a link error to come.
    defs = {}
    for o in objs:
        for sym in o.globals:
            defs.setdefault(sym, []).append(o.path)
    for sym, paths in sorted(defs.items()):
        if len(paths) > 1:
            errors.append('%s is defined by %d objects: %s'
                          % (sym, len(paths), ', '.join(paths)))
    for o in objs:
        for sec in o.sections:
            r = runs_of(o, sec, linkmap)
            if r is None:
                errors.append('%s %s: no image address (no map symbol; '
                              'add it to LOCAL_SYMBOLS)' % (o.path, sec))
                continue
            if r[0][0] != 0:
                # the bytes ahead of the first known symbol would be
                # compared with nothing (a SAU's table lacking a local
                # label the file starts with)
                errors.append('%s %s: +0x0..+0x%x precede the first symbol '
                              'with an image address (%s); add the label '
                              'that starts the section to LOCAL_SYMBOLS'
                              % (o.path, sec, r[0][0], r[0][3]))
                continue
            allruns[(o.path, sec)] = r
    if errors:
        raise SystemExit('\n'.join('asm_compare: error: ' + e for e in errors))

    files = [ImageFile(spec) for spec in args.extract_file]

    if args.extract:
        lines = ['# tools/asm_image_ref.txt - SAU2 image bytes under the '
                 'hand-written assembly', '# (written by tools/asm_compare.py '
                 '--extract from Ghidra; one run per line:',
                 '# image address, length, bytes).']
        seen = set()
        for key in sorted(allruns):
            for off, n, addr, name in allruns[key]:
                if addr < 0 or (addr, n) in seen:
                    continue
                seen.add((addr, n))
                img = image_file_for(files, addr, n)
                if img is not None:
                    lines.append(img.provenance(addr, n))
                    data = img.read(addr, n)
                else:
                    data = gsk_read(addr, n)
                lines.append('%06X %X %s' % (addr, n, data.hex()))
        with open(args.extract, 'w') as f:
            f.write('\n'.join(lines) + '\n')
        print('asm_compare: wrote %d run(s) to %s' % (len(seen), args.extract))
        return

    if files:
        # append mode: the runs the reference file lacks, from the image file
        if not args.ref:
            raise SystemExit('asm_compare: --extract-file needs --ref (append) '
                             'or --extract (rewrite)')
        ref = load_ref(args.ref) if os.path.exists(args.ref) else []
        lines = []
        seen = set()
        missing = 0
        for key in sorted(allruns):
            for off, n, addr, name in allruns[key]:
                if addr < 0 or (addr, n) in seen or \
                        ref_bytes(ref, addr, n) is not None:
                    continue
                seen.add((addr, n))
                img = image_file_for(files, addr, n)
                if img is None:
                    missing += 1
                    continue
                lines.append(img.provenance(addr, n))
                lines.append('%06X %X %s' % (addr, n, img.read(addr, n).hex()))
        if lines:
            with open(args.ref, 'a') as f:
                f.write('\n'.join(lines) + '\n')
        print('asm_compare: appended %d run(s) from the image file to %s%s'
              % (len(lines) // 2, args.ref,
                 '; %d run(s) are in no window (use --extract)' % missing
                 if missing else ''))
        return

    if args.image:
        ref = ImageRef(args.map, args.image)
    elif not args.ref:
        raise SystemExit('asm_compare: --ref, --image or --extract is '
                         'required')
    else:
        ref = load_ref(args.ref)

    # Pass 1: align every section with the image, relocation fields as
    # wildcards, recording where each of our offsets lands in the image.
    results = {}
    for o in objs:
        for sec in o.sections:
            results[(o.path, sec)] = align(o, sec, allruns[(o.path, sec)], ref)

    # Coverage: where two consecutive runs of a section are not contiguous
    # in the image, the bytes between them are compared with nothing (a run
    # that ends early - a fault stub without its inline status words - is
    # invisible to the byte walk, because the next run re-anchors at its own
    # image address).  Reported as notes, not failures: a file that gathers
    # routines from several places in the image has real gaps.  Sections
    # with a documented deviation are not measured (the alignment past the
    # deviation is meaningless).
    gaps = []
    for (path, sec), runs in sorted(allruns.items()):
        res = results[(path, sec)]
        if res.error or res.deviations:
            continue
        for k in range(len(runs) - 1):
            off, n, addr, name = runs[k]
            off2, n2, addr2, name2 = runs[k + 1]
            if addr < 0 or addr2 < 0:
                continue
            end = res.image_addr(off2 - 1)
            if end is None or end + 1 == addr2:
                continue
            gaps.append('%s %s: run %s ends at image 0x%06X, run %s starts '
                        'at 0x%06X (%+d image bytes between them are not '
                        'compared)' % (path, sec, name, end + 1, name2,
                                       addr2, addr2 - end - 1))

    # Tails: the image bytes from a section's end to the next map symbol or
    # segment start, inside the section's map segment, that no section of
    # the set covers (a pad or cell the
    # image has after the section, e.g. an alignment word, that the run
    # walk cannot see because the next section re-anchors at its own map
    # symbol).  Notes, like the gaps above.
    marks = sorted({a for a, _ in linkmap.symbols.values()} |
                   {start for start, size, name in linkmap.segments})
    covered = []
    tails = []
    for (path, sec), runs in allruns.items():
        res = results[(path, sec)]
        if res.error or res.deviations:
            continue
        for off, n, addr, name in runs:
            if addr >= 0 and n:
                end = res.image_addr(off + n - 1)
                if end is not None:
                    covered.append((addr, end + 1))
    for (path, sec), runs in sorted(allruns.items()):
        res = results[(path, sec)]
        if res.error or res.deviations or not runs or runs[-1][2] < 0:
            continue
        off, n, addr, name = runs[-1]
        last = res.image_addr(off + n - 1)
        if last is None:
            continue
        end = last + 1
        k = bisect.bisect_left(marks, end)
        if k == len(marks) or marks[k] == end:
            continue
        nxt = marks[k]
        if any(a <= end < b for a, b in covered):
            continue
        if linkmap.segment_of(last) is None or \
                linkmap.segment_of(end) != linkmap.segment_of(last):
            continue    # the segment ends with the section: a page pad
        tails.append('%s %s: the image has %d byte(s) at 0x%06X..0x%06X '
                     'after the section, before the next map symbol or '
                     'segment, that no section covers'
                     % (path, sec, nxt - end, end, nxt))

    # image address of every symbol an assembly object defines
    asm_sym = {}
    for o in objs:
        for sym, (sec, value) in o.symbols.items():
            res = results[(o.path, sec)]
            a = res.image_addr(value)
            if a is not None:
                asm_sym.setdefault((o.path, sym), a)
                if not sym.startswith('.text'):
                    asm_sym.setdefault((None, sym), a)

    def resolve(o, sym):
        # a section symbol or file-local label of this object; then the
        # map's own name (authoritative); then a module data block's
        # declared image address; a C alias; another assembly routine
        if sym.startswith('.text') and (o.path, sym) in asm_sym:
            return asm_sym[(o.path, sym)], 'asm'
        if sym in linkmap.symbols:
            return linkmap.symbols[sym][0], 'map'
        if sym in LOCAL_SYMBOLS[SAU]:
            return LOCAL_SYMBOLS[SAU][sym], 'local'
        if sym in block_addr:
            return block_addr[sym], 'block'
        if sym in IMAGE_ALIASES[SAU]:
            return IMAGE_ALIASES[SAU][sym], 'alias'
        if (o.path, sym) in asm_sym:
            return asm_sym[(o.path, sym)], 'asm'
        if (None, sym) in asm_sym:
            return asm_sym[(None, sym)], 'asm'
        if sym in segment_addr(linkmap):
            return segment_addr(linkmap)[sym], 'map segment'
        return None, None

    # Pass 2: every relocation (and every widened operand) must resolve to
    # the cell the image instruction addressed.
    failed = 0
    nsec = nrel = nverified = nwide = nbranch = 0
    unverified = []
    deviations = []
    used_devs = set()
    for o in objs:
        for sec in o.sections:
            nsec += 1
            res = results[(o.path, sec)]
            label = '%s %s' % (o.path, sec)
            if res.error:
                failed += 1
                errors.append('%s: %s' % (label, res.error))
                continue
            bad = 0
            rb = REBASES[SAU].get(sec)
            relocs = {off: (typ, sym, add)
                      for off, typ, sym, add in o.relocs.get(sec, [])}
            for chk in res.checks:
                off, size, p, want, pcrel, widened = chk
                nrel += 1 if off in relocs else 0
                nwide += 1 if widened else 0
                if off in relocs:
                    typ, sym, add = relocs[off]
                    if sym in o.sections:
                        # section symbol + addend: an offset into one of
                        # this object's sections, placed by its alignment
                        target = results[(o.path, sym)].image_addr(add)
                        how, add = 'asm', 0
                    else:
                        target, how = resolve(o, sym)
                    what = '%s %s%+#x' % (typ, sym, add)
                    if target is None:
                        unverified.append('%s+0x%x %s' % (label, off, what))
                        continue
                    val = target + add
                    if 'PC' in typ and not widened:
                        val -= p
                else:
                    # a literal operand of a widened instruction
                    val = int.from_bytes(o.data[sec][off:off + size], 'big')
                    how, target, what = 'literal', val, 'literal'
                if widened and rb and off >= 2 and \
                        int.from_bytes(o.data[sec][off - 2:off], 'big') == \
                        (0x41F9 | (rb[0] << 9)) and want == rb[1]:
                    # `lea <our base>,An' for the image's `lea <code base>'
                    ok = sym == rb[2] and add == 0
                elif widened:
                    ok = (val & 0xFFFFFFFF) == want
                else:
                    val &= (1 << (8 * size)) - 1
                    ok = val == want
                if ok:
                    nverified += 1
                    continue
                bad += 1
                errors.append('%s+0x%x (image 0x%06X): %s%s resolves to '
                              '0x%X (%s 0x%06X), image operand is 0x%X'
                              % (label, off, p, what,
                                 ' (widened from PC-relative)' if widened
                                 else '', val, how, target, want))
            if rb:
                base, _ = resolve(o, rb[2])
                for at, d, cell in res.rebased:
                    if base is not None and base + d == cell:
                        nbranch += 1
                        continue
                    bad += 1
                    errors.append('%s+0x%x: (%d,A%d) with A%d = %s names '
                                  '0x%06X, the image cell is 0x%06X'
                                  % (label, at, d, rb[0], rb[0], rb[2],
                                     (base or 0) + d, cell))
            loose = 0
            for at, ours_t, img_t in res.branches:
                got = res.image_addr(ours_t)
                if got == img_t:
                    nbranch += 1
                    continue
                if res.deviations:
                    # the target lies in code placed differently from the
                    # image (past a documented deviation)
                    loose += 1
                    continue
                bad += 1
                errors.append('%s+0x%x: PC-relative operand reaches +0x%x '
                              '(image 0x%06X), the image instruction reaches '
                              '0x%06X' % (label, at, ours_t, got or 0, img_t))
            checked = {c[0] for c in res.checks}
            skipped = [r for r in relocs if r not in checked]
            for run, at, img_at, detail, key in res.deviations:
                used_devs.add(key)
                deviations.append('%s: run %s stops at +0x%x (image 0x%06X) '
                                  '[%s]' % (label, run, at, img_at, detail))
            if res.deviations:
                deviations.append('%s: %d relocation(s) and %d PC-relative '
                                  'operand(s) past a deviation not compared; '
                                  'reason: %s'
                                  % (label, len(skipped), loose,
                                     KNOWN_DEVIATIONS[SAU][res.deviations[0][4]]))
            if skipped and not res.deviations:
                bad += 1
                errors.append('%s: relocation(s) at %s were never reached'
                              % (label, ', '.join('+0x%x' % r
                                                  for r in skipped)))
            if bad:
                failed += 1
                continue
            if args.verbose:
                print('asm_compare: %s: identical modulo %d relocation(s)%s%s'
                      % (label, len(relocs),
                         ', %d widened operand(s)' % res.widened
                         if res.widened else '',
                         ', %d immediate-form alias(es)' % res.aliases
                         if res.aliases else ''))
    for (pth, run), why in KNOWN_DEVIATIONS[SAU].items():
        if (pth, run) not in used_devs:
            errors.append('KNOWN_DEVIATIONS entry %s %s no longer diverges '
                          '(or is not linked): remove it' % (pth, run))
    for d in deviations:
        print('asm_compare: documented deviation: ' + d)
    for u in unverified:
        print('asm_compare: unverified (target has no image address): ' + u)
    for g in gaps + tails:
        print('asm_compare: note: ' + g)
    for e in errors:
        print('asm_compare: FAIL ' + e, file=sys.stderr)
    print('asm_compare: %d object(s), %d section(s): %d identical modulo '
          'relocations, %d failed; %d relocation(s) and %d widened '
          'operand(s) checked, %d resolved to the image operand, '
          '%d unverified; %d PC-relative/base displacement(s) checked; '
          '%d documented deviation(s); %d run boundary(ies) not contiguous '
          'in the image; %d section tail(s) uncovered'
          % (len(objs), nsec, nsec - failed, failed, nrel, nwide,
             nverified, len(unverified), nbranch, len(deviations),
             len(gaps), len(tails)))
    if failed or errors:
        sys.exit(1)


if __name__ == '__main__':
    main()
