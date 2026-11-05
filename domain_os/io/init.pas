{ IO_$INIT - initialize the I/O manager and every controller.

  Image addresses:
    sau2  0x00E328E0  IO_$INIT
    sau3  0x00E310B0  IO_$INIT
    sau4  0x0F835A48  IO_$INIT
    sau5  0x00E34890  IO_$INIT
    sau6  0x7803BD60  IO_$INIT
    sau7  0x3C43BDA8  IO_$INIT
    sau8  0x03C3629C  IO_$INIT
    sau9  0x3C439088  IO_$INIT

  - The two exclusion locks, the DMA controller (`dma_driver') and the
    region nodes (`io_regions') are initialized, the DCTE list built,
    and each bus's and the PBU's (`pbu_driver') initialization run.
  - Each good DCTE: a kind-1 controller's I/O address translated to
    physical (a failure crashes the system), its initialization routine
    run; with verbose, each named controller announced.
  - With the PROM's configuration record (`prom_config_record', param1
    its address; none: status_$io_boot_device_not_found) the DCTEs of
    the boot device, the console and its line are marked; a controller
    whose self-test failed is failed (status_$io_device_failed_self_test)
    before its initialization; a tape boot takes the first controller of
    type 0; a boot device that fails is not found.

  Status stored:
    status_$ok: always (with `prom_config_record': the boot device was
      found)
    status_$io_boot_device_not_found: no configuration record, or no
      boot device (`prom_config_record')
}

{ TODO(pascal) 16 frame bytes unexplained (stand-ins unused_18, unused_1c)

  The SAU2 frame is 28 bytes: i, ppn and d account for 12 (with ppn's
  longword alignment); a pointer to the bus vector's element would add
  4.  The stand-ins unused_18 (12 bytes) and unused_1c (a longword) hold
  the 16 left: the bytes do not start at a multiple of 8 from A6, where
  one 16-byte object would be placed, so the original's objects there
  were smaller. }

[section(os_init_proc, os_init_data)]
procedure io_$init(in param1: integer32; in verbose: boolean;
                   out status: status_$t);
%if prom_config_record %then
var
  cfg: os_$prom_config_ptr_t;
  is_tape: boolean;
  found: boolean;
  d: dcte_ptr_t;
  i: integer;
  k: integer32;
  ppn: integer32;
begin
  cfg := os_$prom_config_ptr_t(param1);
  if cfg = nil then begin
    status.all := status_$io_boot_device_not_found;
    return;
  end;
  is_tape := cfg^.boot_dev.kind = os_$prom_boot_tape;
  status.all := status_$ok;
  io_$in_init := true;
  ml_$exclusion_init(io_$exclusion);
  ml_$exclusion_init(io_$wiring_exclusion);
  io_$build_dcte_list;

  { the boot device, the console and the console's line }
  found := false;
  d := io_$dcte_list;
  if d <> nil then
    repeat
      if not is_tape and then not found
         and then io_$match_device(d^.reserved_1c, cfg^.boot_dev) then begin
        os_$boot_device.device := d^.ctype;
        os_$boot_device.reserved := d^.cnum;
        os_$boot_device.ctlr := cfg^.boot_dev.ctlr;
        found := true;
        d^.config_flags := d^.config_flags + [io_$dcte_boot_device];
        discard(net_io_$boot_device(d^.ctype, d^.cnum));
      end;
      if io_$match_device(d^.reserved_1c, cfg^.console_dev) then
        d^.config_flags := d^.config_flags + [io_$dcte_console];
      if io_$match_device(d^.reserved_1c, cfg^.line_dev) then
        d^.config_flags := d^.config_flags + [io_$dcte_crash_line];
      d := d^.nextp;
    until d = nil;

  { the network boot device: d is nil here, so the walk never runs }
  if d <> nil then
    repeat
      if io_$match_device(d^.reserved_1c, cfg^.net_dev) then begin
        discard(net_io_$boot_device(d^.ctype, d^.cnum));
        d^.config_flags := d^.config_flags + [io_$dcte_net_boot_device];
        exit;
      end;
      d := d^.nextp;
    until d = nil;

  { the buses }
  for i := 0 to 4 do
    if io_$bus_epv[i].init <> nil then
      io_$bus_epv[i].init^;

  { the controllers }
  d := io_$dcte_list;
  if d <> nil then
    repeat
      if verbose and then (d^.name[1] <> chr(0)) then
        vfmt_$write2('Device: %m8a: %$', d^.name, 0);

      { a failed self-test fails the controller }
      if (cfg <> nil) and then (cfg^.self_tests <> nil) then begin
        k := 1;
        repeat
          if not cfg^.self_tests^[k].device.valid then
            exit;
          if cfg^.self_tests^[k].device.failed
             and then io_$match_device(cfg^.self_tests^[k].device,
                                       d^.reserved_1c) then begin
            d^.cstatus.all := status_$io_device_failed_self_test;
            if verbose and then (d^.name[1] <> chr(0)) then
              vfmt_$write2('failed selftest%.', 0, 0);
            exit;
          end;
          k := k + 1;
        until false;
      end;

      { a tape boot takes the first controller of type 0 }
      if is_tape and then not found and then (d^.ctype = 0) then begin
        d^.config_flags := d^.config_flags + [io_$dcte_boot_device];
        os_$boot_device.device := d^.ctype;
        os_$boot_device.reserved := d^.cnum;
        os_$boot_device.ctlr := 0;
        found := true;
      end;

      if d^.cstatus.all = status_$ok then begin
        if d^.kind = 1 then begin
          if d^.io_va <> 0 then
            ppn := mmu_$vtop(d^.io_va, d^.cstatus);
          if d^.cstatus.all <> status_$ok then
            crash_system(d^.cstatus);
          d^.io_pa := lshft(ppn, 10) + (d^.io_va & 16#3FF);
        end;
        if d^.cstatus.all = status_$ok then begin
          if d^.csrsytr <> nil then
            d^.cstatus.all := d^.csrsytr^(d^)
          else
            d^.cstatus.all := status_$ok;
          if verbose and then (d^.name[1] <> chr(0)) then
            if d^.cstatus.all <> status_$ok then
              vfmt_$write2('init failed: status %8zh%.', d^.cstatus, 0)
            else
              vfmt_$write2('OK%.', 0, 0);
        end;
      end;

      { a boot device that failed is not the boot device }
      if (d^.cstatus.all <> status_$ok)
         and then (io_$dcte_boot_device in d^.config_flags) then
        found := false;
      d := d^.nextp;
    until d = nil;

  if not found then
    status.all := status_$io_boot_device_not_found
  else
    io_$in_init := false;
end;
%else
var
  i: integer;                             { the loop count }
  ppn: integer32;
  d: dcte_ptr_t;
  unused_18: array[1..6] of integer;      { the stand-in (TODO) }
  unused_1c: integer32;
%if io_regions %then
  r: io_$region_ptr_t;                    { the free list as it is built }
%endif
begin
  status.all := status_$ok;
  io_$in_init := true;
  ml_$exclusion_init(io_$exclusion);
  ml_$exclusion_init(io_$wiring_exclusion);
%if dma_driver %then
  dma_$init;
%endif
%if io_regions %then

  { the region nodes' free list }
  r := nil;
  for i := 1 to io_$region_count do begin
    io_$region_nodes[i].next := r;
    r := addr(io_$region_nodes[i]);
  end;
  io_$region_free := r;
%endif
  io_$build_dcte_list;

  { the buses }
  for i := 0 to 4 do
    if io_$bus_epv[i].init <> nil then
      io_$bus_epv[i].init^;
%if pbu_driver %then
  pbu_$init(true);
%endif

  { the controllers }
  d := io_$dcte_list;
  if d <> nil then
    repeat
      if verbose and then (d^.name[1] <> chr(0)) then
        vfmt_$write2('Device: %m8a: %$', d^.name, 0);
      if d^.cstatus.all = status_$ok then begin
        if d^.kind = 1 then begin
          if d^.io_va <> 0 then
            ppn := mmu_$vtop(d^.io_va, d^.cstatus);
          if d^.cstatus.all <> status_$ok then
            crash_system(d^.cstatus);
          d^.io_pa := lshft(ppn, 10) + (d^.io_va & 16#3FF);
        end;
        if d^.cstatus.all = status_$ok then begin
          if d^.csrsytr <> nil then
            d^.cstatus.all := d^.csrsytr^(d^)
          else
            d^.cstatus.all := status_$ok;
          if verbose and then (d^.name[1] <> chr(0)) then
            if d^.cstatus.all <> status_$ok then
              vfmt_$write2('init failed: status %8zh%.', d^.cstatus, 0)
            else
              vfmt_$write2('OK%.', 0, 0);
        end;
      end;
      d := d^.nextp;
    until d = nil;

%if mt_driver %then
  io_$config_flag := mt_$present;
%endif
  io_$in_init := false;
end;
%endif
