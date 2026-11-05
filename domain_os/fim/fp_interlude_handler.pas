{ FIM_$FP_INTERLUDE_HANDLER - complete the floating-point accelerator's
  interrupted instruction.

  Image addresses:
    sau7  0x3C46E7F8  FIM_$FP_INTERLUDE_HANDLER
    sau7  0x3C46CAF8  fpa_error (nested)
    sau7  0x3C46CB3C  check_wtk_6_low (nested in decode_instruction)
    sau7  0x3C46CB5E  check_wtk_6_high (nested in decode_instruction)
    sau7  0x3C46CB80  check_wtk_11_low (nested in decode_instruction)
    sau7  0x3C46CBA2  load_kind_0 (nested in decode_instruction)
    sau7  0x3C46CC10  load_kind_1 (nested in decode_instruction)
    sau7  0x3C46CC74  load_kind_2 (nested in decode_instruction)
    sau7  0x3C46CCE4  load_kind_3 (nested in decode_instruction)
    sau7  0x3C46CD4C  load_kind_4 (nested in decode_instruction)
    sau7  0x3C46CDD2  decode_instruction (nested)
    sau7  0x3C46D260  classify (nested)
    sau7  0x3C46D364  is_denormal (nested)
    sau7  0x3C46D3AA  quiet_nan (nested)
    sau7  0x3C46D3EE  int_result (nested)
    sau7  0x3C46D416  get_state (nested)
    sau7  0x3C46D458  put_state (nested)
    sau7  0x3C46D4B4  post_exceptions (nested)
    sau7  0x3C46D61A  integer_overflow (nested)
    sau7  0x3C46D660  invalid_result (nested)
    sau7  0x3C46D67A  nan_operand (nested)
    sau7  0x3C46D8C2  overflow_result (nested)
    sau7  0x3C46D99A  underflow_result (nested)
    sau7  0x3C46DAA2  divide_by_zero (nested)
    sau7  0x3C46DB08  inexact_result (nested)
    sau7  0x3C46DB26  sp_bias_up (nested)
    sau7  0x3C46DB4C  dp_bias_up (nested)
    sau7  0x3C46DB72  rex_sp_monadic (nested)
    sau7  0x3C46DC12  rex_dp_monadic (nested)
    sau7  0x3C46DCBE  rex_sp_cvt (nested)
    sau7  0x3C46DD4A  rex_dp_cvt (nested)
    sau7  0x3C46DDCC  sp_tiny_result (nested in rex_sp_diadic)
    sau7  0x3C46DE14  rex_sp_diadic (nested)
    sau7  0x3C46E284  dp_tiny_result (nested in rex_dp_diadic)
    sau7  0x3C46E2D0  rex_dp_diadic (nested)
    sau7  0x3C46E752  reexecute (nested)

  - The accelerator's state (the exception register, the WTK status,
    the 16 registers) is read, the instruction decoded into its operands
    and result, and the WTK status code of the exception selects the
    completion: a default result (NaN, infinity, the largest value,
    zero), a denormalized result, or the operation re-executed on scaled
    operands.
  - The exceptions raised are accrued in the FPCSR; an enabled one is
    the status.  The result goes to the instruction's destination
    register and the state is written back with the FPCSR's bit 31 set.
  - An inconsistency stores its code (1 .. 43) in the FPCSR's bits
    18..14 and 5 (fpa_error) and skips the completion; an unknown WTK
    status code also skips writing the state back.

  Status stored:
    status_$ok: no enabled exception
    fault_$fp_bsun, fault_$fp_sig_nan, fault_$fp_op_err,
    fault_$fp_ovrflo, fault_$fp_undflo, fault_$fp_div_zero,
    fault_$fp_inexact: the exception raised is enabled
    fault_$fp_fpu_internal_error: the instruction or its operands were
    not understood
}

{ quiet_nan is a nested function with an 8-byte record result, which
  goes through a hidden address: the callers pass a frame temporary's
  address last, the callee finds it first among its arguments and its
  parameters after it, and no static link is passed (quiet_nan reaches
  no enclosing frame).

  sp_tiny_result and dp_tiny_result, nested in rex_sp_diadic and
  rex_dp_diadic, call underflow_result, their parent's sibling: the
  handler's frame is passed as its static link, read through the link
  their parent keeps in its frame. }

{ TODO(pascal) four frames larger than their locals

  The SAU7 image's frames of rex_sp_diadic and rex_dp_diadic are 12
  bytes larger than their declared locals give (the status sits 8 bytes
  below exp, 6 more below it), overflow_result's 4 bytes larger, and
  rex_dp_cvt's has 4 bytes it never addresses (where its siblings keep
  their status).  What the source declared there is not known. }

