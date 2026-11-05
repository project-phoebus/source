{ WIN6_$CINIT - the second board's controller's initialization.

  Image addresses:
    sau6  0x78038D88  WIN6_$CINIT

  - The board is looked for at the DCTE's address and three more 32 KB
    apart (TESTPAGE); where found the DCTE takes that address, and its
    vector four more for each step.
  - The three interrupts (completion, controller, asynchronous) on the
    vector and the two after the next; the unit record, WIN_$DT, the
    drives' records, the controller's initialization (400001 polls of
    its status for the start and the end of it), the free list of all
    the command blocks, the error log cleared; DISK_$REGISTER with
    WIN6_'s jump table.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function win6_$cinit(var dcte: dcte_t): integer32;
label
  10, 20;
var
  status: integer32;
  st: integer32;
  i: integer;
  probe: char;
  id: io_$int_id_t;
  k: integer32;
  started: boolean;
  e: integer;
  w: integer;
begin
  status := status_$io_controller_not_in_system;

  { the board: at the DCTE's address or one of three after it }
  win6_page := dcte.disk_dinit;
  for i := 0 to 3 do
    if not testpage(0, win6_page, probe) then
      win6_page := win6_$page_ptr_t(integer32(win6_page) + 16#8000)
    else begin
      dcte.disk_dinit := win6_page;
      dcte.disk_error_que_lo := dcte.disk_error_que_lo + i * 4;
      status := status_$ok;
      exit;
    end;
  if status <> status_$ok then begin
    st := status;
    goto 20;
  end;

  { the interrupts }
  id.vector := dcte.disk_error_que_lo;
  sysbus_$define_int(id, addr(win6_$int), addr(dcte));
  id.vector := dcte.disk_error_que_lo + 2;
  sysbus_$define_int(id, addr(win6_$ctlr_int), addr(dcte));
  id.vector := dcte.disk_error_que_lo + 3;
  sysbus_$define_int(id, addr(win6_$async_int), addr(dcte));

  { the unit record and the blocks' addresses }
  win_units[dcte.cnum].regs := dcte.disk_dinit;
  win_units[dcte.cnum].lock := dcte.disk_error_que_hi;
  win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [13];
  win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [11];
  win_$dt.iopbs := integer32(win6_page) + 16#6000;
  win_$dt.iopbs_bus := integer32(win6_page) - 16#7FE4A000;
  win6_page := dcte.disk_dinit;

  { the drives' records }
  for i := 0 to 1 do
    with win6_drives[i] do begin
      ec_$init(ec);
      int_seen := false;
      int_time := 0;
      for e := 1 to 64 do
        failed[e] := nil;
    end;

  { the controller's initialization }
  started := false;
  win6_page^.init_go := 1;
  for k := 0 to 400000 do begin
    if started then
      case win6_page^.init_status of
        win6_init_ok, win6_init_ok_2: begin
          goto 10;
        end;
      end;
    case win6_page^.init_status of
      win6_init_ok, win6_init_ok_2: { empty };
      otherwise begin
        started := true;
      end;
    end;
  end;
  st := status_$io_controller_not_in_system;
  goto 20;

10:
  st := status_$ok;
  with win6_page^ do begin
    init_b5 := 0;
    init_b6 := 3;
    init_b7 := 3;
    init_ba := 16#90;
    init_bb := 3;
    if init_status = 0 then
      win6_init_mode := 2
    else
      win6_init_mode := 0;
  end;

  { every command block in the free list }
  win6_free_count := win6_last_iopb + 1;
  win6_free_head := 0;
  win6_free_tail := win6_last_iopb;
  for i := 0 to win6_last_iopb do
    with win6_page^.iopbs[i] do begin
      link := (i + 1) * win6_iopb_size;
      state := 0;
      w_0c := 0;
    end;
  win6_page^.iopbs[win6_last_iopb].link := win6_end_of_chain;

  { the error log }
  for e := 1 to win6_epbs_size do
    for w := 1 to 8 do
      win6_$epbs[e].l[w] := 0;

  discard(disk_$register(0, dcte.cnum, win_units[dcte.cnum].units,
                         win_units[dcte.cnum].lock, addr(win6_jump_table)));
20:
  win6_$cinit := st;
end;
