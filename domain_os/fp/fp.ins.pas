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

{ FP_$GET_FP and FP_$PUT_FP (hand assembly in the FIM_ASM run: no
  frame, the word read off the stack): the address space by value
  (`val_param'). }
procedure fp_$get_fp(asid: integer); options(extern, val_param);
procedure fp_$put_fp(asid: integer); options(extern, val_param);