procedure fim_$fp_interlude_handler(out status: status_$t);
const
  { classify's results. }
  class_pos_zero   = 0;
  class_neg_zero   = 1;
  class_pos_denorm = 2;
  class_neg_denorm = 3;
  class_pos_normal = 4;
  class_neg_normal = 5;
  class_pos_inf    = 6;
  class_neg_inf    = 7;
  class_qnan       = 8;
  class_snan       = 9;

  { The rounding modes in the first WTK status word. }
  round_nearest = 0;
  round_zero    = 1;
  round_plus    = 2;
  round_minus   = 3;

  { The members of inst's kind_flags. }
  inst_bit_31 = 7;
  inst_bit_30 = 6;

  { The members of a WTK status byte's flags. }
  wtk_bit_7 = 7;
  wtk_bit_6 = 6;
  wtk_bit_1 = 1;

  { The values of the exponents' tests. }
  sp_bias      = 127;
  dp_bias      = 1023;
  sp_two_m24   = 16#33800000;               { 2.0 ** -24 }
  dp_two_m54   = 16#3C900000;               { 2.0 ** -54, high longword }
type
  { The decoded instruction. }
  inst_t = packed record
    case integer of
      1: (kind_flags: set of 0..7;          { bits 31..24 }
          bits_23_0: 0..16#FFFFFF);
      2: (flag_31: boolean;                 { bit 31 }
          flag_30: boolean;                 { bit 30 }
          src_single: boolean;              { bit 29: single-precision operands }
          dst_single: boolean;              { bit 28: single-precision result }
          op: -32768..32767;                { bits 27..12: the operation }
          bits_11_0: 0..4095);
  end;

  { The exceptions the completion raises. }
  exceptions_t = packed record
    case integer of
      1: (all: integer16);
      2: (bits_15_7: 0..511;
          bsun: boolean;                    { bit 6 }
          snan: boolean;                    { bit 5 }
          operr: boolean;                   { bit 4 }
          ovfl: boolean;                    { bit 3 }
          unfl: boolean;                    { bit 2 }
          dz: boolean;                      { bit 1 }
          inex: boolean);                   { bit 0 }
  end;
var
  result: fpa_$value_t;
  op_b: fpa_$value_t;
  op_a: fpa_$value_t;
  regs: fpa_$regs_t;
  wtk: fpa_$wtk_status_t;
  inst: inst_t;
  fpcsr: fpa_$csr_view_t;
  eir: fpa_$eir_t;
  op_kind: integer;                         { 0 .. 4: which load_kind }
  exceptions: exceptions_t;
  error: boolean;
  dest_is_x: boolean;                       { the result goes to reg_x }
  use_wrap_i: boolean;                      { unwrap with the I routines }

  { fpa_error - note an internal error: its code in the FPCSR, the
    status fault_$fp_fpu_internal_error. }
  procedure fpa_error(code: integer32);
  begin
    error := true;
    status.all := fault_$fp_fpu_internal_error;
    fpcsr.all := (fpcsr.all & 16#FFF83FDF) + lshft(code & 31, 14)
                 + (code & 32);
  end;

  { decode_instruction - decode the exception register into the
    operands, the result's register, the precisions and the operation. }
  procedure decode_instruction;

    { check_wtk_6_low - use the I unwrap routines when the low nibble
      of the seventh WTK status byte is 11. }
    procedure check_wtk_6_low;
    begin
      if wtk[6].low_nibble = 11 then
        use_wrap_i := true
      else
        use_wrap_i := false;
    end;

    { check_wtk_6_high - the same, from its high nibble. }
    procedure check_wtk_6_high;
    begin
      if wtk[6].high_nibble = 11 then
        use_wrap_i := true
      else
        use_wrap_i := false;
    end;

    { check_wtk_11_low - the same, from the twelfth byte's low
      nibble. }
    procedure check_wtk_11_low;
    begin
      if wtk[11].low_nibble = 11 then
        use_wrap_i := true
      else
        use_wrap_i := false;
    end;

    { load_kind_0 - two operands, reg_x and reg_y; the result reg_x. }
    procedure load_kind_0(single: boolean);
    begin
      op_kind := 0;
      op_b := regs[eir.reg_y];
      op_a := regs[eir.reg_x];
      result := op_a;
      inst.kind_flags := inst.kind_flags - [inst_bit_31];
      inst.kind_flags := inst.kind_flags - [inst_bit_30];
      inst.src_single := single;
      inst.dst_single := single;
    end;

    { load_kind_1 - one operand, reg_x; the result reg_y. }
    procedure load_kind_1(single: boolean);
    begin
      op_kind := 1;
      op_a := regs[eir.reg_x];
      result := regs[eir.reg_y];
      inst.kind_flags := inst.kind_flags + [inst_bit_31];
      inst.kind_flags := inst.kind_flags - [inst_bit_30];
      inst.src_single := single;
      inst.dst_single := single;
    end;

    { load_kind_2 - two operands, reg_y and register 15; the result
      reg_x. }
    procedure load_kind_2(single: boolean);
    begin
      op_kind := 2;
      op_a := regs[eir.reg_y];
      op_b := regs[15];
      result := regs[eir.reg_x];
      inst.kind_flags := inst.kind_flags - [inst_bit_31];
      inst.kind_flags := inst.kind_flags + [inst_bit_30];
      inst.src_single := single;
      inst.dst_single := single;
    end;

    { load_kind_3 - a conversion of reg_x into reg_x, the result in the
      other precision. }
    procedure load_kind_3(single: boolean);
    begin
      op_kind := 3;
      op_a := regs[eir.reg_x];
      result := regs[eir.reg_x];
      inst.kind_flags := inst.kind_flags + [inst_bit_31];
      inst.kind_flags := inst.kind_flags - [inst_bit_30];
      inst.src_single := single;
      inst.dst_single := not single;
    end;

    { load_kind_4 - two operands, reg_x and reg_y, compared; the result
      reg_x. }
    procedure load_kind_4(single: boolean);
    begin
      op_kind := 4;
      op_a := regs[eir.reg_x];
      op_b := regs[eir.reg_y];
      result := regs[eir.reg_x];
      if inst.op = 98 then
        inst.kind_flags := inst.kind_flags + [inst_bit_31]
      else
        inst.kind_flags := inst.kind_flags - [inst_bit_31];
      inst.kind_flags := inst.kind_flags - [inst_bit_30];
      inst.src_single := single;
    end;

  begin
    dest_is_x := true;
    if (eir.op_class = 2) and then eir.flag_17 and then (eir.fmt = 1) then begin
      dest_is_x := false;
      case eir.opcode of
        0: begin
          load_kind_1(false);
          inst.op := 0;
        end;
        1: begin
          load_kind_1(true);
          inst.op := 0;
        end;
        4: begin
          load_kind_1(false);
          inst.op := 1;
          check_wtk_6_low;
        end;
        5: begin
          load_kind_1(true);
          inst.op := 1;
          check_wtk_6_low;
        end;
        6: begin
          load_kind_1(false);
          inst.op := 2;
          check_wtk_6_low;
        end;
        7: begin
          load_kind_1(true);
          inst.op := 2;
          check_wtk_6_low;
        end;
        otherwise begin
          fpa_error(1);
        end;
      end;
    end
    else if (eir.op_class = 2) and then not eir.flag_17
            and then (eir.fmt = 1) then
      fpa_error(2)
    else if (eir.op_class = 1) and then eir.flag_17
            and then (eir.fmt = 1) then begin
      case eir.opcode of
        0: begin
          load_kind_3(false);
          inst.op := 0;
        end;
        1: begin
          load_kind_3(true);
          inst.op := 0;
        end;
        2: begin
          load_kind_3(false);
          inst.op := 1;
        end;
        3: begin
          load_kind_3(true);
          inst.op := 1;
        end;
        4: begin
          load_kind_3(false);
          inst.op := 2;
          check_wtk_6_low;
        end;
        5: begin
          load_kind_3(true);
          inst.op := 3;
        end;
        otherwise begin
          fpa_error(3);
        end;
      end;
    end
    else if (eir.op_class = 1) and then not eir.flag_17
            and then (eir.fmt = 1) then begin
      case eir.opcode of
        0: begin
          load_kind_3(true);
          inst.op := 95;
        end;
        3: begin
          load_kind_3(false);
          inst.op := 96;
        end;
        otherwise begin
          fpa_error(4);
        end;
      end;
    end
    else if (eir.op_class = 0) and then eir.flag_17
            and then (eir.fmt = 2) then begin
      case eir.opcode of
        0: begin
          load_kind_0(true);
          inst.op := 0;
          check_wtk_6_low;
        end;
        1: begin
          load_kind_0(true);
          inst.op := 1;
          check_wtk_6_high;
        end;
        2: begin
          load_kind_0(true);
          inst.op := 2;
          check_wtk_6_high;
        end;
        3: begin
          load_kind_0(true);
          inst.op := 3;
          check_wtk_11_low;
        end;
        4: begin
          load_kind_0(false);
          inst.op := 3;
          check_wtk_11_low;
        end;
        7: begin
          load_kind_0(false);
          inst.op := 0;
          check_wtk_6_low;
        end;
        9: begin
          load_kind_0(false);
          inst.op := 1;
          check_wtk_6_high;
        end;
        10: begin
          load_kind_0(false);
          inst.op := 2;
          check_wtk_6_high;
        end;
        otherwise begin
          fpa_error(5);
        end;
      end;
    end
    else if ((not eir.flag_17) and (eir.fmt = 2))
            and then ((eir.op_class = 0) or else (eir.op_class = 2)) then begin
      if eir.op_class = 2 then
        inst.op := 98
      else
        inst.op := 97;
      case eir.opcode of
        0, 1, 2, 3: begin
          load_kind_4(true);
        end;
        4, 5, 6, 7: begin
          load_kind_4(false);
        end;
        otherwise begin
          fpa_error(6);
        end;
      end;
    end
    else if (eir.op_class = 0) and then eir.flag_17
            and then (eir.fmt = 0) then begin
      case eir.opcode of
        0: begin
          load_kind_2(true);
          inst.op := 0;
          check_wtk_6_low;
        end;
        1: begin
          load_kind_2(true);
          inst.op := 1;
          check_wtk_6_high;
        end;
        2: begin
          load_kind_2(true);
          inst.op := 2;
          check_wtk_6_high;
        end;
        3: begin
          fpa_error(9);
        end;
        5: begin
          fpa_error(8);
        end;
        6: begin
          fpa_error(7);
        end;
        7: begin
          load_kind_2(false);
          inst.op := 0;
          check_wtk_6_low;
        end;
        9: begin
          load_kind_2(false);
          inst.op := 1;
          check_wtk_6_high;
        end;
        10: begin
          load_kind_2(false);
          inst.op := 2;
          check_wtk_6_high;
        end;
        11: begin
          fpa_error(10);
        end;
        otherwise begin
          fpa_error(11);
        end;
      end;
    end
    else
      fpa_error(12);
  end;

  { classify - the class of x, single or double precision. }
  function classify(in x: fpa_$value_t; single: boolean): integer;
  var
    bits: integer;
  begin
    bits := 0;
    if x.hi < 0 then
      bits := 16;
    if single then begin
      if (x.hi & 16#7F800000) = 16#7F800000 then
        bits := bits + 8;
      if (x.hi & 16#7F800000) = 0 then
        bits := bits + 4;
      if (x.hi & 16#7FFFFF) = 0 then
        bits := bits + 2;
      if (x.hi & 16#400000) = 0 then
        bits := bits + 1;
    end
    else begin
      if (x.hi & 16#7FF00000) = 16#7FF00000 then
        bits := bits + 8;
      if (x.hi & 16#7FF00000) = 0 then
        bits := bits + 4;
      if ((x.hi & 16#FFFFF) = 0) and then (x.lo = 0) then
        bits := bits + 2;
      if (x.hi & 16#80000) = 0 then
        bits := bits + 1;
    end;
    case bits of
      0, 1, 3: begin
        classify := class_pos_normal;
      end;
      16, 17, 19: begin
        classify := class_neg_normal;
      end;
      7: begin
        classify := class_pos_zero;
      end;
      23: begin
        classify := class_neg_zero;
      end;
      11: begin
        classify := class_pos_inf;
      end;
      27: begin
        classify := class_neg_inf;
      end;
      4, 5: begin
        classify := class_pos_denorm;
      end;
      20, 21: begin
        classify := class_neg_denorm;
      end;
      8, 24: begin
        classify := class_qnan;
      end;
      9, 25: begin
        classify := class_snan;
      end;
      otherwise begin
        fpa_error(13);
      end;
    end;
  end;

  { is_denormal - whether x is a denormalized number. }
  function is_denormal(in x: fpa_$value_t; single: boolean): boolean;
  begin
    if single then begin
      if ((x.hi & 16#7F800000) = 0) and then ((x.hi & 16#7FFFFF) <> 0) then
        is_denormal := true
      else
        is_denormal := false;
    end
    else begin
      if ((x.hi & 16#7FF00000) = 0)
         and then (((x.hi & 16#FFFFF) <> 0) or else (x.lo <> 0)) then
        is_denormal := true
      else
        is_denormal := false;
    end;
  end;

  { quiet_nan - x with its quiet bit set. }
  function quiet_nan(in x: fpa_$value_t; single: boolean): fpa_$value_t;
  var
    v: fpa_$value_t;
  begin
    v.lo := x.lo;
    if single then
      v.hi := x.hi ! 16#400000
    else
      v.hi := x.hi ! 16#80000;
    quiet_nan := v;
  end;

  { int_result - the integer value as the conversion's result. }
  procedure int_result(out r: fpa_$value_t; value: integer32);
  begin
    r.hi := 0;
    r.lo := 0;
    r.hi := rshft(value, 11);
    r.lo := lshft(value, 21);
  end;

  { get_state - read the exception register, the WTK status and the
    registers. }
  procedure get_state;
  begin
    eir := fim_$fp_get_eir;
    eir.flag_17 := not eir.flag_17;
    fim_$fp_get_wtk_status(wtk);
    fim_$fp_get_fpregs(regs);
  end;

  { put_state - write the WTK status, the registers and the FPCSR back,
    bit 31 of the FPCSR set. }
  procedure put_state;
  begin
    wtk[3].low_byte := 0;
    if not (wtk_bit_7 in wtk[11].flags) then
      fpa_error(14)
    else
      wtk[11].flags := wtk[11].flags - [wtk_bit_7];
    wtk[11].flags := wtk[11].flags - [wtk_bit_6];
    fim_$fp_put_wtk_status(wtk);
    fim_$fp_put_fpregs(regs);
    fpcsr.flags := fpcsr.flags + [fpa_$csr_done];
    fim_$fp_put_fpcsr(fpcsr.csr);
  end;

  { post_exceptions - accrue the exceptions raised in the FPCSR, take an
    enabled one as the status, and store the result. }
  procedure post_exceptions;
  begin
    if exceptions.bsun then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_iop];
      if fpa_$csr_en_bsun in fpcsr.flags then
        status.all := fault_$fp_bsun;
    end
    else if exceptions.snan then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_iop];
      if fpa_$csr_en_snan in fpcsr.flags then
        status.all := fault_$fp_sig_nan;
    end
    else if exceptions.operr then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_iop];
      if fpa_$csr_en_operr in fpcsr.flags then
        status.all := fault_$fp_op_err;
    end
    else if exceptions.ovfl then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_ovfl];
      if fpa_$csr_en_ovfl in fpcsr.flags then
        status.all := fault_$fp_ovrflo
      else begin
        fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_inex];
        if fpa_$csr_en_inex in fpcsr.flags then
          status.all := fault_$fp_inexact;
      end;
    end
    else if exceptions.unfl then begin
      if exceptions.inex or else (fpa_$csr_en_unfl in fpcsr.flags) then
        fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_unfl];
      if exceptions.inex then
        fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_inex];
      if fpa_$csr_en_unfl in fpcsr.flags then
        status.all := fault_$fp_undflo
      else if fpa_$csr_en_inex in fpcsr.flags then
        status.all := fault_$fp_inexact;
    end
    else if exceptions.dz then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_dz];
      if fpa_$csr_en_dz in fpcsr.flags then
        status.all := fault_$fp_div_zero;
    end
    else if exceptions.inex then begin
      fpcsr.flags := fpcsr.flags + [fpa_$csr_acc_inex];
      wtk[2].flags := wtk[2].flags - [wtk_bit_1];
      if fpa_$csr_en_inex in fpcsr.flags then
        status.all := fault_$fp_inexact;
    end;
    if dest_is_x then
      regs[eir.reg_x] := result
    else
      regs[eir.reg_y] := result;
  end;

  { integer_overflow - a conversion to integer out of range: the
    integer of the operand's sign, an operand error. }
  procedure integer_overflow;
  begin
    if op_kind <> 3 then
      fpa_error(15)
    else begin
      exceptions.operr := true;
      if op_a.hi < 0 then
        int_result(result, 16#80000000)
      else
        int_result(result, 16#7FFFFFFF);
    end;
  end;

  { invalid_result - an invalid operation: the result all ones, an
    operand error. }
  procedure invalid_result;
  begin
    exceptions.operr := true;
    result.hi := -1;
    result.lo := -1;
  end;

  { nan_operand - an operation on a NaN: the NaN as the result,
    quieted, or the comparison's exception. }
  procedure nan_operand;
  var
    bsun: boolean;
    operr: boolean;
    snan: boolean;
  begin
    bsun := false;
    operr := false;
    snan := false;
    case op_kind of
      0, 2: begin
        if classify(op_a, inst.src_single) = class_snan then begin
          snan := true;
          result := quiet_nan(op_a, inst.src_single);
        end
        else if classify(op_b, inst.src_single) = class_snan then begin
          snan := true;
          result := quiet_nan(op_b, inst.src_single);
        end
        else if classify(op_a, inst.src_single) = class_qnan then
          result := op_a
        else if classify(op_b, inst.src_single) = class_qnan then
          result := op_b
        else begin
          fpa_error(16);
          return;
        end;
      end;
      1: begin
        if classify(op_a, inst.src_single) = class_snan then begin
          snan := true;
          result := quiet_nan(op_a, inst.src_single);
        end
        else if classify(op_a, inst.src_single) = class_qnan then
          result := op_a
        else begin
          fpa_error(17);
          return;
        end;
      end;
      3: begin
        if classify(op_a, inst.src_single) = class_snan then
          snan := true;
        result.hi := -1;
        result.lo := -1;
        if (inst.op = 0) or else (inst.op = 1) then
          operr := true;
      end;
      4: begin
        if classify(op_a, inst.src_single) = class_snan then
          snan := true
        else if (classify(op_b, inst.src_single) = class_snan)
                and then (inst.op <> 98) then
          snan := true
        else
          bsun := true;
      end;
      otherwise begin
        fpa_error(19);
        return;
      end;
    end;
    if bsun then
      exceptions.bsun := true
    else if operr then
      exceptions.operr := true
    else if snan then
      exceptions.snan := true;
  end;

  { overflow_result - an overflow: infinity or the largest value of the
    result's sign, by the rounding mode. }
  procedure overflow_result;
  var
    negative: boolean;
  begin
    exceptions.ovfl := true;
    negative := result.hi < 0;
    if negative then begin
      case wtk[0].round of
        round_nearest, round_minus: begin
          if inst.dst_single then
            result.hi := 16#FF800000
          else begin
            result.hi := 16#FFF00000;
            result.lo := 0;
          end;
        end;
        round_zero, round_plus: begin
          if inst.dst_single then
            result.hi := 16#FF7FFFFF
          else
            result.hi := 16#FFEFFFFF;
          result.lo := -1;
        end;
      end;
    end
    else begin
      case wtk[0].round of
        round_nearest, round_plus: begin
          if inst.dst_single then
            result.hi := 16#7F800000
          else begin
            result.hi := 16#7FF00000;
            result.lo := 0;
          end;
        end;
        round_zero, round_minus: begin
          if inst.dst_single then
            result.hi := 16#7F7FFFFF
          else
            result.hi := 16#7FEFFFFF;
          result.lo := -1;
        end;
      end;
    end;
  end;

  { underflow_result - an underflow: the result denormalized by the
    unwrap routines. }
  procedure underflow_result;
  var
    exp: integer;
    st: fpa_$op_status_t;
  begin
    if (op_kind = 3) and then (inst.op = 2) then begin
      exp := arshft(lshft(result.hi, 1), 21) - sp_bias;
      if exp < -150 then
        result.hi := (result.hi & 16#80000000) ! 40000000
      else
        result.hi := (result.hi & 16#80000000)
                     ! lshft((exp + sp_bias) & 255, 23)
                     ! lshft(result.hi & 16#FFFFF, 3)
                     ! rshft(result.lo & 16#E0000000, 29);
    end;
    if use_wrap_i then begin
      if inst.dst_single then
        fim_$fp_sunwrapi(result, st)
      else
        fim_$fp_dunwrapi(result, st);
    end
    else begin
      if inst.dst_single then
        fim_$fp_sunwrap(result, st)
      else
        fim_$fp_dunwrap(result, st);
    end;
    exceptions.unfl := true;
    if fpa_$st_inexact in st.flags then
      exceptions.inex := true;
  end;

  { divide_by_zero - a division by zero: infinity of the operands'
    signs. }
  procedure divide_by_zero;
  begin
    if op_kind <> 0 then
      fpa_error(20)
    else begin
      exceptions.dz := true;
      result.lo := 0;
      if inst.dst_single then
        result.hi := 16#7F800000
      else
        result.hi := 16#7FF00000;
      if (op_a.hi & 16#80000000) <> (op_b.hi & 16#80000000) then
        result.top_byte := result.top_byte + 128;
    end;
  end;

  { inexact_result - an inexact result. }
  procedure inexact_result;
  begin
    exceptions.inex := true;
    if not (fpa_$csr_en_inex in fpcsr.flags) then
      wtk[2].flags := wtk[2].flags - [wtk_bit_1];
  end;

  { sp_bias_up - the single-precision x's exponent plus 24. }
  procedure sp_bias_up(in out x: fpa_$value_t);
  begin
    x.hi := (x.hi & 16#80000000) ! ((x.hi + 16#0C000000) & 16#7FFFFFFF);
  end;

  { dp_bias_up - the double-precision x's exponent plus 54. }
  procedure dp_bias_up(in out x: fpa_$value_t);
  begin
    x.hi := (x.hi & 16#80000000) ! ((x.hi + 16#03600000) & 16#7FFFFFFF);
  end;

  { rex_sp_monadic - re-execute a single-precision monadic operation. }
  procedure rex_sp_monadic;
  var
    st: fpa_$op_status_t;
  begin
    case inst.op of
      0: begin
        fim_$fp_spwrap(op_a);
        sp_bias_up(op_a);
        fim_$fp_rex_sp_monadic(op_a, result, 0, st);
        result.top_byte := result.top_byte - 6;
        if fpa_$st_inexact in st.flags then
          exceptions.inex := true
        else if st.flags <> [] then
          fpa_error(21);
      end;
      1: begin
        result.hi := op_a.hi;
      end;
      2: begin
        result.hi := op_a.hi & 16#7FFFFFFF;
      end;
      otherwise begin
        fpa_error(22);
      end;
    end;
  end;

  { rex_dp_monadic - re-execute a double-precision monadic operation. }
  procedure rex_dp_monadic;
  var
    st: fpa_$op_status_t;
  begin
    case inst.op of
      0: begin
        fim_$fp_dpwrap(op_a);
        dp_bias_up(op_a);
        fim_$fp_rex_dp_monadic(op_a, result, 0, st);
        result.top_word := result.top_word - 432;
        if fpa_$st_inexact in st.flags then
          exceptions.inex := true
        else if st.flags <> [] then
          fpa_error(23);
      end;
      1: begin
        result := op_a;
      end;
      2: begin
        result.lo := op_a.lo;
        result.hi := op_a.hi & 16#7FFFFFFF;
      end;
      otherwise begin
        fpa_error(24);
      end;
    end;
  end;

  { rex_sp_cvt - re-execute a conversion of a single-precision
    operand. }
  procedure rex_sp_cvt;
  var
    st: fpa_$op_status_t;
  begin
    case inst.op of
      1, 0: begin
        result.hi := 0;
        result.lo := 0;
        exceptions.inex := true;
      end;
      3: begin
        fim_$fp_spwrap(op_a);
        sp_bias_up(op_a);
        fim_$fp_rex_sp_cvt(op_a, result, 3, st);
        if st.flags <> [] then
          fpa_error(25)
        else
          result.top_word := result.top_word - 384;
      end;
      otherwise begin
        fpa_error(26);
      end;
    end;
  end;

  { rex_dp_cvt - re-execute a conversion of a double-precision operand:
    a single-precision result too small for its format. }
  procedure rex_dp_cvt;
  begin
    case inst.op of
      1, 0: begin
        result.hi := 0;
        result.lo := 0;
        exceptions.inex := true;
      end;
      2: begin
        case wtk[0].round of
          round_nearest, round_zero: begin
            result.hi := 0;
          end;
          round_plus: begin
            if op_a.hi > 0 then
              result.hi := 0
            else
              result.hi := 16#80000001;
          end;
          round_minus: begin
            if op_a.hi < 0 then
              result.hi := 0
            else
              result.hi := 1;
          end;
        end;
      end;
      otherwise begin
        fpa_error(27);
      end;
    end;
  end;

  { rex_sp_diadic - re-execute a single-precision diadic operation on
    scaled operands. }
  procedure rex_sp_diadic;
  var
    a_denorm: boolean;
    b_denorm: boolean;
    tmp: fpa_$value_t;
    exp: integer32;
    st: fpa_$op_status_t;

    { sp_tiny_result - a result below the format's range: 2.0 of the
      operands' sign, denormalized. }
    procedure sp_tiny_result;
    begin
      if (op_a.hi & 16#80000000) <> (op_b.hi & 16#80000000) then
        result.hi := 16#C0000000
      else
        result.hi := 16#40000000;
      use_wrap_i := true;
      underflow_result;
    end;

  begin
    a_denorm := is_denormal(op_a, true);
    b_denorm := is_denormal(op_b, true);
    case inst.op of
      1, 2: begin
        if inst.op = 2 then begin
          if op_b.hi < 0 then
            op_b.hi_bits := op_b.hi_bits - [31]
          else
            op_b.hi_bits := op_b.hi_bits + [31];
        end;
        if a_denorm and b_denorm then begin
          fim_$fp_spwrap(op_a);
          fim_$fp_spwrap(op_b);
          sp_bias_up(op_a);
          sp_bias_up(op_b);
          fim_$fp_rex_sp_diadic(op_a, op_b, result, 1, st);
          if fpa_$st_inexact in st.flags then begin
            exceptions.inex := true;
            use_wrap_i := true;
          end;
          tmp.hi := sp_two_m24;
          fim_$fp_rex_sp_diadic(result, tmp, result, 0, st);
          if fpa_$st_underflow in st.flags then begin
            if fpa_$st_inexact in st.flags then
              use_wrap_i := true;
            underflow_result;
          end;
        end
        else begin
          if a_denorm then begin
            tmp := op_a;
            op_a := op_b;
            op_b := tmp;
          end;
          exp := rshft(lshft(op_a.hi, 1), 24) - sp_bias;
          if exp > 103 then begin
            op_b.hi := (op_b.hi & 16#80000000) ! 16#800000;
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 1, st);
            exceptions.inex := true;
            if st.flags - [fpa_$st_inexact] <> [] then
              fpa_error(28);
          end
          else begin
            if (op_a.hi & 16#7FFFFFFF) <> 0 then
              op_a.top_byte := op_a.top_byte + 12;
            fim_$fp_spwrap(op_b);
            sp_bias_up(op_b);
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 1, st);
            if fpa_$st_inexact in st.flags then begin
              exceptions.inex := true;
              use_wrap_i := true;
            end;
            tmp.hi := sp_two_m24;
            fim_$fp_rex_sp_diadic(result, tmp, result, 0, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end;
          end;
        end;
      end;
      0: begin
        if a_denorm and b_denorm then
          sp_tiny_result
        else begin
          if a_denorm then begin
            tmp := op_a;
            op_a := op_b;
            op_b := tmp;
          end;
          exp := rshft(lshft(op_a.hi, 1), 24) - sp_bias;
          if exp < -102 then
            sp_tiny_result
          else begin
            fim_$fp_spwrap(op_b);
            sp_bias_up(op_b);
            op_a.hi := lshft(exp + 103, 23) ! (op_a.hi & 16#807FFFFF);
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 0, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(29);
          end;
        end;
      end;
      3: begin
        if a_denorm and b_denorm then begin
          fim_$fp_spwrap(op_a);
          fim_$fp_spwrap(op_b);
          sp_bias_up(op_a);
          sp_bias_up(op_b);
          fim_$fp_rex_sp_diadic(op_a, op_b, result, 3, st);
          if fpa_$st_inexact in st.flags then
            exceptions.inex := true;
        end
        else if a_denorm then begin
          exp := rshft(lshft(op_b.hi, 1), 24) - sp_bias;
          if exp > 103 then
            sp_tiny_result
          else begin
            fim_$fp_spwrap(op_a);
            sp_bias_up(op_a);
            op_b.hi := lshft(exp + 151, 23) ! (op_b.hi & 16#807FFFFF);
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 3, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(30);
          end;
        end
        else begin
          exp := rshft(lshft(op_a.hi, 1), 24) - sp_bias;
          if exp > 103 then begin
            op_b.hi := (op_b.hi & 16#80000000) ! 16#7F000000;
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 0, st);
            overflow_result;
          end
          else begin
            fim_$fp_spwrap(op_b);
            sp_bias_up(op_b);
            op_a.hi := lshft(exp + 151, 23) ! (op_a.hi & 16#807FFFFF);
            fim_$fp_rex_sp_diadic(op_a, op_b, result, 3, st);
            if fpa_$st_overflow in st.flags then
              overflow_result
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(31);
          end;
        end;
      end;
      otherwise begin
        fpa_error(32);
      end;
    end;
  end;

  { rex_dp_diadic - re-execute a double-precision diadic operation on
    scaled operands. }
  procedure rex_dp_diadic;
  var
    a_denorm: boolean;
    b_denorm: boolean;
    tmp: fpa_$value_t;
    exp: integer32;
    st: fpa_$op_status_t;

    { dp_tiny_result - a result below the format's range: 2.0 of the
      operands' sign, denormalized. }
    procedure dp_tiny_result;
    begin
      result.lo := 0;
      if (op_a.hi & 16#80000000) <> (op_b.hi & 16#80000000) then
        result.hi := 16#C0000000
      else
        result.hi := 16#40000000;
      use_wrap_i := true;
      underflow_result;
    end;

  begin
    a_denorm := is_denormal(op_a, false);
    b_denorm := is_denormal(op_b, false);
    case inst.op of
      1, 2: begin
        if inst.op = 2 then begin
          if op_b.hi < 0 then
            op_b.hi_bits := op_b.hi_bits - [31]
          else
            op_b.hi_bits := op_b.hi_bits + [31];
        end;
        if a_denorm and b_denorm then begin
          fim_$fp_dpwrap(op_a);
          fim_$fp_dpwrap(op_b);
          dp_bias_up(op_a);
          dp_bias_up(op_b);
          fim_$fp_rex_dp_diadic(op_a, op_b, result, 1, st);
          if fpa_$st_inexact in st.flags then begin
            exceptions.inex := true;
            use_wrap_i := true;
          end;
          tmp.hi := dp_two_m54;
          tmp.lo := 0;
          fim_$fp_rex_dp_diadic(result, tmp, result, 0, st);
          if fpa_$st_underflow in st.flags then begin
            if fpa_$st_inexact in st.flags then
              use_wrap_i := true;
            underflow_result;
          end;
        end
        else begin
          if a_denorm then begin
            tmp := op_a;
            op_a := op_b;
            op_b := tmp;
          end;
          exp := rshft(lshft(op_a.hi, 1), 21) - dp_bias;
          if exp > 969 then begin
            op_b.hi := (op_b.hi & 16#80000000) ! 16#100000;
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 1, st);
            exceptions.inex := true;
            if st.flags - [fpa_$st_inexact] <> [] then
              fpa_error(33);
          end
          else begin
            if (op_a.hi * 16#7FFFFFFF <> 0) or else (op_a.lo <> 0) then
              op_a.top_word := op_a.top_word + 864;
            fim_$fp_dpwrap(op_b);
            dp_bias_up(op_b);
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 1, st);
            if fpa_$st_inexact in st.flags then begin
              exceptions.inex := true;
              use_wrap_i := true;
            end;
            tmp.hi := dp_two_m54;
            tmp.lo := 0;
            fim_$fp_rex_dp_diadic(result, tmp, result, 0, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end;
          end;
        end;
      end;
      0: begin
        if a_denorm and b_denorm then
          dp_tiny_result
        else begin
          if a_denorm then begin
            tmp := op_a;
            op_a := op_b;
            op_b := tmp;
          end;
          exp := rshft(lshft(op_a.hi, 1), 21) - dp_bias;
          if exp < -968 then
            dp_tiny_result
          else begin
            fim_$fp_dpwrap(op_b);
            dp_bias_up(op_b);
            op_a.hi := lshft(exp + 969, 20) ! (op_a.hi & 16#800FFFFF);
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 0, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(34);
          end;
        end;
      end;
      3: begin
        if a_denorm and b_denorm then begin
          fim_$fp_dpwrap(op_a);
          fim_$fp_dpwrap(op_b);
          dp_bias_up(op_a);
          dp_bias_up(op_b);
          fim_$fp_rex_dp_diadic(op_a, op_b, result, 3, st);
          if fpa_$st_inexact in st.flags then
            exceptions.inex := true;
        end
        else if a_denorm then begin
          exp := rshft(lshft(op_b.hi, 1), 21) - dp_bias;
          if exp > 969 then
            dp_tiny_result
          else begin
            fim_$fp_dpwrap(op_a);
            dp_bias_up(op_a);
            op_b.hi := lshft(exp + 1077, 20) ! (op_b.hi & 16#800FFFFF);
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 3, st);
            if fpa_$st_underflow in st.flags then begin
              if fpa_$st_inexact in st.flags then
                use_wrap_i := true;
              underflow_result;
            end
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(35);
          end;
        end
        else begin
          exp := rshft(lshft(op_a.hi, 1), 21) - dp_bias;
          if exp > 969 then begin
            op_b.hi := (op_b.hi & 16#80000000) ! 16#7FE00000;
            op_b.lo := 0;
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 0, st);
            overflow_result;
          end
          else begin
            fim_$fp_dpwrap(op_b);
            dp_bias_up(op_b);
            op_a.hi := lshft(exp + 1077, 20) ! (op_a.hi & 16#800FFFFF);
            fim_$fp_rex_dp_diadic(op_a, op_b, result, 3, st);
            if fpa_$st_overflow in st.flags then
              overflow_result
            else if fpa_$st_inexact in st.flags then
              exceptions.inex := true
            else if st.flags <> [] then
              fpa_error(36);
          end;
        end;
      end;
      otherwise begin
        fpa_error(37);
      end;
    end;
  end;

  { reexecute - re-execute the operation on a denormalized operand. }
  procedure reexecute;
  begin
    exceptions.all := 0;
    use_wrap_i := false;
    if inst.src_single then begin
      case op_kind of
        0, 2: begin
          rex_sp_diadic;
        end;
        1: begin
          rex_sp_monadic;
        end;
        3: begin
          rex_sp_cvt;
        end;
        4: begin
          fpa_error(38);
        end;
        otherwise begin
          fpa_error(39);
        end;
      end;
    end
    else begin
      case op_kind of
        0, 2: begin
          rex_dp_diadic;
        end;
        1: begin
          rex_dp_monadic;
        end;
        3: begin
          rex_dp_cvt;
        end;
        4: begin
          fpa_error(40);
        end;
        otherwise begin
          fpa_error(41);
        end;
      end;
    end;
  end;

begin
  error := false;
  fpcsr.csr := fim_$fp_get_fpcsr;
  fpcsr.flags := fpcsr.flags - [fpa_$csr_bit_4];
  fpcsr.flags := fpcsr.flags - [fpa_$csr_done];
  fim_$fp_put_fpcsr(fpcsr.csr);
  get_state;
  decode_instruction;
  if not error then begin
    status.all := status_$ok;
    exceptions.all := 0;
    case wtk[3].all & 255 of
      18, 16: begin
        reexecute;
      end;
      6, 4: begin
        underflow_result;
      end;
      2: begin
        inexact_result;
      end;
      194, 146, 144, 192, 130, 128: begin
        nan_operand;
      end;
      66, 64, 82, 80: begin
        invalid_result;
      end;
      34, 50, 32, 48: begin
        divide_by_zero;
      end;
      10, 8: begin
        overflow_result;
      end;
      1, 3: begin
        integer_overflow;
      end;
      otherwise begin
        fpa_error(43);
        return;
      end;
    end;
    if not error then
      post_exceptions;
  end;
  put_state;
end;
