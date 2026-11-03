{ fim/fim.ins.pas - FIM (fault interrupt manager) constants and variables,
  for the Domain Pascal tree.

  Only what the Pascal files use.  Include base/base.ins.pas and
  ec/ec.ins.pas before it.
}

const
  { Fault status codes, with the names and values of Apollo's customer
    fault.ins.pas of SR10.2 (sr10.2-install/install/ri.apollo.os.v.10.2/
    sys/ins/fault.ins.pas, "FAULT.INS.PAS, /sys/ins, gms, 11/30/88", lines
    52, 67, 76; texts from stcode.db.10.2: "process quit", "process
    interrupt", "process suspend from keyboard").  TTY_$I_INIT puts them
    in the quit, interrupt and suspend signal entries (tty/i_init.pas). }
  fault_$quit             = 16#00120010;
  fault_$interrupt        = 16#0012001F;
  fault_$suspend_proc_kbd = 16#00120028;

  { The parity faults, with the names and values of the same
    fault.ins.pas (lines 66 and 69; stcode.db.10.2's texts, "memory
    parity error" and "spurious parity error", subsystem 0x12, FAULT).
    PARITY_$CHK passes them to CRASH_SYSTEM as constants, cells after
    its code (parity/chk.pas). }
  fault_$parity           = 16#0012001E;
  fault_$spurious_parity  = 16#00120021;

var
  { The per-address-space quit eventcounts and the last value seen of
    each, map symbols FIM_$QUIT_EC and FIM_$QUIT_VALUE in the FIM_WIRED
    data run.  The map's next symbols give their sizes: 58 eventcounts of
    12 bytes, then 58 longwords (to FIM_$TRACE_STS), [0..57].  Compiled
    code indexes them by PROC1_$AS_ID with the symbol as the base and no
    displacement: element 0 at the symbol, lower bound 0.  The map names
    them apart, so they are separate variables here. }
  fim_$quit_ec: extern array[0..57] of ec_$eventcount_t;
  fim_$quit_value: extern array[0..57] of integer32;

const
  { The delivery frame's size and magic word, and the frame version, as
      FIM_$BUILD_DF stores them. }
  fim_df_size = 106;
  fim_df_magic = 16#DFDF;
  fim_df_version = 2;

  { status_$fault_supervisor_fault_while_resource_locks_set, 16#00120020
    ("supervisor fault while resource locks set", stcode.db.10.2):
    FIM_$BUILD_DF's cell. }
  status_$fault_supervisor_fault_while_resource_locks_set = 16#00120020;

  { status_$fault_invalid_stack_format, 16#0012001D ("invalid stack
    format", stcode.db.10.2): the crash of the SAU5 FIM_$BUILD_DF for a
    PBU fault whose frame format has no size. }
  status_$fault_invalid_stack_format = 16#0012001D;

  { The status PROC2_$DELIVER_FIM leaves for a BLAST with its signal flag
    (bit 23) set: fault_$blast (16#00120019) with bit 23, which
    FIM_$BUILD_DF compares with. }
  fim_blast_signal_status = 16#00920019;

  { status_$peb_interrupt, 16#00240002 (stcode.db.10.2 "PEB interrupt"):
    FIM_$BUILD_DF compares the delivery frame's status with it. }
  status_$peb_interrupt = 16#00240002;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  fim_$byte_t = [byte] 0..255;

  { A status register, a fault class word, a special status word and the
    builder's flags: word sets, member k bit k.  FIM_$BUILD_DF tests
    members of loaded words and of memory words through their byte,
    member 15 as the sign, sets members, and intersects the status
    register with [8..10] (the interrupt mask).  The members: the SR's
    supervisor bit 13; the class's 12, 13, 15, 2, 3; the SSW's 8, 14,
    15. }
  fim_$word_set_t = set of 0..15;

  { The 16-bit format/vector word of an exception frame, a packed record:
    the format in the top four bits, read as a field; the word cleared
    whole, the second arm. }
  fim_$fv_t = packed record
    case integer of
      1: (format: 0..15;                  { bits 0..3 }
          vector: 0..4095);               { bits 4..15 }
      2: (fv_word: integer);
  end;

  { An exception frame: sr, pc, the format word, then the format's own
      words.  FIM_$BUILD_DF reads format 8's at 0x8, 0xA, 0x18 and
      formats A and B's at 0xA, 0xC, 0xE, 0x10, 0x24. }
  fim_$exc_frame_t = record
    sr: fim_$word_set_t;                  { 0x00 }
    pc: integer32;                        { 0x02 }
    format_vector: fim_$fv_t;             { 0x06 }
    case integer of
      8:  (f8_ssw: fim_$word_set_t;       { 0x08 }
           f8_fault_addr: linteger;       { 0x0A }
           f8_unused_0e: array[16#0E..16#17] of char;
           f8_instr_in: integer);         { 0x18 }
      10: (ab_unused_08: integer;         { 0x08 }
           ab_ssw: fim_$word_set_t;       { 0x0A }
           ab_stage_c: integer;           { 0x0C }
           ab_stage_b: integer;           { 0x0E }
           ab_data_fault_addr: linteger;  { 0x10 }
           ab_unused_14: array[16#14..16#23] of char;
           ab_stage_b_addr: linteger);    { 0x24 }
  end;
  fim_$exc_frame_ptr_t = ^fim_$exc_frame_t;

  { The SR and the PC of a frame, 6 bytes. }
  fim_$sr_pc_t = record
    sr: fim_$word_set_t;                  { 0x00 }
    pc: integer32;                        { 0x02 }
  end;

  { The access fault's information, 8 bytes: FIM_$BUILD_DF fills it in
    its frame and copies it whole into the delivery frame.  addr is
    compared unsigned: linteger. }
  fim_$fault_info_t = record
    ssw: fim_$word_set_t;                 { 0x00 }
    addr: linteger;                       { 0x02 }
    word: integer;                        { 0x06 }
  end;

  { The register save area FIM_$COM passes, D0..D7 then A0..A7, from 1:
    A6 is element 15, A7 element 16. }
  fim_$regs_t = array[1..16] of integer32;
  fim_$regs_ptr_t = ^fim_$regs_t;

  { The delivery frame's flags byte (0x4E) and version byte (0x4F), one
    2-byte packed record.  The flags are eight booleans, from bit 7 of
    0x4E down, stored as boolean fields; the version the byte after
    them.  Why one record (the layout rules; the model is
    disk/disk.ins.pas disk_$owner_op_t): a record takes at least 2 bytes
    (ref 3.10.7, p. 3-35), so the flags as a 1-byte packed record of
    their own took 0x4E..0x4F and pushed version to 0x50 and every later
    field 2 bytes on (the frame 0x6C bytes).  In a packed record the
    booleans take one bit each and the byte-sized subrange is bit
    aligned (ref 3.10.7), so the flags fill bits 15..8 of the word and
    version bits 7..0.  Probed with dpc (an `addr' of every field of
    fim_$df_t through a pointer): every field at the offset in its
    comment, the record 0x6A bytes. }
  fim_$df_flags_version_t = packed record
    class_15: boolean;                    { 0x4E bit 7 }
    supervisor: boolean;                  { 0x4E bit 6 }
    class_13: boolean;                    { 0x4E bit 5 }
    fault_info: boolean;                  { 0x4E bit 4 }
    status_23: boolean;                   { 0x4E bit 3 }
    always: boolean;                      { 0x4E bit 2 }
    fp_saved: boolean;                    { 0x4E bit 1 }
    deliver_flag: boolean;                { 0x4E bit 0 }
    version: fim_$byte_t;                 { 0x4F }
  end;

  { The delivery frame FIM_$BUILD_DF builds below the user stack, 0x6A
    bytes. }
  fim_$df_t = record
    magic: pinteger;                      { 0x00 }
    status: status_$t;                    { 0x02 }
    regs: fim_$regs_t;                    { 0x06 }
    fault_info: fim_$fault_info_t;        { 0x46 }
    flags_version: fim_$df_flags_version_t;  { 0x4E..0x4F }
    reserved_50: integer32;               { 0x50 }
    kernel_sr_pc: fim_$sr_pc_t;           { 0x54 }
    user_sr: fim_$word_set_t;             { 0x5A }
    fp_save_ptr: integer32;               { 0x5C }
    signal: integer;                      { 0x60 }
    mask: integer32;                      { 0x62 }
    user_pc: integer32;                   { 0x66 }
  end;
  fim_$df_ptr_t = ^fim_$df_t;

  { FIM_$BUILD_DF's two results, the new USP and SSP (from 1). }
  fim_$result_t = array[1..2] of integer32;
  fim_$result_ptr_t = ^fim_$result_t;

  { A longword reached through an integer address (FIM_$GET_USER_PC). }
  fim_$long_ptr_t = ^integer32;

var
  { FIM_IN_FIM (map symbol, +0x000 of FIM_'s data segment; no `$', but
    the map lists only global symbols): per ASID, from 0, tested for the
    sign, set and cleared by FIM_$BUILD_DF: booleans.  Defined in
    fim/fim.pas. }
  fim_in_fim: extern array[0..57] of boolean;

  { FIM_$QUIT_INH and FIM_$DELIV_EC (map symbols in the FIM_WIRED data
    run): per ASID, from 0, the symbol the base: booleans, cleared and
    set; eventcounts, indexed by as * 12. }
  fim_$quit_inh: extern array[0..57] of boolean;
  fim_$deliv_ec: extern array[0..57] of ec_$eventcount_t;

  { FIM_$USER_FIM_ADDR (map symbol, +0x3C of FIM_'s data segment): the
    user FIM handler per ASID, from 0.  integer32, as the conformance
    unit fim_get_fim_addr.pas has it (the routines return it in D0 and
    test it against 0).  Defined in fim/fim.pas. }
  fim_$user_fim_addr: extern array[0..57] of integer32;

  { BUS_ERROR_VEC (map symbol of the TRAP_PAGE data segment, the vector
    at 0x8): FIM_$BUILD_DF compares it with FIM_$COLD_BUS_ERR's
    address. }
  bus_error_vec: extern univ_ptr;

%if pmmu_page_maps %then
  { MMU_$BUS_STATUS (map symbol, a word of the hand-written FIM_WIRED
    data): the MMU's status of the last bus error, which FIM_$BUILD_DF
    stores as the fault information's word. }
  mmu_$bus_status: extern integer;
%endif

  { OS_STACK_BASE (map symbol in PROC1_'s block): declared in
    proc1/proc1.ins.pas, where PROC1_ defines it (FIM_$BUILD_DF reads
    it). }

{ The hand-written FIM routines FIM_$BUILD_DF calls (fim/sau2/*.s and
  CRASH_SYSTEM's segment), their headings from its pushes:
  - FIM_$SIGNAL_FIRST: the status by value;
  - FIM_$CRASH: the frame and the registers by address (the pointers'
    values) and the status by address;
  - FIM_$FP_ABORT: nothing pushed;
  - FIM_$FSAVE: the saved flag and the USP by address, the FP type a
    word by value after the pad;
  - FIM_$GET_USER_SR_PTR: the process a word by value after the pad, the
    address returned in D0: an integer32 function;
  - FIM_$CLEAR_TRACE_FAULT: the ASID a word by value after the pad
    (FIM_$INIT_ASID). }
procedure fim_$signal_first(status: status_$t); options(extern, val_param);
procedure fim_$crash(var frame: fim_$exc_frame_t; var regs: fim_$regs_t;
                     in status: status_$t); extern;
procedure fim_$fp_abort; extern;
procedure fim_$fsave(out saved: integer; in out usp: integer32;
                     fp_type: integer); options(extern, val_param);
function fim_$get_user_sr_ptr(process: integer): integer32;
  options(extern, val_param);
procedure fim_$clear_trace_fault(as_id: integer); options(extern, val_param);

{ FIM_$COLD_BUS_ERR (map symbol, hand-written in a FIM_WIRED data
  segment): only its address is used (above). }
procedure fim_$cold_bus_err; extern;

{ Routine headings of the FIM_ module, in map order (FIM_'s code
  segment, WIRED_PROC).  The bodies repeat the full heading (ref 7.3.4,
  Method 2). }

{ FIM_$BUILD_DF - build the user-mode delivery frame for a fault. }
function fim_$build_df(exception_frame: fim_$exc_frame_ptr_t; usp: integer32;
                       regs: fim_$regs_ptr_t; fault_class: fim_$word_set_t;
                       signal: integer; status: status_$t;
                       result: fim_$result_ptr_t): boolean;
  options(extern, val_param);

{ FIM_$ACKNOWLEDGE - acknowledge a quit for the current address space. }
procedure fim_$acknowledge; extern;

{ FIM_$INSTALL (fim/install.pas): the result is the old handler. }
function fim_$install(in handler: integer32): integer32; extern;

{ FIM_$GET_FIM_ADDR - the current address space's user FIM handler. }
function fim_$get_fim_addr: integer32; extern;

{ FIM_$INIT_ASID and FIM_$FREE_ASID (fim/init_asid.pas,
  fim/free_asid.pas). }
procedure fim_$init_asid(in asid: integer); extern;
procedure fim_$free_asid(in asid: integer); extern;

{ FIM_$GET_USER_PC - the longword at the top of the user stack. }
function fim_$get_user_pc: integer32; extern;

const
  { Apollo's customer fault.ins.pas (SR10.2), line 89: `fault_$cleanup_set
    = 16#00120035' ("cleanup handler set", stcode.db.10.2).
    FIM_$CLEANUP's result when the handler is first established;
    MAC_$SEND and MAC_$RECEIVE compare with it. }
  fault_$cleanup_set = 16#00120035;

  { Apollo's customer fault.ins.pas (SR10.2), line 47:
    `fault_$prot_violation = 16#0012000B' (stcode.db.10.2: "protection
    boundary violation").  EC2_$WAIT stores it when an eventcount
    address lies at or above AS_$PROTECTION. }
  fault_$prot_violation = 16#0012000B;

type
  { A cleanup handler's record.  FIM_$CLEANUP (hand assembly) stores five
    longwords into it: the previous handler, the return address and
    A5..A7; FIM_$RLS_CLEANUP reads the first back.  Its callers give it
    0x18 bytes (MAC_$SEND's and MAC_$RECEIVE's under their packet
    records; PROC2, EC2 and others the same; one exception, 20).
    Apollo's user pfm_$cleanup_rec is 64 bytes (`pad: array [0..15] of
    linteger'); the kernel's is smaller. }
  fim_$cleanup_rec_t = record
    pad: array[1..6] of integer32;
  end;

{ FIM_$CLEANUP and FIM_$RLS_CLEANUP (hand assembly in the FIM_ASM run:
  no frame, the argument read off the stack).  FIM_$CLEANUP writes the
  record and returns a status in D0, fault_$cleanup_set at once and the
  fault's status when a fault unwinds to it (setjmp's shape);
  FIM_$RLS_CLEANUP reads the record.  Both take the record by address
  (MAC_$SEND).  Apollo's customer pfm.ins.pas declares the user routines
  so, `FUNCTION pfm_$cleanup (OUT cl_rec: pfm_$cleanup_rec): status_$t ;
  OPTIONS(ABNORMAL, EXTERN)' ("04/06/84 apl Added OPTIONS(ABNORMAL) to
  keep optimizer happy") and `pfm_$rls_cleanup (IN OUT cl_rec; OUT st)';
  the kernel's FIM_$RLS_CLEANUP has no status (one argument pushed, one
  read).  The callers of FIM_$CLEANUP save every callee-saved register
  and keep their locals in the frame across it (MAC_$SEND, MAC_$RECEIVE,
  mac/send.pas), which is what `abnormal' asks of the compiler (ref
  5.5.6). }
function fim_$cleanup(out rec: fim_$cleanup_rec_t): status_$t;
  options(abnormal, extern);
procedure fim_$rls_cleanup(in out rec: fim_$cleanup_rec_t); extern;

{ FIM_$POP_SIGNAL (hand assembly in the FIM_ASM run after
  FIM_$RLS_CLEANUP, no frame): the record's address read off the stack,
  its longword at +0x10 (the stack pointer FIM_$CLEANUP saved) read,
  nothing written.  PCHIST_$UNIX_PROFIL_CNTL passes its cleanup record
  when FIM_$CLEANUP returns a fault's status: by address, `in'. }
procedure fim_$pop_signal(in rec: fim_$cleanup_rec_t); extern;

{ FIM_$DELIVER_TRACE_FAULT (hand assembly in FIM_ASM: no frame, the
  word by value off the stack).  PCHIST_$COUNT pushes the pad and
  PROC1_$AS_ID's value: `val_param'. }
procedure fim_$deliver_trace_fault(as_id: integer); options(extern, val_param);

{ FIM_$SIGNAL (hand assembly in FIM_ASM, after FIM_$POP_SIGNAL: no
  frame, the status read off the stack as a longword; it unwinds to the
  current process's innermost cleanup handler).  PKT_$COPY_TO_PA pushes
  the status's value: by value, `val_param', as FIM_$SIGNAL_FIRST's
  heading (above). }
procedure fim_$signal(status: status_$t); options(extern, val_param);


const
  { The two statuses PEB_$TEST_PARITY_ERR stores (the first also
    MEM_$ECCC_LOG's crash), with the names and
    values of Apollo's customer fault.ins.pas of SR10.2 (lines 51 and 63;
    stcode.db.10.2's texts: "uncorrectable memory error detected", "PEB
    WCS parity error"). }
  fault_$eccu             = 16#0012000F;
  fault_$wcs_parity       = 16#0012001B;

{ FIM_$UII and FIM_$FLINE (map symbols; hand assembly, fim/m68k/uii.s
  and the FIM_ASM run, entered through the exception vectors): the
  unimplemented-instruction and line-F handlers.  Only their addresses
  are used, stored into the line-F vector (PEB_$INIT, PEB_$LOAD_WCS's
  nested check).  No parameters. }
procedure fim_$uii; extern;
procedure fim_$fline; extern;

{ }

const
  { Apollo's customer fault.ins.pas (SR10.2), lines 57 and 61:
    `fault_$single_step = 16#00120015', `fault_$blast = 16#00120019'.
    XPD_$CAPTURE_FAULT compares the fault status with both. }
  fault_$single_step      = 16#00120015;
  fault_$blast            = 16#00120019;

type
  { An address space's trace status (FIM_$TRACE_STS's elements): a
    status longword, set whole (XPD_$CAPTURE_FAULT) and compared whole
    (XPD_$COPY_MEMORY), and with bit 23 set alone after clearing it: the
    constant 1 into a one-bit field that is not a boolean, on the
    record's word, where a boolean would be a bit set on the byte.  The
    bit is the one PROC2's fault status carries as a boolean
    (proc2/proc2_data.ins.pas proc2_$fault_param_t). }
  fim_$trace_sts_t = packed record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (high_byte: 0..255;              { 0x00 }
          signal_flag: 0..1;              { 0x01, bit 7 }
          unused_bits: 0..127;            { 0x01, bits 6..0 }
          code: integer);                 { 0x02 }
  end;

  { The FP state areas FIM_$FP_GET_STATE and _$FP_PUT_STATE take: a
    length longword, then the state (both are buffers, the hand-written
    routines step past the length).  A univ formal. }
  fim_$fp_area_t = array[1..64] of integer32;

var
  { FIM_$TRACE_STS (map symbol in the FIM_WIRED data run): per address
    space from 0, 58 longwords to FIM_$QUIT_INH; indexed with the symbol
    as the base (XPD_$CAPTURE_FAULT). }
  fim_$trace_sts: extern array[0..57] of fim_$trace_sts_t;

{ FIM_$FP_GET_STATE and FIM_$FP_PUT_STATE (hand assembly in the FIM_ASM
  run: no frame, the two arguments read off the stack after the register
  pushes): two buffers by address, the default convention.
  XPD_$FP_GET_STATE and XPD_$FP_PUT_STATE pass their two slots.  GET
  fills both (`out'), PUT reads both (`in').  The second is the second
  buffer, as XPD passes it. }
procedure fim_$fp_get_state(out state: univ fim_$fp_area_t;
                            out aux: univ fim_$fp_area_t);
  extern;
procedure fim_$fp_put_state(in state: univ fim_$fp_area_t;
                            in aux: univ fim_$fp_area_t);
  extern;


type
  { The context FIM_$PROC2_STARTUP starts a process from, 8 bytes: the
    user stack pointer, then the program counter
    (fim/m68k/proc2_startup.s). }
  fim_$startup_context_t = record
    usp: univ_ptr;                        { 0x00 }
    pc: univ_ptr;                         { 0x04 }
  end;

{ FIM_$PROC2_STARTUP (hand assembly, fim/m68k/proc2_startup.s): the
  context's address read off the stack, the record only read: `in', by
  address.  os_$start_proc2 passes on its own slot.  It never returns
  (FIM_$EXIT's return from exception).  `univ': PROC2_$STARTUP passes
  its own 10-byte argument record, proc2/proc2.ins.pas
  proc2_$startup_args_t, whose first two longwords are this record's;
  os_$start_proc2's call is unchanged by it. }
procedure fim_$proc2_startup(in ctx: univ fim_$startup_context_t); extern;

{ FIM's exception entry points (map symbols in FIM's hand-written code;
  fim/sau2/), whose addresses OS_$INIT's vector table holds
  (os/init.pas, the static table at OS_INIT_DATA +0xE0, RELOC cells):
  entered by the CPU's vectors, not called, so parameterless headings
  serve only `addr'.  FIM_$COLD_BUS_ERR, FIM_$UII and FIM_$FLINE are
  declared above. }
procedure fim_$addr_err; extern;
procedure fim_$ill_instr; extern;
procedure fim_$zero_div; extern;
procedure fim_$chk_instr; extern;
procedure fim_$trapv_instr; extern;
procedure fim_$priv_viol; extern;
procedure fim_$trace; extern;
procedure fim_$coproc; extern;
procedure fim_$inv_stack; extern;
procedure fim_$spurious_int; extern;
procedure fim_$undef_trap; extern;
procedure fim_$soft_fault; extern;
procedure fim_$fp_bsun; extern;
procedure fim_$fp_inexact; extern;
procedure fim_$fp_div_zero; extern;
procedure fim_$fp_undflo; extern;
procedure fim_$fp_op_err; extern;
procedure fim_$fp_ovrflo; extern;
procedure fim_$fp_sig_nan; extern;
%if mmu_fault_vectors %then
{ FIM_$ACC_VIOL, FIM_$FP_TRAP (map symbols; hand assembly): the access
  violation's and the FP ASID exception's entries, vectors 16#83 and 16#84
  (`mmu_fault_vectors'), never called. }
procedure fim_$acc_viol; extern;
procedure fim_$fp_trap; extern;
%endif
%if ecc_memory %then
{ FIM_$ECCC_TRAP, FIM_$ECCU_TRAP (map symbols; hand assembly): the
  corrected and the uncorrectable memory error's entries, vectors 16#F0
  and 16#FF (`ecc_memory'), never called. }
procedure fim_$eccc_trap; extern;
procedure fim_$eccu_trap; extern;
%endif

{ FIM_$PARITY_TRAP (hand assembly in FIM's code, a map symbol): an
  exception entry, never called; OS_$INIT stores its address into
  vector 31 (the level-7 autovector; the immediate a RELOC cell).
  Declared as a procedure for its address only, as the other entries
  above. }
procedure fim_$parity_trap; extern;
%if fim_nmi %then

{ FIM_$NMI (hand assembly in FIM's code, a map symbol): the
  non-maskable interrupt's entry, vector 31 (OS_$INIT's vector table).
  Declared as a procedure for its address only, as the other entries
  above. }
procedure fim_$nmi; extern;
%endif

{ FIM_$BUS_ERR (hand assembly in FIM's exception code): OS_$INIT
  installs it as the bus-error vector (the immediate a RELOC cell).
  Declared as a procedure for its address only, as the other entries
  above. }
procedure fim_$bus_err; extern;

%if mmu_fault_vectors %then
{ FIM_$REG_FAULT, FIM_$PAGE_FAULT (map symbols; hand assembly in FIM's
  exception code): OS_$INIT installs the first for the region fault
  (vector 128) and the second for the segment and page faults (129,
  130), with the bus-error vector (`mmu_fault_vectors').  For their
  addresses only. }
procedure fim_$reg_fault; extern;
procedure fim_$page_fault; extern;
%endif

type
  { The signal context a user signal handler returns through (4.3BSD's
    m68k sigcontext, its names and offsets): PROC2_$SIGRETURN reads the
    first two longwords through the pointer, sc_onstack tested for
    non-zero and sc_mask stored as a signal set (into the process
    entry's 32-member set); FIM_$FAULT_RETURN reads sc_fp, sc_ap, sc_pc
    and sc_ps as longwords (fim/m68k/fault_return.s).  0x1C bytes. }
  fim_$sigcontext_t = record
    sc_onstack: integer32;                { 0x00 }
    sc_mask: set of 0..31;                { 0x04 }
    sc_sp: integer32;                     { 0x08 }
    sc_fp: integer32;                     { 0x0C }
    sc_ap: integer32;                     { 0x10 }
    sc_pc: integer32;                     { 0x14 }
    sc_ps: integer32;                     { 0x18 }
  end;
  fim_$sigcontext_ptr_t = ^fim_$sigcontext_t;

{ FIM_$FAULT_RETURN (hand assembly, fim/m68k/fault_return.s; a map
  symbol): no frame, the three arguments read off the stack, each the
  address of a pointer: the sigcontext pointer, the register area's
  pointer, and the FP state's pointer, tested and passed on to
  FIM_$FRESTORE by address.  Only read: `in', by address (the default
  convention).  PROC2_$SIGRETURN passes its own slots on.  It does not
  return.  context is univ so a caller may hold the pointer as a
  univ_ptr (PROC2_$SIGRETURN's heading, proc2/proc2.ins.pas, which is
  included before this file). }
procedure fim_$fault_return(in context: univ fim_$sigcontext_ptr_t;
                            in regs: univ_ptr;
                            in fp_state: univ_ptr); extern;

{ ---- For PROC2_$CREATE.  Nothing above is changed. ---- }

var
  { FIM_$INITIAL_STACK_SIZE (map symbol; a longword cell in FIM's
    hand-written code, the FIM_UNWIRED data segment; "Bytes reserved
    above a new process's startup context", value 8 in the image).
    PROC2_$CREATE adds it to a longword constant and subtracts the sum
    from the new stack's address: a longword in address arithmetic,
    linteger as the stack address it is subtracted from
    (PROC1_$ALLOC_STACK's result).  The name is the map's. }
  fim_$initial_stack_size: extern linteger;

{ FIM_$FP_INIT (hand assembly, fim/m68k/fp_init.s; a map symbol in the
  FIM_WIRED data run): no frame, the word read off the stack: one word
  by value.  PROC2_$CREATE pushes it with the value-parameter pad:
  `val_param'.  The word is the new process's ASID. }
procedure fim_$fp_init(asid: integer); options(extern, val_param);

{ ---- FIM's dispatch codes, named. ----

  An exception frame's format code (the high nibble of the frame's
  format/vector word; FIM_$BUILD_DF's `case format of', arms 8, 10 and
  11; 8 is the 68010's long bus fault frame).  No Apollo insert declares
  them. }
const
  fim_$frame_format_short = 16#0;
  fim_$frame_format_throw = 16#1;
  fim_$frame_format_instr = 16#2;
  fim_$frame_format_bus_68010 = 16#8;
  fim_$frame_format_coproc = 16#9;
  fim_$frame_format_short_bus = 16#A;
  fim_$frame_format_long_bus = 16#B;
{ ---- end of the dispatch codes ---- }

%if pbu_driver %then
{ ---- On the SAUs with the PBU (`pbu_driver'): what the SAU5
  FIM_$BUILD_DF adds. ---- }

var
  { CPU_B_PBU_SWITCH (map symbol, in the hand-written FIM_WIRED data
    after FIM_$TRACE_BIT, on the SAU3..SAU8): a word, nonzero while the
    processor runs for a PBU (PBU_$INT_FAULT_COM stores it from its
    stack); FIM_$BUILD_DF tests it as a word against 0, FIM_$BUS_ERR its low
    byte.  Defined by fim/m68k/bus_err.s under its `pbu_driver' arm (the
    SAU5's FIM_WIRED data is 0x10C8 bytes, against the SAU2's 0x1074:
    this word, an alignment word and FIM_$BUS_ERR's PBU fault path).
    integer. }
  cpu_b_pbu_switch: extern integer;

{ PBU_$GET_DIAG_PTR and PBU_$INT_FAULT_COM, which FIM_$BUILD_DF calls,
  are pbu/pbu.ins.pas's (hand assembly in PBU_ASM). }
%endif
