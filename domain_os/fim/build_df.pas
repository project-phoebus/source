{ FIM_$BUILD_DF - build the user-mode delivery frame for a fault.

  Image addresses:
    sau2  0x00E0A458  FIM_$BUILD_DF
    sau3  0x00E0A458  FIM_$BUILD_DF
    sau4  0x0F80ABE0  FIM_$BUILD_DF
    sau5  0x00E0A32C  FIM_$BUILD_DF
    sau8  0x03C0B138  FIM_$BUILD_DF
    sau9  0x3C40BE38  FIM_$BUILD_DF

  - A supervisor-mode fault crashes the system unless it is an access
    fault at interrupt level 0, after cold start, with no resource lock
    held; then the first cleanup handler is signaled.
  - An address space with no user FIM, or already in it, is deleted (in
    the first process, the system crashes).
  - The result is false when PROC2_$DELIVER_FIM delivers nothing: a
    format-0 frame at the OS stack's top then carries the SR and PC back.
  - info is not cleared first: the fields a frame format does not set
    keep the frame's bytes.
  - With the PBU (`pbu_driver'), a PBU fault's frame is built in the
    PBU's diagnostic area and handed to PBU_$INT_FAULT_COM.
  - With `fault_frame_addr' an access fault's address is the frame's
    longword at +0x0A, its status and instruction words zero; with
    `fp_state_in_cpu' no FPU state is aborted or saved.
  - The MC68010's bus error frame (format 8) is taken only with
    `pft_mmu'; with `pmmu_page_maps' the information's word is the MMU's
    bus status; the board's status replaces a PEB interrupt's only with
    `peb_board'.

  Status stored: none.
}

{ TODO(pascal) the frame is not reproduced

  The SAU2 image's frame has never-addressed gaps where the
  register-held locals keep slots in an order not seen, and the result
  variable lies between the locals (dpc puts it below them).  The
  declarations below do not follow the image's frame; dpc's frame
  differs. }

{ TODO(pascal) bit 23 of a status read as the sign of its second byte

  The SAU2 image tests and clears bit 23 of df^.status and of d_status
  as the top bit of status_$t's modc byte (base/base.ins.pas, Apollo's
  0..255), PROC2_$DELIVER_FIM's signal flag.  A field 0..255 cannot be
  negative, so the original's status type had another view of that bit
  (a boolean or a signed byte there).  The source below writes `&
  16#00800000' on `all', which would compile to a bit test or a longword
  mask instead. }

{ TODO(pascal) the SAU4's FP register save around FIM_$BUILD_DF

  The SAU4 image (`fp_state_in_cpu') enters with `pea' of a descriptor
  cell after the code (16#0002, 16#003F, 16#FFFF, 16#FF64: the FP
  registers' mask, FP2..FP7, and their save area at -0x9C), links, and
  saves FP2..FP7 with six `fmove.d' before the integer registers; it
  restores them with six F-line words (opmode 1, the cells at -0x9C ..
  -0x74) before the integer registers and pops the descriptor after
  `unlk'.  The parameters are 4 bytes further up the frame.  No other
  routine of any SR10.2 image has this prologue, and the routine itself
  uses no FP register.  Neither the source construct that asks for it
  nor dpc's form of it is known; dpc emits the plain prologue. }

function fim_$build_df(exception_frame: fim_$exc_frame_ptr_t; usp: integer32;
                       regs: fim_$regs_ptr_t; fault_class: fim_$word_set_t;
                       signal: integer; status: status_$t;
                       result: fim_$result_ptr_t): boolean;
var
  frame: fim_$exc_frame_ptr_t;
  sr_pc: fim_$sr_pc_t;
  info: fim_$fault_info_t;
  format: integer;
  frame_size: integer32;
  ssw: fim_$word_set_t;
  flags: fim_$word_set_t;
  frame_end: integer32;
  d_status: status_$t;
  d_usp: integer32;
  d_signal: integer;
  d_mask: integer32;
  d_flag: boolean;
  new_usp: linteger;
%if not fp_state_in_cpu %then
  fp_type: integer;
  fp_saved: integer;
%endif
  df: fim_$df_ptr_t;
  kframe: integer32;
  user_frame: integer32;
  stack_top: linteger;
  stack_low: linteger;
  link: fim_$long_ptr_t;
  fp: linteger;
  i: integer;
%if pbu_driver %then
  pbu_mode: boolean;                      { a PBU fault (CPU_B_PBU_SWITCH) }
%endif
begin
  fim_$build_df := true;

  frame := exception_frame;
  sr_pc.sr := frame^.sr;
  sr_pc.pc := frame^.pc;

  format := frame^.format_vector.format;
  frame_size := fim_frame_size[format];

%if fault_frame_addr %then
  { an access fault's address, the frame's longword at +0x0A }
  if 12 in fault_class then begin
    info.ssw := [];
    info.addr := frame^.f8_fault_addr;
    info.word := 0;
  end;
%else
  case format of
%if pft_mmu %then
    fim_$frame_format_bus_68010: begin
      info.ssw := frame^.f8_ssw;
      info.addr := frame^.f8_fault_addr;
      info.word := frame^.f8_instr_in;
    end;
%endif
    fim_$frame_format_short_bus: begin
      info.word := frame^.ab_stage_b;
      ssw := frame^.ab_ssw;
      if 8 in ssw then
        info.addr := frame^.ab_data_fault_addr
      else if 14 in ssw then
        info.addr := frame^.pc + 4
      else begin
        info.addr := frame^.pc + 2;
        info.word := frame^.ab_stage_c;
      end;
      info.ssw := ssw;
    end;
    fim_$frame_format_long_bus: begin
      info.word := frame^.ab_stage_b;
      ssw := frame^.ab_ssw;
      if 8 in ssw then
        info.addr := frame^.ab_data_fault_addr
      else begin
        info.addr := frame^.ab_stage_b_addr;
        if 15 in ssw then begin
          info.addr := info.addr - 2;
          info.word := frame^.ab_stage_c;
        end;
      end;
      info.ssw := ssw;
    end;
    otherwise { empty };
  end;
%endif
%if pmmu_page_maps %then
  info.word := mmu_$bus_status;
%endif

%if pbu_driver %then
  pbu_mode := cpu_b_pbu_switch <> 0;
%endif
  flags := fault_class;
  frame_end := frame_size + integer32(frame);
  regs^[16] := frame_end;

  { a supervisor-mode fault }
  if 13 in sr_pc.sr then
%if pbu_driver %then
  if pbu_mode then begin
    { a PBU fault in supervisor mode: only an access above the OS
      stack crashes }
    if info.addr > linteger(addr(os_stack)) then begin
      fim_$crash(exception_frame^, regs^, status);
      return;
    end;
  end
  else
%endif
  begin
    flags := flags + [14];
    if (sr_pc.sr * [8..10] <> [])
       or else (bus_error_vec = addr(fim_$cold_bus_err))
       or else not (12 in fault_class)
       or else ((proc1_$get_locks & 16#0FFFE000) <> 0) then begin
      fim_$crash(exception_frame^, regs^, status);
      return;
    end;
    fim_$signal_first(status);
    if info.addr > linteger(addr(os_stack)) then begin
      fim_$crash(exception_frame^, regs^, status);
      return;
    end;
    acl_$clear_super;
    name_$cleanup;
    if proc1_$inhibit_check(proc1_$current_pcb) then
      crash_system(status_$fault_supervisor_fault_while_resource_locks_set);
  end;

  if fim_in_fim[proc1_$as_id]
     or else (fim_$user_fim_addr[proc1_$as_id] = 0) then begin
    fim_in_fim[proc1_$as_id] := false;
    if proc1_$current = 1 then begin
      fim_$crash(exception_frame^, regs^, status);
      return;
    end;
    proc2_$delete;
  end;

  fim_in_fim[proc1_$as_id] := true;
  new_usp := usp;
  d_status := status;
  regs^[16] := new_usp;
  d_usp := new_usp;
  d_signal := signal;
%if pbu_driver %then
  if not pbu_mode then begin
%endif
  { the register block's and the SR/PC record's addresses by value
      (proc2/proc2.ins.pas, the heading's evidence from
      PROC2_$DELIVER_FIM's body); the pushes are those of the objects by
      address too (`addr(x)' by value). }
  if not proc2_$deliver_fim(d_signal, d_status, d_usp, regs, addr(sr_pc),
                            d_mask, d_flag) then begin
    { nothing to deliver }
    kframe := os_stack_base[proc1_$current] - fim_frame_size[0];
    with fim_$exc_frame_ptr_t(kframe)^ do begin
      sr := sr_pc.sr;
      pc := sr_pc.pc;
      format_vector.fv_word := 0;
    end;
    result^[1] := regs^[16];
    result^[2] := kframe;
    regs^[16] := kframe;
    fim_in_fim[proc1_$as_id] := false;
    fim_$build_df := false;
    return;
  end;

  new_usp := d_usp;
%if pbu_driver %then
  end;
%endif

  if (d_status.all = fim_blast_signal_status)
     and then (proc1_$current <> 1) then
    proc2_$delete;
  regs^[16] := frame_end;
  if d_flag then
    flags := flags + [8];

%if pbu_driver %then
  if pbu_mode then begin
    { the delivery frame goes in the PBU's diagnostic area }
    if frame_size = 0 then
      crash_system(status_$fault_invalid_stack_format);
    new_usp := linteger(pbu_$get_diag_ptr(regs^[16])) + fim_df_size;
  end
  else
%endif
  if (new_usp >= as_$global_a) or else (as_$private + 1024 > new_usp)
     or else odd(new_usp) then
    new_usp := as_$stack_low + 1024;

%if not fp_state_in_cpu %then
%if pbu_driver %then
  if not pbu_mode then
%endif
  if not (15 in fault_class) then
    fim_$fp_abort
  else begin
    if 2 in fault_class then
      fp_type := 1
    else if 3 in fault_class then
      fp_type := 2
    else
      fp_type := 0;
    d_usp := new_usp;
    fim_$fsave(fp_saved, d_usp, fp_type);
    new_usp := d_usp;
    if fp_saved <> 0 then
      flags := flags + [9];
  end;
%endif

  new_usp := new_usp - fim_df_size;
  df := fim_$df_ptr_t(new_usp);
  df^.magic := fim_df_magic;
  df^.status := d_status;
  df^.signal := d_signal;
  df^.mask := d_mask;

  for i := 1 to 16 do
    df^.regs[i] := regs^[i];
  df^.regs[16] := usp;

  if 12 in fault_class then
    df^.fault_info := info;

  df^.flags_version.class_15 := 15 in flags;
  df^.flags_version.supervisor := 14 in flags;
  df^.flags_version.class_13 := 13 in flags;
  df^.flags_version.fault_info := 12 in flags;
  df^.flags_version.status_23 := (df^.status.all & 16#00800000) <> 0;
  df^.status.all := df^.status.all & (-16#00800001);
  df^.flags_version.always := true;
  df^.flags_version.fp_saved := 9 in flags;
  df^.flags_version.deliver_flag := 8 in flags;

  df^.flags_version.version := fim_df_version;
  df^.reserved_50 := 0;
  if (d_status.all & 16#00800000) <> 0 then begin
    df^.flags_version.status_23 := true;
    df^.status.all := df^.status.all & (-16#00800001);
  end;

  if 13 in sr_pc.sr then begin
    df^.kernel_sr_pc.sr := sr_pc.sr;
    df^.kernel_sr_pc.pc := sr_pc.pc;
    user_frame := fim_$get_user_sr_ptr(proc1_$current);
  end
  else begin
    df^.kernel_sr_pc.sr := [];
    df^.kernel_sr_pc.pc := 0;
    user_frame := integer32(frame);
  end;
  df^.user_sr := fim_$exc_frame_ptr_t(user_frame)^.sr;
  df^.user_pc := fim_$exc_frame_ptr_t(user_frame)^.pc;

%if fp_state_in_cpu %then
  df^.fp_save_ptr := 0;
%else
  if 9 in flags then
    df^.fp_save_ptr := new_usp + fim_df_size
  else
    df^.fp_save_ptr := 0;
%endif

  { the caller's A6, up the frame chain }
  stack_top := os_stack_base[proc1_$current];
  stack_low := stack_top - 16#1000;
  link := addr(regs^[15]);
  repeat
    fp := link^;
    if (fp <= stack_low) or else (fp >= stack_top)
       or else (fp >= linteger(link)) or else odd(fp) then
      exit;
    link := fim_$long_ptr_t(fp);
  until false;
  df^.regs[15] := fp;

%if pbu_driver %then
  { a PBU fault goes back through the PBU's fault path (which does not
    return here) }
  if pbu_mode then begin
    fim_in_fim[proc1_$as_id] := false;
    pbu_$int_fault_com(regs^[16]);
  end;
%endif

%if peb_board %then
  if df^.status.all = status_$peb_interrupt then
    df^.status.all := peb_$get_status;
%endif

  kframe := os_stack_base[proc1_$current] - fim_frame_size[0];
  with fim_$exc_frame_ptr_t(kframe)^ do begin
    sr := [];
    pc := fim_$user_fim_addr[proc1_$as_id];
    format_vector.fv_word := 0;
  end;

  result^[1] := new_usp;
  result^[2] := kframe;
  fim_in_fim[proc1_$as_id] := false;
end;
