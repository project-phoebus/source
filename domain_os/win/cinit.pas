{ WIN_$CINIT - the Winchester controller's initialization.

  Image addresses:
    sau2  0x00E30340  WIN_$CINIT
    sau5  0x00E31870  WIN_$CINIT

  - The controller is probed at the DCTE's register address (with the
    descriptor-list controller, a word write at +0x300); an answering one
    gets its unit record filled, its eventcount initialized and the
    driver registered (DISK_$REGISTER).

  Returns:
    status_$ok: the controller answered
    status_$io_controller_not_in_system: it did not

  Status stored: none.
}

%if win_descriptor_ctlr %then
[section(os_init_proc, os_init_data)]
function win_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  probe: univ_ptr;
begin
  status := status_$ok;

  { the unit record }
  win_units[dcte.cnum].dcte := addr(dcte);
  win_units[dcte.cnum].regs := dcte.disk_dinit;
  win_units[dcte.cnum].lock := dcte.disk_error_que_hi;
  win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [13];
  win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [11];
  ec_$init(win_unit_ec[dcte.cnum]);

  { the probe: the configuration word written to the window }
  win_config := win_config_word;
  probe := addr(win_units[dcte.cnum].regs^.config);
  if not testpage(3, probe, win_config) then
    status := status_$io_controller_not_in_system
  else
    discard(disk_$register(0, dcte.cnum, win_units[dcte.cnum].units,
                           win_units[dcte.cnum].lock, addr(win_jump_table)));

  win_$cinit := status;
end;
%else

[section(os_init_proc, os_init_data)]
function win_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  probe_data: array[1..6] of char;
begin
  status := status_$ok;

  { the probe }
  if not testpage(0, dcte.disk_dinit, probe_data) then
    status := status_$io_controller_not_in_system
  else begin
    { the unit record }
    win_units[0].dcte := addr(dcte);
    win_units[0].regs := dcte.disk_dinit;
    win_units[0].lock := dcte.disk_error_que_hi;
    win_units[0].unit_bits := win_units[0].unit_bits + [13];
    win_units[0].unit_bits := win_units[0].unit_bits + [11];

    ec_$init(win_unit_ec[dcte.cnum]);

    { the registration }
    discard(disk_$register(0, 0, win_units[0].units, win_units[0].lock,
                           addr(win_jump_table)));
  end;

  win_$cinit := status;
end;
%endif
