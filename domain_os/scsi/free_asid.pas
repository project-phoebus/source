{ SCSI_$FREE_ASID - free a process's SCSI resources.

  Image addresses:
    sau2  0x00E88800  SCSI_$FREE_ASID
    sau9  0x3C4A5514  SCSI_$FREE_ASID

  - With the driver (`scsi_driver'): releases every device the current
    process set up, but the system devices; the address space number is
    not read.
  - Without the driver (the SAU2) an empty procedure.

  Status stored: none.
}

%if scsi_driver %then
procedure scsi_$free_asid(in asid: integer);
var
  bus: integer;
  target: integer;
  h: scsi_$handle_t;
  st: status_$t;
begin
  for bus := 0 to scsi_bus_count - 1 do
    for target := 0 to scsi_max_target do
      with scsi_$cb[bus].target[target] do
        if not sys_device and then allocated
           and then (owner = proc1_$current) then begin
          h.all := 0;
          h.gen := gen;
          h.bus := bus;
          h.target := target;
          scsi_$release(h, st);
        end;
end;
%else
procedure scsi_$free_asid(in asid: integer);
begin
end;
%endif
