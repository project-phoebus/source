{ WIN_$CINIT - the Winchester controller's initialization.

  Image addresses:
    sau2  0x00E30340  WIN_$CINIT
    sau4  0x0F8338BC  WIN_$CINIT
    sau5  0x00E31870  WIN_$CINIT
    sau6  0x78038CA8  WIN_$CINIT
    sau7  0x3C438E08  WIN_$CINIT
    sau8  0x03C332B0  WIN_$CINIT

  - The controller is probed at the DCTE's register address (with the
    descriptor-list controller, a word write at +0x300); an answering one
    gets its unit record filled, its eventcount initialized and the
    driver registered (DISK_$REGISTER).
  - The AT bus form maps the controller's ports, waits for its answer to
    the select port, acquires its interrupt for WIN8_$INT and enables
    it, and sends it a command block of its own before the
    registration.
  - The ring/disk form fills the unit record before the probe; an
    answering controller gets WIN_$INT on twelve of the board's sixteen
    vectors from the DCTE's first (+0x3E), its DMA controller cleared,
    the SMD interface probed (smd_interface), the I/O map entries'
    pointers set, and the registration.

  Returns:
    status_$ok: the controller answered
    status_$io_controller_not_in_system: it did not
    IO_$ACQUIRE's status: the AT bus form's interrupt not acquired

  Status stored: none.
}

%if win_descriptor_ctlr %then
[section(os_init_proc, os_init_data)]
function win_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  probe: univ_ptr;
%if win_vectored_ctlr %then
  id: io_$int_id_t;
%endif
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
%if win_vectored_ctlr %then
  else begin
    id.vector := dcte.disk_error_que_lo;
    sysbus_$define_int(id, addr(win_$int), addr(dcte));
    discard(disk_$register(0, dcte.cnum, win_units[dcte.cnum].units,
                           win_units[dcte.cnum].lock, addr(win_jump_table)));
  end;
%else
  else
    discard(disk_$register(0, dcte.cnum, win_units[dcte.cnum].units,
                           win_units[dcte.cnum].lock, addr(win_jump_table)));
%endif

  win_$cinit := status;
end;
%elseif win_atbus_ctlr %then
[section(os_init_proc, os_init_data)]
function win_$cinit(var dcte: win_$dcte_t): integer32;
var
  result: integer32;
  dcte_addr: univ_ptr;
  found: boolean;
  regs: win_$regs_ptr_t;
  status: status_$t;
  i: integer32;
  unit: io_$unit_num_t;
  stat: integer;
begin
  result := status_$ok;
  dcte_addr := addr(dcte);
  found := false;

  { the unit record, the ports }
  win_units[dcte.cnum].regs := win_$regs_ptr_t(dcte.req.csr.va);
  win_units[dcte.cnum].dcte := addr(dcte);
  io_$map_csr(dcte.req, status);

  { the probe: the controller answers the select port }
  regs := win_units[dcte.cnum].regs;
  if (regs^.select <> 16#0E) and (regs^.status = 16#C0) then begin
    regs^.select := 0;
    for i := 1 to 5000000 do
      if regs^.status = 16#CD then begin
        found := true;
        exit;
      end;
  end;
  if not found then begin
    io_$unmap_csr(dcte.req, status);
    result := status_$io_controller_not_in_system;
  end
  else begin
    { the interrupt }
    io_$acquire(dcte.req, addr(win8_$int), dcte_addr, unit, status);
    if status.all <> status_$ok then begin
      result := status.all;
      io_$unmap_csr(dcte.req, status);
    end
    else begin
      io_$enable_device(unit, status);

      { the controller's first command block, and its completion }
      regs^.data := 1;
      regs^.data := 0;
      regs^.data := 0;
      regs^.data := 0;
      regs^.data := 0;
      regs^.data := 1;
      for i := 1 to 5000000 do
        if (regs^.status & win_status_completion) =
           win_status_completion then begin
          stat := regs^.data;
          exit;
        end;

      { the registration }
      discard(disk_$register(0, dcte.cnum, win_unit_bits, dcte.lock,
                             addr(win_jump_table)));
      ec_$init(win_unit_ec[dcte.cnum]);
    end;
  end;

  win_$cinit := result;
end;
%elseif win_ring_disk_ctlr %then
[section(os_init_proc, os_init_data)]
function win_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  probe_data: array[1..6] of char;
  regs: win_$regs_ptr_t;
  id: io_$int_id_t;
  i: integer;
begin
  status := status_$ok;

  { the unit record }
  win_units[dcte.cnum].dcte := addr(dcte);
  win_units[dcte.cnum].regs := dcte.disk_dinit;
  win_units[dcte.cnum].lock := dcte.disk_error_que_hi;

  { the probe }
  if not testpage(0, win_units[dcte.cnum].regs, probe_data) then
    status := status_$io_controller_not_in_system
  else begin
    { the board's disk vectors: the first 9, the 11th, the 13th, the
      15th }
    for i := 0 to 8 do begin
      id.vector := dcte.disk_error_que_lo + i;
      sysbus_$define_int(id, addr(win_$int), addr(dcte));
    end;
    id.vector := dcte.disk_error_que_lo + 10;
    sysbus_$define_int(id, addr(win_$int), addr(dcte));
    id.vector := dcte.disk_error_que_lo + 12;
    sysbus_$define_int(id, addr(win_$int), addr(dcte));
    id.vector := dcte.disk_error_que_lo + 14;
    sysbus_$define_int(id, addr(win_$int), addr(dcte));
    ec_$init(win_unit_ec[dcte.cnum]);

    { the DMA controller's reset, and the SMD interface's probe }
    regs := win_units[dcte.cnum].regs;
    regs^.dma_master_clear := 0;
    regs^.dma_command := 16#60;
    regs^.select := 16#FE;
    regs^.cmd := 16#10;
    win_units[dcte.cnum].flags.smd_interface := regs^.cmd <> 255;

    { the I/O map entries of the two pages }
    win_hdr_iomap := addr(iomap[win_iomap_first]);
    win_data_iomap := addr(iomap[win_iomap_first + 1]);

    { the registration }
    win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [13];
    win_units[dcte.cnum].unit_bits := win_units[dcte.cnum].unit_bits + [11];
    discard(disk_$register(0, dcte.cnum, win_units[dcte.cnum].units,
                           win_units[dcte.cnum].lock, addr(win_jump_table)));
  end;

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
