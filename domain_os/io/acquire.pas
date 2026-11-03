{ IO_$ACQUIRE - acquire a unit for a device: a free slot of the unit
  table, checked against the units already acquired on the same bus.

  Image addresses:
    sau2  0x00E1A528  IO_$ACQUIRE
    sau2  0x00E1A4DC  int_ids_match (nested)
    sau3  0x00E195C0  IO_$ACQUIRE
    sau3  0x00E19574  int_ids_match (nested)
    sau4  0x0F81B190  IO_$ACQUIRE
    sau4  0x0F81B144  int_ids_match (nested)
    sau5  0x00E1A870  IO_$ACQUIRE
    sau5  0x00E1A824  int_ids_match (nested)
    sau8  0x03C1B6AC  IO_$ACQUIRE
    sau8  0x03C1B660  int_ids_match (nested)

  - Under io_$exclusion, the first free slot of IO_$DCTES; the request
    must not share an interrupt id or a CSR page with an acquired unit
    of its bus.
  - The interrupt is defined with the bus (when the request has one) and
    the slot filled, the acquiring process with it.  An id the nested
    int_ids_match cannot compare crashes the system.

  Status stored:
    status_$ok: the unit was acquired
    status_$io_unit_table_full: no free slot
    status_$io_illegal_csr_address: the CSR address fits not the bus's
      alignment
    status_$io_int_id_in_use: an acquired unit has the interrupt id
    status_$io_csr_page_in_use: the CSR address is in a unit's pages
}

{ TODO(pascal) frame of IO_$ACQUIRE not accounted for

  The SAU2 frame is 20 bytes: align (4), i (2), int_both and csr_both (1
  each) and the two `with' temporaries of array elements (4 each, item
  4) give 16.  Which 4 bytes are missing (a third `with', a wider i, the
  original's other locals) the image does not show; nothing addresses
  the frame.  No stand-in: the rest of the module's frames are dpc's
  best effort too. }

procedure io_$acquire(in req: io_$acquire_rec_t; handler: univ_ptr;
                      handler_arg: univ_ptr; out unit: io_$unit_num_t;
                      out status: status_$t);
  options(val_param);
label
  done;
var
  align: integer32;
  i: integer;                             { the loop count }
  int_both: boolean;
  csr_both: boolean;

  { Whether two interrupt ids are the same on the request's bus; a bus
    without interrupt ids crashes the system. }
  function int_ids_match(id1: io_$int_id_t; id2: io_$int_id_t): boolean;
    options(val_param);
  begin
    case req.bus of
      io_$bus_vme, io_$bus_mbus, io_$bus_atbus, io_$bus_sysbus:
        int_ids_match := id1.vector = id2.vector;
      otherwise
        crash_system(status_$io_int_id_not_implemented);
    end;
  end;

begin
  ml_$exclusion_start(io_$exclusion);
  status.all := status_$io_unit_table_full;

  { the first free slot }
  for unit := 0 to io_$max_unit do
    if io_$dctes[unit].tag = 0 then begin
      status.all := status_$ok;
      exit;
    end;
  if status.all <> status_$ok then
    goto done;

  { the CSR address's alignment }
  align := io_$bus_epv[req.bus].csr_align;
  if req.csr.has_csr and then (((align - 1) & req.csr.pa) <> 0) then begin
    status.all := status_$io_illegal_csr_address;
    goto done;
  end;

  { the units acquired on the same bus }
  for i := 0 to io_$max_unit do
    with io_$dctes[i] do
      if (tag <> 0) and then (bus = req.bus) then begin
        int_both := req.int.has_int and int.has_int;
        csr_both := req.csr.has_csr and csr.has_csr;
        if int_both and then int_ids_match(req.int.id, int.id) then
          status.all := status_$io_int_id_in_use
        else if csr_both and then (req.csr.pa >= csr.pa)
                and then (csr.pa + csr.pages > req.csr.pa) then
          status.all := status_$io_csr_page_in_use;
        if status.all <> status_$ok then
          goto done;
      end;

  if req.int.has_int then
    io_$bus_epv[req.bus].define_int^(req.int.id, handler, handler_arg);

  with io_$dctes[unit] do begin
    tag := req.tag;
    owner := proc1_$current;
    bus := req.bus;
    int := req.int;
    csr := req.csr;
    attrs := req.attrs;
    regions := nil;
  end;

done:
  ml_$exclusion_stop(io_$exclusion);
end;
