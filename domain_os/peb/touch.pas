{ PEB_$TOUCH - give the board to the process that touched its page.

  Image addresses:
    sau2  0x00E70810  PEB_$TOUCH
    sau6  0x7807B658  PEB_$TOUCH
    sau7  0x3C4849BC  PEB_$TOUCH
    sau9  0x3C4770E0  PEB_$TOUCH

  - When the faulting address lies in the board's private register page
    (16#7000..16#73FF) and the board's pages are not installed, the
    result is true, and the board moves to the current address space.
  - The board is waited for first (10000 polls, then a crash: "fpu is
    hung").
  - The previous owner's registers are saved into its PEB_$REGS
    element, and the current address space's loaded.
  - Without `peb_board' (base/config.ins.pas) the result is always
    false.

  Status stored: none.
}

{ TODO(pascal) PEB_$TOUCH's frame

  The SAU2 frame has twenty bytes: regs is the only object addressed.
  i (the loop's count, held) and the three `with' temporaries
  (PEB_$INFO and the two elements, held) would take 2 + 12
  bytes, regs 4, and the boolean result variable (held) 2 more: 20 only
  if the result variable has no slot or one temporary is not counted.
  Not settled. }

function peb_$touch(in va: linteger): boolean;
%if peb_board %then
var
  i: integer;                             { the busy wait's count }
  regs: peb_$regs_ptr_t;
%endif
begin
  peb_$touch := false;
%if peb_board %then

  if (va >= 16#7000) and then (va < 16#7400)
     and then not peb_$info.mmu_installed then begin
    peb_$touch := true;

    { wait while the board is busy }
    if peb_ctl.ctl.all < 0 then begin
      for i := 1 to 10000 do
        if peb_ctl.ctl.all >= 0 then
          exit;
      if peb_ctl.ctl.all < 0 then
        crash_system(peb_fpu_is_hung_err);
    end;

    with peb_$info do begin
      regs := peb_$regs_ptr_t(16#7000);

      { the private page, and the old owner's registers saved }
      if owner_pid = 0 then
        mmu_$install_private(16#2D, univ_ptr(16#7000), proc1_$as_id, 6)
      else begin
        mmu_$install_private(16#2D, univ_ptr(16#7000), proc1_$as_id, 6);
        with peb_$regs[owner_asid] do begin
          data1 := regs^.data_in;
          data2 := regs^.stat_in;
          status_reg := regs^.status;
          ctrl_reg := regs^.misc;
          instr_counter := regs^.ctrl_out;
        end;
      end;

      { the current address space's registers }
      with peb_$regs[proc1_$as_id] do begin
        regs^.data_out := data1;
        regs^.stat_out := data2;
        regs^.status := status_reg;
        regs^.ctrl_in := ctrl_reg;
        regs^.ctrl_out := instr_counter;
      end;

      owner_pid := proc1_$current;
      owner_asid := proc1_$as_id;
    end;
  end;
%endif
end;
