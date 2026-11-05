{ COLOR6_$IOINIT - find and set up the COLOR6 board's unit at boot.

  Image addresses:
    sau7  0x3C43E880  COLOR6_$IOINIT
    sau7  0x3C43E718  color6_probe (nested)

  - The first unit's call takes the register pages' and the display
    memory's addresses from its requests and checks that the CSR page
    is mapped at its bus address; later units' calls use them.
  - The unit is there when color6_probe finds the board answering at
    its page; then the driver gets it (SMD_$ADD_DEVICE), and the first
    unit's state gives the module its UIDs and special segment; a later
    unit marks the board shared.
  - Once the probe has found the board's configuration bits set, every
    later call finds no unit.

  Status stored (the result):
    status_$ok: the unit is there
    status_$io_controller_not_in_system: no board or no unit, or the CSR
      page mapped elsewhere
}

[section(os_init_proc, os_init_data)]
function color6_$ioinit(var dcte: color6_$dcte_t): integer32;
var
  page: static integer := -1;              { +0x0 }
  absent: static boolean := false;         { +0x2 }
  initialized: static boolean := false;    { +0x4 }
  info: color6_$info_ptr_t;
  csr: color6_$req_ptr_t;
  pa: integer32;
  status: status_$t;

  { color6_probe - look for the board at the unit's page.

    - The board's test register keeps a written value when the board
      is there.  Then the board's configuration bits are noted, and
      unless the board is busy it is given its setup command and the
      display memory is cleared.
    - The first unit found gives the page the board is left at; the
      board is set back to it after a later unit's probe.

    Status stored: none.
  }
  function color6_probe(var dcte: color6_$dcte_t;
                        cnum: integer): boolean;
    options(val_param);
  var
    saved: pinteger;
    present: boolean;
    regs: color6_$regs_ptr_t;
    hdm: color6_$hdm_ptr_t;
    fifo_l: color6_$fifo_long_ptr_t;
    row: integer;
    col: integer;
    restore: integer;
  begin
    color6_set_page(color6_regs, cnum);
    saved := color6_regs^.probe;
    color6_regs^.probe := color6_$probe_value;
    present := color6_regs^.probe = color6_$probe_value;
    color6_regs^.probe := saved;
    regs := color6_regs;
    if present then begin
      absent := (color6_swap16(regs^.board_id) & 16#30) = 16#30;
      if not color6_wait_ready(color6_regs) then begin
        hdm := dcte.hdm;
        with regs^ do begin
          fifo := color6_$cmd_setup;
          fifo := 12;
          fifo := 0;
          fifo := 0;
          fifo := 0;
          fifo := 0;
          fifo := hdm^.line_bits;
          fifo := hdm^.width;
          fifo := 8;
          fifo := 0;
          fifo_l := addr(fifo);
          fifo_l^ := 2048;
          fifo_l^ := color6_$memory_size;
        end;
        discard(color6_wait_ready(color6_regs));
        for row := 0 to hdm^.word_74 - 1 do
          for col := 0 to hdm^.line_bits div 16 - 1 do
            color6_$memory_ptr_t(color6_memory)^[row, col] := 0;
      end;
    end;
    if present and (page = -1) then
      page := cnum;
    restore := page;
    if (restore <> -1) and (restore <> cnum) then
      color6_set_page(color6_regs, restore);
    color6_probe := present;
  end;

begin
  color6_$ioinit := status_$io_controller_not_in_system;
  if absent then
    return;
  status.all := status_$ok;
  info := dcte.info;
  if not initialized then begin
    color6_memory := color6_$req_ptr_t(dcte.config)^.csr.va;
    csr := color6_$req_ptr_t(color6_$req_ptr_t(dcte.config)^.unused_00);
    color6_regs := color6_$regs_ptr_t(csr^.csr.va);
    pa := csr^.csr.pa;
    if (mmu_$vtop(integer32(color6_regs), status) * 1024 <> pa) or
       (status.all <> status_$ok) then
      return;
  end;
  if color6_probe(dcte, dcte.cnum) then begin
    info^.regs := color6_regs;
    info^.memory := color6_memory;
    smd_$add_device(1, addr(dcte));
    if initialized then
      color6_shared := true
    else begin
      color6_display_uid := info^.display_uid;
      color6_special_uid := info^.special_uid;
      color6_special_seg := info^.special_seg;
    end;
    color6_$ioinit := status_$ok;
    initialized := true;
  end;
end;
