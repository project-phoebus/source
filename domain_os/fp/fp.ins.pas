{ fp/fp.ins.pas - FP_ (the 68881/68882 context switch), for the Domain
  Pascal tree.

  The FP_ code and data are hand-written (fp/m68k/, the FIM_ASM and
  FIM_WIRED runs).  Include base/base.ins.pas before it.
}

var
  { FP_$SAVEP (map symbol, in the hand-written FIM_WIRED data segment):
    the base of the per-address-space FP save areas, a pointer.  Another
    unit's variable, extern. }
  fp_$savep: extern univ_ptr;
%if fpa_board %then

  { FPA_$SAVEP (map symbol, in the hand-written FIM_WIRED data segment,
    after FP_$OWNER): the floating-point accelerator's save-area base,
    a pointer (OS_$SHUTDOWN clears it). }
  fpa_$savep: extern univ_ptr;
%endif

%if fpa_board %then
const
  { The floating-point accelerator's control and status register, the
    FPCSR (FIM_$FP_GET_FPCSR's). }
  fpa_$csr_va = 16#FFF90000;

  { The version the kernel supports, the FPCSR's bits 27..26. }
  fpa_$version_supported = 3;

  { The FPCSR's bits as FIM_$FP_INTERLUDE_HANDLER uses them (members of
    `flags'): the exception enables 25..19 and the accrued exceptions
    18..14, in the order of the MC68881's; bit 31 is set when the
    handler gives the context back, bit 4 cleared when it starts. }
  fpa_$csr_done      = 31;
  fpa_$csr_en_bsun   = 25;
  fpa_$csr_en_snan   = 24;
  fpa_$csr_en_operr  = 23;
  fpa_$csr_en_ovfl   = 22;
  fpa_$csr_en_unfl   = 21;
  fpa_$csr_en_dz     = 20;
  fpa_$csr_en_inex   = 19;
  fpa_$csr_acc_iop   = 18;
  fpa_$csr_acc_ovfl  = 17;
  fpa_$csr_acc_unfl  = 16;
  fpa_$csr_acc_dz    = 15;
  fpa_$csr_acc_inex  = 14;
  fpa_$csr_bit_4     = 4;

  { The bits of an operation's status (fpa_$op_status_t's flags). }
  fpa_$st_inexact    = 1;
  fpa_$st_underflow  = 2;
  fpa_$st_overflow   = 3;

type
  { The FPCSR as PEB_$LOAD_WCS reads it: its version field. }
  fpa_$csr_t = packed record
    bits_31_28: 0..15;                    { bits 31..28 }
    version: 0..3;                        { bits 27..26 }
    bits_25_0: 0..16#3FFFFFF;             { bits 25..0 }
  end;

  { The FPCSR as FIM_$FP_INTERLUDE_HANDLER keeps it: the register, a
    longword, and the set of its bits. }
  fpa_$csr_view_t = record
    case integer of
      1: (csr: fpa_$csr_t);
      2: (all: integer32);
      3: (flags: set of 0..31);
  end;

  { A floating-point value in the accelerator's register format, 8
    bytes: a single-precision value in hi, a double-precision one in hi
    and lo (IEEE 754, the sign in bit 31 of hi). }
  fpa_$value_t = record
    case integer of
      1: (hi: integer32;                  { 0x00 }
          lo: integer32);                 { 0x04 }
      2: (hi_bits: set of 0..31);         { 0x00 }
      3: (top_word: integer16);           { 0x00 }
      4: (top_byte: [byte] 0..255);       { 0x00 }
  end;

  { The accelerator's 16 registers, register 0 first (128 bytes). }
  fpa_$regs_t = array[0..15] of fpa_$value_t;

  { A word of the WTK status as FIM_$FP_GET_WTK_STATUS returns it: the
    status byte in the low byte. }
  fpa_$wtk_word_t = packed record
    case integer of
      1: (all: integer16);
      2: (hi_byte: 0..255;
          flags: set of 0..7);
      3: (hi_byte_2: 0..255;
          high_nibble: 0..15;             { bits 7..4 }
          low_nibble: 0..15);             { bits 3..0 }
      4: (hi_byte_3: 0..255;
          bits_7_3: 0..31;
          round: 0..3;                    { bits 2..1 }
          bit_0: 0..1);
      5: (hi_byte_4: 0..255;
          low_byte: 0..255);
  end;

  { The twelve WTK status words (24 bytes). }
  fpa_$wtk_status_t = array[0..11] of fpa_$wtk_word_t;

  { The status of an accelerator operation: the WTK status byte in the
    low byte, the high byte undefined. }
  fpa_$op_status_t = packed record
    hi_byte: 0..255;
    flags: set of 0..7;
  end;

  { The exception register (EIR): the instruction the accelerator
    stopped on. }
  fpa_$eir_t = packed record
    case integer of
      1: (all: integer32);
      2: (bits_31_18: 0..16#3FFF;         { bits 31..18 }
          flag_17: boolean;               { bit 17 }
          fmt: 0..3;                      { bits 16..15 }
          bit_14: boolean;                { bit 14 }
          reg_x: 0..15;                   { bits 13..10 }
          reg_y: 0..15;                   { bits 9..6 }
          opcode: 0..15;                  { bits 5..2 }
          op_class: 0..3);                { bits 1..0 }
  end;

{ The accelerator's register and wrap routines (hand assembly,
  fim/sau7/fpa_regs.s): arguments by reference, results in D0. }
function fim_$fp_get_fpcsr: fpa_$csr_t; extern;
procedure fim_$fp_get_fpregs(out regs: fpa_$regs_t); extern;
procedure fim_$fp_put_fpregs(in regs: fpa_$regs_t); extern;
procedure fim_$fp_get_wtk_status(out status: fpa_$wtk_status_t); extern;
procedure fim_$fp_put_wtk_status(in status: fpa_$wtk_status_t); extern;
procedure fim_$fp_put_fpcsr(in csr: fpa_$csr_t); extern;
function fim_$fp_get_eir: fpa_$eir_t; extern;
procedure fim_$fp_sunwrap(in out x: fpa_$value_t;
                          out status: fpa_$op_status_t); extern;
procedure fim_$fp_dunwrap(in out x: fpa_$value_t;
                          out status: fpa_$op_status_t); extern;
procedure fim_$fp_sunwrapi(in out x: fpa_$value_t;
                           out status: fpa_$op_status_t); extern;
procedure fim_$fp_dunwrapi(in out x: fpa_$value_t;
                           out status: fpa_$op_status_t); extern;
procedure fim_$fp_spwrap(in out x: fpa_$value_t); extern;
procedure fim_$fp_dpwrap(in out x: fpa_$value_t); extern;
procedure fim_$fp_rex_sp_diadic(in a: fpa_$value_t; in b: fpa_$value_t;
                                out result: fpa_$value_t; in op: integer;
                                out status: fpa_$op_status_t); extern;
procedure fim_$fp_rex_dp_diadic(in a: fpa_$value_t; in b: fpa_$value_t;
                                out result: fpa_$value_t; in op: integer;
                                out status: fpa_$op_status_t); extern;
procedure fim_$fp_rex_sp_monadic(in a: fpa_$value_t;
                                 out result: fpa_$value_t; in op: integer;
                                 out status: fpa_$op_status_t); extern;
procedure fim_$fp_rex_dp_monadic(in a: fpa_$value_t;
                                 out result: fpa_$value_t; in op: integer;
                                 out status: fpa_$op_status_t); extern;
procedure fim_$fp_rex_sp_cvt(in a: fpa_$value_t;
                             out result: fpa_$value_t; in op: integer;
                             out status: fpa_$op_status_t); extern;
procedure fim_$fp_rex_dp_cvt(in a: fpa_$value_t;
                             out result: fpa_$value_t; in op: integer;
                             out status: fpa_$op_status_t); extern;
%endif

{ FP_$GET_FP and FP_$PUT_FP (hand assembly in the FIM_ASM run: no
  frame, the word read off the stack): the address space by value
  (`val_param'). }
procedure fp_$get_fp(asid: integer); options(extern, val_param);
procedure fp_$put_fp(asid: integer); options(extern, val_param);
