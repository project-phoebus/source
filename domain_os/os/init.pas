{ OS_$INIT - the kernel's start-up: map the address space, start the
  subsystems, mount the boot volume and start process 2.

  Image addresses:
    sau2  0x00E337F4  OS_$INIT
    sau3  0x00E31C3C  OS_$INIT
    sau5  0x00E357E8  OS_$INIT
    sau8  0x03C37034  OS_$INIT
    sau9  0x3C439E2E  OS_$INIT

  - boot_info is the PROM's boot record, diskless the diskless reply,
    prom_cfg (`prom_config_record') the PROM's configuration record;
    the routine runs once, on the boot stack.
  - One routine, one frame: the vector installation, the boot device
    test and the terminal parameters are in-line code.
  - The node check tests NETWORK_$DISKLESS a second time after the
    prompt.

  The statics, at the start of the module's OS_INIT_DATA block:
    +0x000  mmap_table, zero: MMAP_$INIT's `out' table
            (mmap/mmap.ins.pas mmap_$init_table_t, mmap_$table_pages
            longwords: 56, 0xE0 bytes, on the SAU2; 1024, 0x1000 bytes,
            on the SAU9, the later offsets moving with it)
    +0x0E0  vectors[1..40], 0xA0 bytes: descriptors (first vector,
            count), each followed by count handler addresses
    (+0x180 is OS_$BOOT_ERRCHK's static, os/boot_errchk.pas.)

  The parts of other SAUs (base/config.ins.pas; the literal addresses
  are the SAU5's I/O space's):

  - `vme_bus': three more vector cells, VME_$INT and VME_$ERR_INT for
    vectors 28 and 29; `pbu_driver': trap 6 is PBU_$TRAP6's.
  - `tape_boot': boot device 5 is a tape boot, device 0 with
    proc2_$boot_from_tape; the mode is then a word set.
  - `gpu_driver': the graphics board's id selects the DN580's color
    display (DISPLAY3_$UID) and starts COLOR2 and the graphics processor.
  - `disp2_probe': a second display is probed and installed as
    DISPLAY2_$UID; its answer is kept in DISP2_PRESENT.
  - `power_off_check': OS_$INIT_POWER_OFF_CHECK runs before
    PACCT_$INIT (os/init_power_off_check.pas).
  - Without `pft_mmu': COLD's segment goes whole; the type-4
    protections are page write bits and segment map entries.
  - `large_address_space': the page maps of global B's two unused
    ranges are freed (os/free_gap_pmaps.pas).
  - `prom_config_record': the terminal, the server flag, a tape boot
    and the clock's frequency come from the PROM's record.
  - `calendar_service_mode': a failed calendar check stops the boot
    until the operator runs CALENDAR.
  - `crash_reboot': a server whose node number is not the volume's
    shuts down and restarts by itself.
  - Without `display_driver': no display, touch pad or blinking
    cursor; the terminal's mode is 1 and MST_$DISKLESS_INIT's color
    flag false.
  - `lpr_driver', `iic_driver': the line printer and the internet
    interface controller are started.
  - `early_as_init': AS_$INIT before COLD's segment goes;
    `boot_flags_diskless', `boot_flags_server': the diskless and server
    settings from the boot flags; `pbu_wire_at_boot',
    `atbus_int8_dummy': the PBU page wired and AT bus interrupt 8
    claimed after the checksum passes; `parity_trap_vector_30',
    `vector_seg_prot': the parity trap on vector 30 too, and the vector
    page protected by its segment.

  Status stored: none.
}

{ TODO(sau) the vector table's count on the SAU6

  The SAU6 has `vme_bus' and `fim_nmi' and a 44-cell table (its OS_$INIT
  compares the index with 44), where the two parts' cells give 45: not
  looked at. }

{ TODO(sau) the forms of the SAU4, SAU6 and SAU7 not compared

  The arms of `pft_mmu', `large_vm', `crash_reboot', `ring_node_id',
  `smd_display_memory', `calendar_service_mode' and `pmmu_page_maps'
  follow the SAU9's and the SAU8's code, their banks the other SAUs'
  maps and calls.  Not compared there: TIME_$INIT's argument without
  the calendar probe on the SAU4, SAU6 and SAU7 (the SAU9's, SAU8's and
  SAU3's `true'), CAL_$VERIFY's two literals (the SAU9's and SAU8's). }

{ TODO(pascal) OS_$INIT's frame

  The frame is 0x1FC bytes, the saved registers below it.  The body's
  slots, from the top: boot (0x24), the diskless copy (0x30), root_uid,
  node_uid, asid, proc2_start, vtoce_req (0x20), vtoce (0x90),
  mount_dir_uid, the boot_info copy (0x24), stored_node, prom_node,
  rounded_clock, boot_clock, keep1_high, keep1_low, paged_end,
  unwired_data, lock_info, block_hint, status, map_desc, vtop_va,
  vtop_ppn, ws_mode, term_ctrl, term_mode, probe_result, lv_num,
  vol_idx, time_flags, disk_chksum_arg, is_type4, and two expression
  temporaries, IO_$INIT's boolean (also the keep-range test's spill) and
  FILE_$SET_LEN's length.  Seventeen runs of bytes between them are read
  by no instruction (alignment, or locals the original declared and kept
  in registers).  Not settled: the two value parameters' copies sit
  among the locals, the diskless copy directly below boot and the
  boot_info copy between mount_dir_uid and stored_node, where dpc puts
  the copies first, from the top; no declaration order of the locals
  puts the copies there under dpc's rule.  The var section keeps the
  grouping by part; the image's order is the evidence for the compiler's
  rule.

  The SAU8's frame is 0x218 bytes, with the SAU2's order at the top
  (boot, then the diskless copy right below it, the boot_info copy
  among the locals), not compared slot by slot.

  The SAU3's frame is 20 bytes smaller than the SAU2's (0x1E8 bytes):
  it has no slots for probe_result (`display_driver') and for
  time_flags, boot_clock and rounded_clock, which only `boot_time_lock'
  uses; the three are declared under every configuration here, as the
  SAU9's frame has not been compared. }

[section(os_init_proc, os_init_data)]
%if prom_config_record %then
procedure os_$init(boot_info: os_$boot_info_t;
                   diskless: os_$diskless_info_t;
                   in prom_cfg: os_$prom_config_t);
%else
procedure os_$init(boot_info: os_$boot_info_t;
                   diskless: os_$diskless_info_t);
%endif
label
  10;                                     { after the paging file }
const
  { the vector table's cells }
%if vme_bus %then
%if fim_nmi %then
  os_init_vector_cells = 45;
%else
  os_init_vector_cells = 43;
%endif
%else
%if fim_nmi %then
  os_init_vector_cells = 42;
%else
  os_init_vector_cells = 40;
%endif
%endif
type
  { The location descriptor passed to MST_$MAP_CANNED_AT and built for the
    paging file, a packed record from the most significant bit: remote,
    bit 31, cleared and set on the longword's high byte; on a disked
    boot the other 31 bits one field, set to 1 (a constant store into a
    sub-word field); on a diskless one bits 25..20 cleared on the high
    word, and the low 20 bits the mother node (an unmasked merge: the
    node linteger). }
  os_$init_loc_t = packed record
    case integer of
      1: (all: integer32);
      2: (remote: boolean;                { bit 31 }
          local_part: 0..16#7FFFFFFF);    { bits 30..0 }
      3: (bit_31: boolean;                { bit 31 }
          bits_30_26: 0..31;              { bits 30..26 }
          bits_25_20: 0..63;              { bits 25..20 }
          node: 0..16#FFFFF);             { bits 19..0 }
  end;

  { The paging file's location request, handed to VTOCE_$READ and to
    AST_$ACTIVATE_AOTE_CANNED, and cleared as eight longwords on a
    diskless boot; the paging file's VTOCE, read by VTOCE_$READ and
    cleared as 36 longwords.  Each a variant record, so that one variable
    takes both views (the image's one frame object each). }
  os_$init_req_view_t = record
    case integer of
      1: (req: vtoc_$lookup_req_t);
      2: (longs: array[1..8] of integer32);
  end;
  os_$init_vtoce_view_t = record
    case integer of
      1: (v: vtoce_$t);
      2: (o: os_$init_vtoce_t);
  end;
  os_$init_byte_array_t = array[0..1023] of char;
  os_$init_byte_array_ptr_t = ^os_$init_byte_array_t;

  { One cell of the vector table: a descriptor (the first vector, the
    number of handler cells after it) or a handler's address. }
  os_$init_vector_t = record
    case integer of
      1: (handler: univ_ptr);
      2: (first_vector: integer;
          count: integer);
  end;
var
  mmap_table: static mmap_$init_table_t;          { +0x000, zero }
  vectors: static array[1..os_init_vector_cells] of os_$init_vector_t := [
    [first_vector := 2, count := 10],             { +0x0E0 }
    [handler := addr(fim_$cold_bus_err)],
    [handler := addr(fim_$addr_err)],
    [handler := addr(fim_$ill_instr)],
    [handler := addr(fim_$zero_div)],
    [handler := addr(fim_$chk_instr)],
    [handler := addr(fim_$trapv_instr)],
    [handler := addr(fim_$priv_viol)],
    [handler := addr(fim_$trace)],
    [handler := addr(fim_$uii)],
    [handler := addr(fim_$uii)],
    [first_vector := 13, count := 2],             { +0x108 }
    [handler := addr(fim_$coproc)],
    [handler := addr(fim_$inv_stack)],
    [first_vector := 24, count := 1],             { +0x114 }
    [handler := addr(fim_$spurious_int)],
%if vme_bus %then
    [first_vector := 28, count := 2],             { +0x11C, the later
                                                    cells 0xC further }
    [handler := addr(vme_$int)],
    [handler := addr(vme_$err_int)],
%endif
%if fim_nmi %then
    [first_vector := 31, count := 1],             { the non-maskable
                                                    interrupt; the later
                                                    cells 8 further }
    [handler := addr(fim_$nmi)],
%endif
    [first_vector := 32, count := 15],            { +0x11C }
    [handler := addr(svc_$trap0)],
    [handler := addr(svc_$trap1)],
    [handler := addr(svc_$trap2)],
    [handler := addr(svc_$trap3)],
    [handler := addr(svc_$trap4)],
    [handler := addr(svc_$trap5)],
%if pbu_driver %then
    [handler := addr(pbu_$trap6)],
%else
    [handler := addr(fim_$undef_trap)],
%endif
    [handler := addr(svc_$trap7)],
    [handler := addr(svc_$trap8)],
    [handler := addr(fim_$undef_trap)],
    [handler := addr(fim_$undef_trap)],
    [handler := addr(fim_$undef_trap)],
    [handler := addr(fim_$undef_trap)],
    [handler := addr(fim_$undef_trap)],
    [handler := addr(fim_$soft_fault)],
    [first_vector := 48, count := 7],             { +0x15C }
    [handler := addr(fim_$fp_bsun)],
    [handler := addr(fim_$fp_inexact)],
    [handler := addr(fim_$fp_div_zero)],
    [handler := addr(fim_$fp_undflo)],
    [handler := addr(fim_$fp_op_err)],
    [handler := addr(fim_$fp_ovrflo)],
    [handler := addr(fim_$fp_sig_nan)]];          { +0x17C }

  boot: os_$boot_info_t;
  root_uid: uid_$t;
  node_uid: uid_$t;
  paged_end: linteger;                    { register-held at first }
  unwired_data: linteger;                 { register-held at first }
  status: status_$t;
  map_desc: os_$init_loc_t;               { never written before the five
                                            calls (kept) }
  vtop_va: integer32;
  vtop_ppn: integer32;
%if tape_boot %then
  ws_mode: proc2_$ws_mode_t;
%else
  ws_mode: integer;
%endif
  term_ctrl: integer;
  term_mode: integer;
  is_type4: boolean;
%if tape_boot %then
  is_five: boolean;
%endif
  is_one: boolean;
  ppn: integer32;
  i: integer;
  v: integer;                             { the `for' index: its element
                                            pointer stepped }
  low_base: integer32;
  low_top: integer32;
  kernel_base: integer32;
  unwired_proc: linteger;
  mst_high: integer32;
  va: linteger;
  ro_low: integer32;
  wired_data: univ_ptr;
  calendar_present: boolean;
  time_flags: boolean;
  lv: integer;
  lv_num: integer;
  mount_dir_uid: uid_$t;
  vol_idx: integer;
  lv_label: bat_$label_ptr_t;
  block_hint: fm_$block_addr_t;
  vtoce_req: os_$init_req_view_t;
  vtoce: os_$init_vtoce_view_t;
  stack_low: os_$init_byte_array_ptr_t;   { the start of the cleared KB }
  idx: integer;
  disk_chksum_arg: boolean;
%if display_driver %then
  probe_result: char;
%endif
  asid: integer;
  boot_clock: time_$clock_t;
  rounded_clock: time_$clock_t;
  lock_info: integer32;
  keep1_low: linteger;
  keep1_high: linteger;
  keep2_low: linteger;
  keep2_high: linteger;
  seg: pinteger;
  aste: ast_$aste_ptr_t;
  warned: boolean;
  prom_node: integer32;
  stored_node: integer32;
  proc2_start: fim_$startup_context_t;
  saved_net: integer32;
%if display_driver %then
  disp_type: smd_$display_type_t;
%endif
%if prom_config_record %then
  cfg: os_$prom_config_t;                 { the PROM's record's copy }
  cfg_ptr: integer32;                     { its address, for IO_$INIT and
                                            IO_$LOG_SELF_TESTS }
%endif
%if not pft_mmu %then
  va_seg: pinteger;                       { va's segment number }
%endif
%if pmmu_page_maps %then
  pmap_seg: pinteger;                     { va's segment in global B's
                                            segment map, after global
                                            A's }
%endif
%if crash_reboot %then
  server_reboot: boolean;                 { the node check shuts a server
                                            down without asking }
%endif
%if atbus_int8_dummy %then
  int8_req: io_$acquire_rec_t;            { AT bus interrupt 8's request }
  int8_unit: io_$unit_num_t;
%endif
begin
  { the parameters' copies, then the working
    copy }
  boot := boot_info;
%if prom_config_record %then
  boot.unit := 1;
  cfg := prom_cfg;
%endif

  pmap_$shutting_down_flag := false;
  mst_$pre_init;
%if pft_mmu %then
  mmu_$init;
  as_$init;

  { free COLD's two pages }
  ppn := rshft(integer32(addr(cold)), 10);
  mmu_$remove(ppn);
  mmu_$remove(ppn + 1);
%else
%if early_as_init %then
  as_$init;
%endif
  { COLD's segment removed, its pages' descriptors with it, and its
    region's root entry cleared }
  mmu_$remove_special_seg(addr(cold), 0, true);
%if large_address_space %then
  rars[rars_asid_base[0] + rshft(integer32(addr(cold)), 22)].all := 0;
%endif
%endif

  mmap_$init(mmap_table);

  { the exception vectors from the table }
  i := 1;
  while i <= os_init_vector_cells do begin
    for v := vectors[i].first_vector to
             vectors[i].first_vector + vectors[i].count - 1 do begin
      i := i + 1;
      if vectors[i].handler <> nil then
        trap_page[v] := vectors[i].handler;
    end;
    i := i + 1;
  end;

%if prom_config_record %then
  { the boot device's unit; a tape boot from the PROM's record }
  ws_mode := [];
  os_$boot_device.unit := boot.unit;
  if cfg.boot_device.kind = os_$prom_boot_tape then
    ws_mode := [proc2_$boot_from_tape];
%else
%if tape_boot %then
  { boot device 5 is a tape boot, device 1 adds the floppy }
  ws_mode := [];
  is_five := boot.device = 5;
  if is_five then begin
    boot.device := 0;
    ws_mode := [proc2_$boot_from_tape];
  end;
  is_one := boot.device = 1;
  if is_one then begin
    ws_mode := ws_mode + [proc2_$boot_from_floppy];
    boot.device := 0;
  end;
%else
  { boot device 1 is workstation mode 2 }
  ws_mode := 0;
  is_one := boot.device = 1;
  if is_one then begin
    ws_mode := 2;
    boot.device := 0;
  end;
%endif

  with os_$boot_device do begin
    device := boot.device;
    reserved := 0;
    ctlr := boot.ctlr;
    unit := boot.unit;
  end;
%endif
  mmu_$set_sysrev;

  { diskless or not }
%if prom_config_record %then
  network_$diskless := 7 in boot.flags;
%elseif boot_flags_diskless %then
  { boot flag 7 a diskless boot, 8 a disked one from the network device
    the diskless reply names; else the boot device says }
  if 7 in boot.flags then begin
    network_$diskless := true;
    discard(net_io_$boot_device(boot.device, boot.ctlr));
  end
  else if 8 in boot.flags then begin
    network_$diskless := false;
    discard(net_io_$boot_device(diskless.net_boot_device,
                                diskless.net_boot_unit));
  end
  else
    network_$diskless := net_io_$boot_device(boot.device, boot.ctlr);
%else
  network_$diskless := net_io_$boot_device(boot.device, boot.ctlr);
%endif
  if network_$diskless then begin
    network_$mother_node := diskless.mother_node;
    network_$paging_file_uid := diskless.paging_file_uid;
    root_uid := diskless.root_uid;
    node_uid := diskless.node_uid;
  end
  else begin
    root_uid := uid_$nil;
    node_uid := uid_$nil;
  end;

  proc1_$inhibit_begin;
  mst_$init;
  dxm_$init;

  { the tables must end below the I/O space }
  if linteger(addr(iodefs_guard)) > linteger(addr(iodefs)) then
    crash_system(status_$mst_no_space_available);

  { the boundaries, rounded to segments }
  low_base := integer32(addr(os_low)) & (-16#8000);
  low_top := (integer32(addr(os_low_end)) + 16#7FFF) & (-16#8000);
  kernel_base := integer32(addr(os_begin)) & (-16#8000);
  unwired_proc := linteger(integer32(addr(os_proc_unwired)) & (-16#8000));
  unwired_data := linteger(integer32(addr(os_data_unwired)) & (-16#8000));
  paged_end := linteger((integer32(addr(os_data_end)) + 16#7FFF) &
                        (-16#8000));
  mst_high := (mst_$mst_pages_limit * 1024 + integer32(addr(mste_pages)) +
               16#7FFF) & (-16#8000);
  is_type4 := boot.flags * [2, 15] = [2];

  { the low region }
  mst_$map_canned_at(low_base, os_wired_$uid, 0, low_top - low_base,
                     16#170001, false, false, map_desc.all, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the wired kernel }
  mst_$map_canned_at(kernel_base, os_wired_$uid, 0,
                     unwired_proc - kernel_base, 16#170001, false, false,
                     map_desc.all, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the unwired code, read-only on a type-4
    boot }
  if is_type4 then
    mst_$map_canned_at(unwired_proc, os_wired_$uid, 0,
                       unwired_data - unwired_proc, 16#130001, true, false,
                       map_desc.all, status)
  else
    mst_$map_canned_at(unwired_proc, os_wired_$uid, 0,
                       unwired_data - unwired_proc, 16#170001, true, false,
                       map_desc.all, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the unwired data }
  mst_$map_canned_at(unwired_data, os_wired_$uid,
                     unwired_data - unwired_proc, paged_end - unwired_data,
                     16#170001, true, false, map_desc.all, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the stacks, the tables and the MST region }
  mst_$map_canned_at(paged_end, os_wired_$uid, 0, mst_high - paged_end,
                     16#170001, false, false, map_desc.all, status);
  if status.all <> status_$ok then
    crash_system(status);

  { a type-4 boot sets the pages' protections }
  if is_type4 then begin
    va := kernel_base;
    ro_low := (integer32(addr(os_proc)) + 16#3FF) & (-16#400);
    wired_data := addr(os_data_wired);
    repeat
%if pft_mmu %then
      vtop_va := va;
      vtop_ppn := vtop_or_crash(vtop_va);
      if (ro_low > integer32(va)) or else
         (linteger(integer32(wired_data) & (-16#400)) <= va) then
        mmu_$set_prot(vtop_ppn, 16#17)
      else
        mmu_$set_prot(vtop_ppn, 16#13);
%else
      if (ro_low > integer32(va)) or else
         (linteger(integer32(wired_data) & (-16#400)) <= va) then
        mmu_$page_write_bit(univ_ptr(va), 16#17)
      else
        mmu_$page_write_bit(univ_ptr(va), 16#13);
%endif
      va := va + 16#400;
    until va >= unwired_proc;

    va := unwired_proc;
    repeat
%if pft_mmu %then
      vtop_va := va;
      vtop_ppn := vtop_or_crash(vtop_va);
      mmu_$set_prot(vtop_ppn, 16#13);
      va := va + 16#400;
%else
      { the unwired code's segments, in ASID 0's map after global A's
        entries: write-protected and supervisor-only (members 2 and 8),
        and of the table address's four low bits 2 and 3 cleared, 0 and
        1 set }
      va_seg := rshft(va, 15);
      with smaps[va_seg + smap_asid_base[0] - mst_$seg_global_b +
                 mst_$global_a_size] do begin
        flags := flags + [2, 8];
        table_bits := table_bits - [2, 3];
        table_bits := table_bits + [0, 1];
      end;
      va := va + 16#8000;
%endif
    until va >= unwired_data;
  end;
%if not pft_mmu %then
  mmu_$purge;
%endif

%if prom_config_record %then
  { the clock's frequency from the PROM's record, then the clock and
    process 1 }
  time_$sys_freq := cfg.sys_freq;
  time_$init(true);
  null_pc := addr(null_loop);
  proc1_$init;
  proc1_$set_type(proc1_$current, 1);

%endif
  { the I/O subsystem }
  peb_$init;
%if prom_config_record %then
  cfg_ptr := integer32(addr(cfg));
  io_$init(cfg_ptr, 15 in boot.flags, status);
%else
  io_$init(0, 15 in boot.flags, status);
%endif
  if status.all <> status_$ok then
    crash_system(status);

%if ring_node_id %then
  node_$me := ring_$get_id(0);
%endif
%if lpr_driver %then
  lpr_$init;
%endif
%if large_vm %then
  mem_$init;
%endif

%if prom_config_record %then
  { the terminal's parameters and the server flag, from the PROM's
    record: a display console makes a workstation }
  if cfg.console.kind = os_$prom_console_display then begin
    term_mode := 2;
    term_ctrl := 0;
    server_$flag := false;
  end
  else begin
    term_mode := 1;
    term_ctrl := cfg.console_line;
    server_$flag := true;
  end;
%else
  { the terminal's parameters, from the boot
    flags }
  term_ctrl := 1;
  if 4 in boot.flags then
    term_ctrl := 2;
%if display_driver %then
%if boot_flags_server %then
  { boot flag 1 with flag 0 also makes the node a server }
  if 0 in boot.flags then begin
    if 1 in boot.flags then
      term_mode := 1
    else begin
      term_mode := 2;
      term_ctrl := 1;
    end;
    server_$flag := 1 in boot.flags;
  end
%else
  if 0 in boot.flags then
    if 1 in boot.flags then
      term_mode := 1
    else begin
      term_mode := 2;
      term_ctrl := 1;
    end
%endif
  else begin
    term_mode := 0;
    term_ctrl := 1;
  end;
%else
  term_mode := 1;
%endif
%endif
  term_$init(term_mode, term_ctrl);

%if boot_time_lock %then
  { is there a calendar?  A disked node without
    one cannot boot.  The literal 0 one cell, pushed once and copied for
    both arguments }
  discard(io_$get_dcte(0, 0, status));
  calendar_present := status.all = status_$ok;
  if not network_$diskless and then not calendar_present then
    crash_system(status_$os_no_calendar_on_system);
  time_flags := calendar_present;
  time_$init(time_flags);
%else
%if not prom_config_record %then
  time_$init(true);
%endif
%endif

  uid_$init;
%if not prom_config_record %then
  null_pc := addr(null_loop);
  proc1_$init;
  proc1_$set_type(proc1_$current, 1);
%endif

%if display_driver %then
  smd_$init;
  tpad_$init;
%endif
  dtty_$init(term_mode, term_ctrl);
  ec2_$init_s;
  print_build_time;

  { the parity trap's vector (with `fim_nmi' vector 31 is the table's),
    then the object managers; the disk only with a disk }
%if not fim_nmi %then
  trap_page[31] := addr(fim_$parity_trap);
%if parity_trap_vector_30 %then
  trap_page[30] := addr(fim_$parity_trap);
%endif
%endif
  acl_$init;
  ast_$init;
  area_$init;
  if not network_$diskless then begin
    disk_$init;
    dbuf_$init;
  end;

  cal_$boot_volx := 0;

  { a disked boot mounts the boot volume and
    looks its paging file up; below, a diskless one names the mother
    node's }
  if not network_$diskless then begin
    { unit 0 means logical volume 1, the value
      kept in D2 for the retry below }
    lv := boot.unit;
    if lv = 0 then
      lv := 1;
    lv_num := lv;

    { the bus a zero-word cell, the two flags one
      pooled `false' cell pushed once and copied; with
      `prom_config_record' the device, the bus and the controller are
      OS_$BOOT_DEVICE's }
%if prom_config_record %then
    volx_$mount(os_$boot_device.device, os_$boot_device.reserved,
                os_$boot_device.ctlr, lv_num, false, false, uid_$nil,
                mount_dir_uid, status);
%else
    volx_$mount(boot.device, 0, boot.ctlr, lv_num, false, false, uid_$nil,
                mount_dir_uid, status);
%endif

    { a volume that needs salvaging: ask, then
      mount it anyway }
    if status.all = status_$disk_needs_salvaging then begin
      os_$print_init_error('%/%/%/%/BOOT VOLUME NEEDS SALVAGING.%.');
      if mmu_$normal_mode then
        crash_system(status);
      os_$print_init_error('Proceed to bring up OS (and risk volume)? %$');
      if not prompt_for_yes_or_no then                { prompt_for_yes_or_no }
        crash_system(status_$disk_needs_salvaging);   { a constant cell }
      lv_num := lv;
%if prom_config_record %then
      volx_$mount(os_$boot_device.device, os_$boot_device.reserved,
                  os_$boot_device.ctlr, lv_num, true, false, uid_$nil,
                  mount_dir_uid, status);
%else
      volx_$mount(boot.device, 0, boot.ctlr, lv_num, true, false, uid_$nil,
                  mount_dir_uid, status);
%endif
    end;

    if status.all <> status_$ok then
      crash_system(status);
    vol_idx := 1;
    cal_$boot_volx := 1;

    { the calendar against the volume; the three
      literals constant cells (16#192549, '5  ' and true); a refusal
      shuts the volume down and crashes with the zero longword (the cell
      before OS_$INIT, pooled) }
%if calendar_service_mode %then
    { a server's check does not ask; a calendar a workstation's operator
      refused shuts the volume down, any other failure waits for the
      operator, the lights blinking }
    if not cal_$verify(16#466866, '14 ', not server_$flag, status) then
      begin
      if not server_$flag and then (status.all = cal_$refused) then begin
        status.all := volx_$shutdown;
        crash_system(status_$ok);
      end;
      vfmt_$write2(
        '%/Switch to service mode, press reset and run CALENDAR. %.', 0, 0);
      repeat
        mmu_$mcr_change(15);
        i := 0;
        while i < 10000 do
          i := i + 1;
        mmu_$mcr_change(0);
        while i > 0 do
          i := i - 1;
      until false;
    end;
%else
    if not cal_$verify(16#192549, '5  ', true, status) and then
       (status.all = cal_$refused) then begin
      status.all := volx_$shutdown;
      crash_system(status_$ok);
    end;
%endif

    { the paging file's location descriptor,
      local: bit 31 cleared, the other 31 bits set to 1 }
    map_desc.remote := false;
    map_desc.local_part := 1;

    { the logical volume's label; the two zero
      words block_type and flags pushed as one longword }
    lv_label := dbuf_$get_block(vol_idx, 0, lv_label_$uid, 0, 0, 0, status);
    if status.all <> status_$ok then
      crash_system(status);

    { the label's current VTOCE, then the label
      released (the pointer by value: dbuf/dbuf.ins.pas) }
    block_hint := lv_label^.vtoc_header.current_vtoce;
    dbuf_$set_buff(lv_label, 8, status);

    { no paging file: the banner, then the wired
      UID stands in for it }
    if block_hint.block_num = 0 then begin
      os_$print_init_error('%/%/%/%/%/%/%/%/%.');
      os_$print_init_error('%.%/%/%/%/%/%/%/%/%.');
      os_$print_init_error('Boot device has no OS paging file.%/%.');
      os_$print_init_error(
        'see the Installation Procedures chapter in the Release Document%.');
      os_$print_init_error(
        'for information on how to correct this problem.%/%.');
      os_$print_init_error(
        'For now, the OS will NOT page, which may cause some performance%.');
      os_$print_init_error('degradation%.');
      network_$paging_file_uid := os_wired_$uid;
      goto 10;                                       { to label 10 }
    end;

    { the paging file's VTOCE; only these three
      fields of the request are written }
    vtoce_req.req.uid := uid_$nil;
    vtoce_req.req.block_hint := block_hint;
    vtoce_req.req.tail.vol_idx := vol_idx;           { the word's low byte }
    vtoce_$read(vtoce_req.req, vtoce.v, status);
    if status.all <> status_$ok then
      crash_system(status);

    { the request's address formed for each copy;
      then past the else part }
    vtoce_req.req.uid := vtoce.o.file_uid;
    network_$paging_file_uid := vtoce.o.file_uid;
  end
  else begin
    { the descriptor names the mother node:
      bit 31 set, bits 25..20 cleared on the high word, the node merged
      unmasked into bits 19..0 }
    map_desc.remote := true;
    map_desc.bits_25_20 := 0;
    map_desc.node := diskless.mother_node;

    { the request cleared, eight longwords; the
      element pointer A6 + 4 * i at (-0x9c,A1), its base A0 kept for the
      second loop }
    for i := 1 to 8 do
      vtoce_req.longs[i] := 0;

    { the mother node's paging file, the node
      from the reply; the kind's nibble, then the remote and scratch
      bits set together on one word }
    vtoce_req.req.uid := network_$paging_file_uid;
    vtoce_req.req.port := 0;
    vtoce_req.req.node := diskless.mother_node;
    vtoce_req.req.tail.kind := 1;
    vtoce_req.req.tail.remote := true;
    vtoce_req.req.tail.scratch := true;

    { the VTOCE the mother node's file stands in
      for, 36 longwords cleared through the same base, `(-0x12c,A1)' }
    for i := 1 to 36 do
      vtoce.o.longs[i] := 0;
    vtoce.o.file_uid := network_$paging_file_uid;
    vtoce.o.acl_uid := acl_$fndwrx;
    vtoce.o.length := paged_end - unwired_proc;
    vtoce.o.field_74 := 1;
  end;

  { both paths' paging-file object }
  ast_$activate_aote_canned(vtoce.o, vtoce_req.req);

10:
  { the stack's three guard pages }
  network_$really_diskless := network_$diskless;
  os_$free_va_page(integer32(addr(null_stack_guard)));
  os_$free_va_page(integer32(addr(p1_stack_guard)));
  os_$free_va_page(integer32(addr(int_stack_guard)));

  { the 1 KB interrupt stack cleared downwards,
    from INT_STACK_BASE }
  stack_low := os_$init_byte_array_ptr_t(
                 integer32(addr(int_stack_base)) - 1024);
  for i := 1023 downto 0 do
    stack_low^[i] := chr(0);
%if large_address_space %then

  { the page maps of global B's unused ranges: between the low region
    and the kernel, and between the tables and the I/O space }
  os_$free_gap_pmaps(integer32(addr(os_low_end)), integer32(addr(os_begin)),
                     true);
  os_$free_gap_pmaps(integer32(addr(iodefs_guard)), integer32(addr(iodefs)),
                     true);
%endif

  { the page frames of the boot table's entries freed, MMAP's pages;
    mmap_table[idx] through an induction pointer }
  for idx := 1 to mmap_$table_pages do
    if mmap_table[idx] <> 0 then
      os_$free_va_page(integer32(addr(mmap)) + (idx - 1) * 1024);

  { the optional checksum passes; the literals
    constant cells (0 and 2), the second call's one cell pushed once and
    copied twice }
  if network_$do_chksum then
    os_$chksum(0, 2, 0, network_$do_chksum, status);
  if disk_$do_chksum then begin
    disk_$do_chksum := false;
    disk_chksum_arg := true;
    os_$chksum(0, 0, 0, disk_chksum_arg, status);
  end;
%if pbu_wire_at_boot %then
  pbu_$wire_pbu;
%endif
%if atbus_int8_dummy %then

  { AT bus interrupt 8 claimed for DUMMY_INTERRUPT_HANDLER, with no CSR
    pages }
  int8_req.tag := 1;
  int8_req.bus := io_$bus_atbus;
  int8_req.int.has_int := true;
  int8_req.int.id.vector := 8;
  int8_req.csr.has_csr := false;
  io_$acquire(int8_req, addr(dummy_interrupt_handler), nil, int8_unit,
              status);
  if status.all <> status_$ok then
    crash_system(status);
%endif

%if display_driver %then
%if smd_display_memory %then
  { the display memory, SMD's }
  smd_$install_disp_mem;
%else
  { the display, if one answers the probe; the
    kind a pooled cell (1), the aperture 16#FC0000 one cell for both
    calls, the size 16#20000 and touch constant cells }
%if gpu_driver %then
  { the DN580's color display is at the second display's address; the
    two calls' tails merged }
  if smd_$graphic_device_id = smd_gdev_color2 then
    os_$install_display_aste(display3_$uid, 16#FA0000, 16#40000, true)
  else if testpage(1, univ_ptr(16#FC0000), probe_result) then
    os_$install_display_aste(display1_$uid, 16#FC0000, 16#20000, true);
%else
  if testpage(1, univ_ptr(16#FC0000), probe_result) then
    os_$install_display_aste(display1_$uid, 16#FC0000, 16#20000, true);
%endif
%if disp2_probe %then

  { a second display: none with a COLOR2 board }
%if gpu_driver %then
  case smd_$graphic_device_id of
    smd_gdev_color2, smd_gdev_color3:
      disp2_present := false;
    otherwise
%endif
      disp2_present := testpage(1, univ_ptr(16#FA0000), probe_result);
%if color_board %then
      if not disp2_present then
        disp2_present := testpage(1, univ_ptr(16#FF6402), probe_result);
%endif
%if gpu_driver %then
  end;
%endif
  if disp2_present then
    os_$install_display_aste(display2_$uid, 16#FA0000, 16#20000, true);
%endif
%endif
%endif

%if boot_time_lock %then
  { the purifiers wait on this lock while the time is fetched below }
  if not calendar_present then
    ml_$lock(ml_$mt_lock);
%endif

  { the three daemons; their entry points by
    address, the results not read }
  discard(proc1_$create_p(addr(pmap_$purifier_l), 16#0C000005, status));
  if status.all <> status_$ok then
    crash_system(status);
  discard(proc1_$create_p(addr(pmap_$purifier_r), 16#0C000005, status));
  if status.all <> status_$ok then
    crash_system(status);
  discard(proc1_$create_p(addr(dxm_$helper_unwired), 16#0C000006, status));
  if status.all <> status_$ok then
    crash_system(status);

  { process 1's own address space }
  asid := mst_$alloc_asid(status);                   { the word result stored }
  if status.all <> status_$ok then
    crash_system(status);
  proc1_$set_asid(asid);
  proc1_$set_type(proc1_$current, 11);

  acl_$enter_super;
  sock_$init;
  network_$init;
%if iic_driver %then
  iic_$init;
%endif
%if boot_time_lock %then

  { with no calendar of its own, the node takes
    the time from its mother node: TIME_$CLOCKH read once for the three
    stores, the clock built as high := it, low := 0, its seconds rounded
    back to a clock and the remainder kept as microseconds (the longword
    two bytes into the difference), then the Domain-to-Unix epoch added
    in place }
  if not calendar_present then begin
    network_$fetch_diskless_info(asknode_$req_boot_time, network_$mother_node);
    time_$current_clockh := time_$clockh;
    time_$boot_time := time_$clockh;
    boot_clock.high := time_$clockh;
    boot_clock.low := 0;
    time_$current_time.sec := cal_$clock_to_sec(boot_clock);
    cal_$sec_to_clock(time_$current_time.sec, rounded_clock);
    discard(sub48(boot_clock, rounded_clock));
    time_$current_time.usec := lshft(boot_clock.low32, 2);
    time_$current_time.sec := time_$current_time.sec + 16#12CEA600;
    uid_$init;
    ml_$unlock(ml_$mt_lock);
  end;
%endif

  { the load average, the file locks, the bus-error
    vector (both addresses relocated cells), DXM's wired helper }
  proc1_$init_loadav;
  file_$lock_init;
  trap_page[2] := addr(fim_$bus_err);
  discard(proc1_$create_p(addr(dxm_$helper_wired), 16#08000004, status));
  if status.all <> status_$ok then
    crash_system(status);

  { the hint cache, the naming system on the boot
    volume's root and node directories, the request servers (the count a
    constant cell, 1; NETWORK_$ADD_REQUEST_SERVERS's count, its result,
    is not read: `discard', network/network.ins.pas) }
  hint_$init_cache;
  name_$init(root_uid, node_uid);
  discard(network_$add_request_servers(1, status));
  if status.all <> status_$ok then
    crash_system(status);

  { the paging file locked; the index, the mode
    and the rights constant cells (0, 4, false) }
  file_$lock(network_$paging_file_uid, 0, 4, false, lock_info, status);
  if status.all <> status_$ok then
    crash_system(status);

  { a diskless node's paging file, the count the
    zero longword }
  if network_$diskless then
    file_$set_refcnt(network_$paging_file_uid, 0, status);

  { unless the paging file is the wired OS image
    (the record compare), the file is grown to the pageable range and
    the OS paged into it, segment by segment }
  if network_$paging_file_uid <> os_wired_$uid then begin
    { the length an expression temporary; no
      status test }
    file_$set_len(network_$paging_file_uid, paged_end - unwired_proc,
                  status);

    { the ranges a disked node keeps wired, the
      disk code and its data, widened to pages (the +16#3FF of the high
      bounds folded into the relocated immediates) }
    keep1_low := linteger(integer32(addr(os_disk_proc)) & (-16#400));
    keep1_high := linteger((integer32(addr(os_disk_proc_end)) + 16#3FF) &
                           (-16#400));
    keep2_low := linteger(integer32(addr(os_disk_data)) & (-16#400));
    keep2_high := linteger((integer32(addr(os_disk_data_end)) + 16#3FF) &
                           (-16#400));

    { seg and va; NETWORK_$REALLY_DISKLESS's
      address hoisted into a register (and STACK's, never read) }
    seg := 0;
    va := unwired_proc;
    repeat
%if pmmu_page_maps %then

      { TODO(pascal) one expression for pmap_seg

        Without the large address space the SAU8 image computes the
        segment as rshft(va, 15) - MST_$SEG_GLOBAL_B + MST_$GLOBAL_A_SIZE,
        the two words read from MST_WIRED; with it the SAU7 and SAU9
        images subtract 30464, which is those two constants' difference
        folded.  So the original is likely the one expression for both;
        dpc compiles the constants' form as a subtraction and an
        addition, so the large address space's arm keeps
        mst_$seg_global_b_offset. }
%if large_address_space %then
      pmap_seg := rshft(va, 15) - mst_$seg_global_b_offset;
%else
      pmap_seg := rshft(va, 15) - mst_$seg_global_b + mst_$global_a_size;
%endif
%endif
      { the segment's ASTE, A0 kept in A2 }
      aste := ast_$activate_aste_canned(network_$paging_file_uid, seg);
      warned := false;

      { its 32 pages }
      for i := 1 to 32 do begin
        vtop_va := va;
        vtop_ppn := vtop_or_crash(vtop_va);
        if va < linteger(addr(os_data_end)) then begin
          { the page in the segment, the PPN from the
            result; the two booleans true }
          ast_$pmap_assoc(aste, rshft(va & 16#7FFF, 10), vtop_ppn, true,
                          true, status);
          { the status loaded once into D1 for
            both tests }
          if status.all <> status_$ok then begin
            if status.all <> status_$pmap_bad_assoc then
              crash_system(status);
            if not warned then begin
              os_$print_init_error(
'%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%.');
              os_$print_init_error(
          'Unable to initialize DOMAIN_OS - The OS paging file is too small.%.');
              os_$print_init_error(
          'For information on how to correct this, see the Installation%.');
              os_$print_init_error(
                'Procedures chapter in the Release Document.%.');
              os_$print_init_error('Do you want to proceed? %$');
              if not prompt_for_yes_or_no then begin
                status.all := status_$ok;
                os_$shutdown(status);
              end;
              os_$print_init_error(
      'The OS will NOT page, which may cause some performance degradation%.');
              warned := true;
            end;
          end
          { a disked node keeps the disk's two
            ranges wired; the four compares a plain `and'/`or', the
            third's value spilled to a frame temporary; the unwire's PPN
            reloaded from the frame }
          else if network_$really_diskless or else
                  not ((va >= keep1_low) and (va < keep1_high) or
                       (va >= keep2_low) and (va < keep2_high)) then
            mmap_$unwire(vtop_ppn);
        end
        else
          { past the image's data; the pop shared
            with the unwire's }
          os_$free_va_page(va);
        va := va + 16#400;
      end;

      { the segment mapped from the file, read-only
        below the unwired data on a type-4 boot; the compare signed,
        where the other compares of va are unsigned, so both sides
        integer32 here; va - 16#8000 kept and pushed by the first call,
        recomputed by the second; the offset seg zero-extended and
        shifted; the two calls' tails merged }
      if is_type4 and then
         (integer32(va) - 16#8000 < integer32(unwired_data)) then
        mst_$map_canned_at(va - 16#8000, network_$paging_file_uid,
                           seg * 16#8000, 16#8000, 16#130001, true, true,
                           map_desc.all, status)
      else
        mst_$map_canned_at(va - 16#8000, network_$paging_file_uid,
                           seg * 16#8000, 16#8000, 16#170001, true, true,
                           map_desc.all, status);
      if status.all <> status_$ok then
        crash_system(status);
%if pmmu_page_maps %then
      { the segment's page descriptors in OS_PMAPS, not resident }
      for i := 0 to 31 do
        os_pmaps[pmap_seg - mst_$global_a_size][i].flags :=
          os_pmaps[pmap_seg - mst_$global_a_size][i].flags -
          [ast_$pmap_resident];
%endif
      seg := seg + 1;
    until warned or else (va >= paged_end);
%if not pft_mmu %then
    mmu_$purge;
%endif
  end;

  { a disked node's number against the one on the
    boot volume; the two values kept from the test and stored for VFMT;
    the test of NETWORK_$DISKLESS repeated after the prompt }
  if not network_$diskless then begin
    if (name_$node_uid.low & 16#FFFFF) <> node_$me then begin
      prom_node := node_$me;
      stored_node := name_$node_uid.low & 16#FFFFF;
%if crash_reboot %then
      { a server in normal mode does not ask: it shuts down and restarts;
        the two shutdowns' tails one }
%if large_vm %then
      server_reboot := mmu_$normal_mode and server_$flag;
%else
      server_reboot := mmu_$normal_mode;
%endif
      if not server_reboot then begin
        os_$print_init_error('%/The node number of this node differs %$');
        os_$print_init_error('from that stored on%.');
        vfmt_$write2('the boot volume.  Prom node #%h, stored node #%h.%.',
                     prom_node, stored_node);
        os_$print_init_error('Do you want to proceed? %$');
        if not prompt_for_yes_or_no then begin
          status.all := status_$ok;
          os_$shutdown(status);
        end;
      end
      else begin
        restart_code := os_$restart_code_reboot;
        status.all := status_$ok;
        os_$shutdown(status);
      end;
%else
      os_$print_init_error('%/The node number of this node differs %$');
      os_$print_init_error('from that stored on%.');
      vfmt_$write2('the boot volume.  Prom node #%h, stored node #%h.%.',
                   prom_node, stored_node);
      os_$print_init_error('Do you want to proceed? %$');
      if not prompt_for_yes_or_no then begin
        status.all := status_$ok;
        os_$shutdown(status);
      end;
%endif
    end;
    if not network_$diskless then
      volx_$rec_entry(vol_idx, name_$node_uid);
  end;

  { the working directory, the root; the path a
    constant cell ('/', padded with a blank), the length a pooled cell
    (1); no status test }
  name_$set_wdir('/', 1, status);

  { process 2's entry PC from PROC2_$INIT, then its
    stack }
  proc2_start.pc := proc2_$init(ws_mode, status);
  if status.all <> status_$ok then
    crash_system(status);
  proc2_start.usp := univ_ptr(as_$stack_high);

  { the hints; a diskless node keeps its network
    number across HINT_$INIT (D2) }
  if network_$diskless then begin
    saved_net := network_$me;
    hint_$init;
    if network_$me = 0 then begin
      network_$me := saved_net;
      hint_$add_net(saved_net);
    end;
  end
  else
    hint_$init;

  { a diskless node's time zone from its mother,
    the drift cleared, then its routing }
  if network_$diskless then begin
    network_$fetch_diskless_info(asknode_$req_timezone, diskless.mother_node);
    cal_$timezone.drift.high := 0;
    cal_$timezone.drift.low := 0;
    network_$fetch_diskless_info(asknode_$req_route_port, diskless.mother_node);
  end;

  log_$init;
%if prom_config_record %then
  io_$log_self_tests(cfg_ptr, status);
%endif
%if smd_display_memory %then
  smd_$cold_init;
%endif
%if gpu_driver %then
  { the color boards, then the graphics processor if its register page
    answers (the location an expression temporary) }
  case smd_$graphic_device_id of
    smd_gdev_color2, smd_gdev_color3:
      color2_$cold_init;
    otherwise
%if color_board %then
      color_$cold_init;
%endif
  end;
  if testpage(1, addr(gpu.reg_02), probe_result) then
    gpu_$cold_init;
%else
%if color_board %then
  color_$cold_init;
%endif
%endif
  xpd_$init;
  pchist_$init;
  network_$load;
  peb_$load_wcs;

  { the vector page read-only; page 0's address
    the zero longword }
%if pft_mmu %then
  mmu_$set_prot(vtop_or_crash(0), 16#13);
%elseif vector_seg_prot %then
  mmu_$set_seg_prot(addr(trap_page), 16#13);
%else
  mmu_$page_write_bit(addr(trap_page), 16#13);
%endif

%if display_driver %then
  { the display's type, unit 1 then 2 (constant
    cells); tested on the move's flags }
  disp_type := smd_$inq_disp_type(1);
  if disp_type = smd_$none then
    disp_type := smd_$inq_disp_type(2);
  mst_$diskless_init(disp_type = smd_$color_display, network_$mother_node,
                     node_$me);
%else
  { no display, so none in color }
  mst_$diskless_init(false, network_$mother_node, node_$me);
%endif

  { the last subsystems; then process 2, which
    does not return }
%if display_driver %then
  smd_$init_blink;
%endif
%if power_off_check %then
  os_$init_power_off_check;
%endif
  pacct_$init;
  audit_$init;
%if vector_alignment_check %then

  { every handler the table installed at a longword address }
  i := 1;
  while i <= os_init_vector_cells do begin
    for v := vectors[i].first_vector to
             vectors[i].first_vector + vectors[i].count - 1 do
      if (integer32(trap_page[v]) & 3) <> 0 then
        crash_system(status_$os_exception_handler_not_aligned);
    i := i + vectors[i].count + 1;
  end;
%endif
%if crash_reboot %then
  if not (15 in boot.flags) then
    crash_$ok_to_reboot := true;
%endif
  proc1_$inhibit_end;
  os_$start_proc2(proc2_start);
end;
