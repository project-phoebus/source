{ PBU_$ACQUIRE_INT - set up a PBU unit for a kernel driver.

  Image addresses:
    sau3  0x00E588B2  PBU_$ACQUIRE_INT
    sau5  0x00E588B2  PBU_$ACQUIRE_INT
    sau8  0x03C613D6  PBU_$ACQUIRE_INT

  - The kernel drivers' PBU_$SETUP: a DDF for the one unit (the wide I/O
    map but on the AT bus, a kernel handler, any address, not global)
    with the CSR pages and the handler as given; on success sharing goes
    into the unit's DCTE.

  Status stored:
    pbu_$setup's status: the unit was set up, or not
}

procedure pbu_$acquire_int(unit: integer; handler: univ_ptr;
                           handler_arg: univ_ptr; csr_va: univ_ptr;
                           csr_pa: integer32; csr_pages: integer;
                           sharing: integer; out status: status_$t);
  options(val_param);
var
  ddf_p: pbu_$ddf_ptr_t;
  dcte_status: status_$t;
  ddf: pbu_$ddf_t;
  i: integer;
begin
  for i := 0 to pbu_ddf_last_handler do
    ddf.handlers[i] := univ_ptr(pbu_no_handler);
  ddf.flags.version := pbu_ddf_version;
  ddf.unit := unit;
%if pbu_atbus_units %then
  ddf.flags.wide_iomap := false;
%else
  ddf.flags.wide_iomap := true;
%endif
  ddf.flags.kernel_driver := true;
  ddf.flags.any_address := true;
  ddf.flags.global := false;
  ddf.csr_va := linteger(csr_va);
  ddf.csr_pa := csr_pa;
  ddf.csr_pages := csr_pages;
  ddf.handlers[unit] := handler;
  ddf.handler_arg := handler_arg;
  ddf_p := addr(ddf);
  pbu_$setup(pbu_lib_version, ddf_p, status);
  if status.all = status_$ok then
    pbu_check_unit(unit, dcte_status)^.sharing := sharing;
end;
