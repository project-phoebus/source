{ PEB_$LOAD_WCS - set up the floating-point save area or load the
  board's microcode.

  Image addresses:
    sau2  0x00E31FD8  PEB_$LOAD_WCS
    sau2  0x00E31EC8  peb_$load_wcs_check_err (nested)
    sau5  0x00E33530  PEB_$LOAD_WCS
    sau5  0x00E33420  peb_$load_wcs_check_err (nested)
    sau6  0x7803AC38  PEB_$LOAD_WCS
    sau6  0x7803AB2C  peb_$load_wcs_check_err (nested)
    sau7  0x3C43AAFC  PEB_$LOAD_WCS
    sau7  0x3C43A9C0  peb_$load_wcs_check_err (nested)
    sau7  0x3C43AA74  peb_$load_wcs_check_fpa_err (nested)
    sau9  0x3C437EE8  PEB_$LOAD_WCS
    sau9  0x3C437E32  peb_$load_wcs_check_err (nested)

  - With an MC68881 or a pending save area, a file is created, locked
    and 18810 bytes of it mapped as the FP save area.
  - Otherwise, with the board installed, /sys/peb2_microcode is mapped
    and written into the WCS, each entry read back (a mismatch crashes
    the system).
  - After each step the nested check prints a warning and ends the
    routine when the step failed.
  - Without `peb_board' (base/config.ins.pas) only the save area's arm;
    with `peb_fpx' the check disables an FPX's save area as it does the
    68881's.
  - With `fpa_board' the floating-point accelerator comes first: a
    version other than the one supported disables it; then its 8892-byte
    save area is mapped as the 68881's is (FPA_$SAVEP), its own nested
    check disabling it on a failed step.

  Status stored: none.
}

{ TODO(pascal) the 19-step page loop of the save-area arm

  The SAU2 image takes a pointer from FP_$SAVEP and steps it by 1024
  nineteen times, its value never used and nothing read or written
  through it (19 pages of 1024 bytes cover the 18810 mapped).
  Written here as a page-pair pointer stepped with
  `addr(save_area^[1])', which gives the step; the source may have
  touched each page (a load the compiler dropped as dead, its induction
  pointer kept) or stepped an integer address.  Without `peb_board' the
  SAU9 frame has room for one local of up to 4 bytes below status (32
  bytes: file_uid, header, maps_length, lock_info, map_info, status and
  that one), 4 bytes less than this source gives: there the loop has one
  local, not an index and a pointer.  The SAU7's frame (36 bytes, its
  csr at -12 in header's place) is short by the same 4 bytes, and its
  accelerator arm has the same loop, 9 steps for the 8892 bytes.  Not
  settled.

  TODO(pascal) the SAU7's version test: the image extracts the FPCSR's
  version field from csr into D1, after storing the function's result
  from D0; dpc extracts it into D0. }

[section(os_init_proc, os_init_data)]
procedure peb_$load_wcs;
const
  peb_microcode_path = '/sys/peb2_microcode';
type
  save_page_t = array[1..1024] of char;
  save_pages_ptr_t = ^array[0..1] of save_page_t;
var
%if peb_board %then
  wired_pages: array[0..9] of integer32;
  verify: peb_$wcs_entry_t;
%endif
  file_uid: uid_$t;
%if fpa_board %then
  csr: fpa_$csr_t;
%endif
  header: peb_$wcs_header_ptr_t;
  maps_length: integer32;
%if peb_board %then
  map_va: integer32;
%endif
  lock_info: integer32;
  map_info: integer32;
  status: status_$t;
%if peb_board %then
  ctl: peb_$ctl_bits_t;
  wire_count1: integer;
  wire_count2: integer;
  ctl_page_byte: char;
%endif
  i: integer;
  save_area: save_pages_ptr_t;

  { peb_$load_wcs_check_err: warn of a failed step, nested. }
  function peb_$load_wcs_check_err(in msg: univ vfmt_$string_t): boolean;
  begin
    if status.code <> 0 then begin
      { the warning }
      vfmt_$write2('%/%/%/Warning: Unable to %$', 0, 0);
      vfmt_$write2(msg, 0, 0);

      if peb_$info.m68881_save_flag then begin
        { no 68881 save area }
        peb_$info.m68881_save_flag := false;
        vfmt_$write2(' 68881 savearea -- 68881 is disabled.%.', 0, 0);
        fp_$savep := nil;
        trap_page[11] := addr(fim_$uii);
      end
%if peb_fpx %then
      else if peb_$info.savep_flag then begin
        { no FPX save area }
        peb_$info.savep_flag := false;
        vfmt_$write2(' FPA savearea -- FPA is disabled.%.', 0, 0);
        fp_$savep := nil;
        trap_page[11] := addr(fim_$uii);
      end
%endif
%if peb_board %then
      else
        vfmt_$write5(' "%a" -- %lh%/PEB is disabled.%.',
                     peb_microcode_path, 19, status, 0, 0)
%endif
      ;

      peb_$load_wcs_check_err := true;
    end
    else
      peb_$load_wcs_check_err := false;
  end;

%if fpa_board %then
  { peb_$load_wcs_check_fpa_err: warn of a failed step of the
    accelerator's save area, nested. }
  function peb_$load_wcs_check_fpa_err(in msg: univ vfmt_$string_t): boolean;
  begin
    if status.code <> 0 then begin
      { the warning }
      vfmt_$write2('%/%/%/Warning: Unable to %$', 0, 0);
      vfmt_$write2(msg, 0, 0);

      if peb_$info.flag_1d then begin
        { no accelerator save area }
        peb_$info.flag_1d := false;
        vfmt_$write2(' FPA savearea -- FPA is disabled.%.', 0, 0);
        fpa_$savep := nil;
      end;

      peb_$load_wcs_check_fpa_err := true;
    end
    else
      peb_$load_wcs_check_fpa_err := false;
  end;
%endif

begin
%if fpa_board %then
  if peb_$info.flag_1d then begin
    { the accelerator's version }
    csr := fim_$fp_get_fpcsr;
    if csr.version <> fpa_$version_supported then begin
      vfmt_$write2('%/Warning: FPA version not supported by this operating system revision.%.', 0, 0);
      vfmt_$write2('FPA is disabled.%.', 0, 0);
      peb_$info.flag_1d := false;
    end;

    if peb_$info.flag_1d then begin
      { the accelerator's save area's file }
      file_$create(uid_$nil, file_uid, status);
      if peb_$load_wcs_check_fpa_err('create file for fpa save area%$') then
        return;

      file_$lock(file_uid, 0, 4, false, lock_info, status);
      if peb_$load_wcs_check_fpa_err('lock file for%$') then
        return;

      { the area }
      maps_length := 8892;
      fpa_$savep := mst_$maps(0, true, file_uid, 0, maps_length, 16#16, 0,
                              true, map_info, status);
      if peb_$load_wcs_check_fpa_err('map file for%$') then
        return;

      { see the TODO(pascal) above }
      save_area := fpa_$savep;
      for i := 1 to 9 do
        save_area := addr(save_area^[1]);
    end;
  end;

%endif
  if peb_$info.m68881_save_flag or else peb_$info.savep_flag then begin
    { the FP save area's file }
    file_$create(uid_$nil, file_uid, status);
    if peb_$load_wcs_check_err('create file for%$') then
      return;

    file_$lock(file_uid, 0, 4, false, lock_info, status);
    if peb_$load_wcs_check_err('lock file for%$') then
      return;

    { the area }
    maps_length := 18810;
    fp_$savep := mst_$maps(0, true, file_uid, 0, maps_length, 16#16, 0,
                           true, map_info, status);
    if peb_$load_wcs_check_err('map file for%$') then
      return;

    { see the TODO(pascal) above }
    save_area := fp_$savep;
    for i := 1 to 19 do
      save_area := addr(save_area^[1]);
  end
%if peb_board %then
  else if peb_$info.installed then begin
    { the microcode's file }
    name_$resolve(peb_microcode_path, 19, file_uid, status);
    if peb_$load_wcs_check_err('resolve%$') then
      return;

    file_$lock(file_uid, 0, 1, false, lock_info, status);
    if peb_$load_wcs_check_err('lock%$') then
      return;

    header := mst_$map(file_uid, 0, 16#10000, 6, 0, false, map_info,
                       status);
    if peb_$load_wcs_check_err('map%$') then
      return;

    { write every entry }
    for i := 0 to header^.entry_count - 1 do
      peb_$write_wcs(i + header^.start_addr, header^.entries[i]);

    { read each one back }
    for i := 0 to header^.entry_count - 1 do begin
      peb_$read_wcs(i + header^.start_addr, verify);
      if verify <> header^.entries[i] then
        crash_system(status_$peb_wcs_verify_failed);
    end;

    map_va := integer32(header);
    mst_$unmap(file_uid, map_va, map_info, status);
    if peb_$load_wcs_check_err('unmap%$') then
      return;

    discard(file_$unlock(file_uid, 1, status));
    if peb_$load_wcs_check_err('unlock%$') then
      return;

    { wire the board's code, then its data }
    mst_$wire_area(addr(peb_$wired_proc_start), addr(peb_$wired_proc_end),
                   wired_pages, 10, wire_count1);
    mst_$wire_area(addr(peb_$wired_data_start), addr(peb_$wired_data_end),
                   wired_pages[wire_count1], 10 - wire_count1,
                   wire_count2);

    { enable the board }
    ctl := peb_$info.ctl_shadow;
    ctl.all := ctl.all ! 16#D;
    peb_$info.ctl_shadow := ctl;
    ctl_page_byte := peb_ctl.reg_3fc;
    peb_ctl.ctl := ctl;
    peb_$info.wcs_loaded := true;
  end
%endif
  ;
end;
