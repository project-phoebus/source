%if ct_scsi %then
{ CT_$READ - read blocks from the cartridge tape.

  Image addresses:
    sau9  0x3C4782C0  CT_$READ

  - For a drive that is set up, ct_scsi_transfer reads up to npages
    512-byte blocks into the page list's buffers; the count read is
    returned.
  - Without a drive that is set up, nothing is stored.
  - The frame holds the QIC-02 arm's status local, st (the SAU5's; the
    SAU7's copy passes it at -4), which this arm does not use.

  Status stored:
    ct_check_unit's result: the unit may not be used
    ct_scsi_transfer's status: otherwise
}

procedure ct_$read(in unit: integer; in pages: univ ct_$page_list_t;
                   in npages: integer; out nread: integer;
                   out status: status_$t);
var
  st: status_$t;                          { the QIC-02 arm's }
begin
  if ct_scsi_state = ct_scsi_present then begin
    status.all := ct_check_unit(unit);
    if status.all = 0 then
      ct_scsi_transfer(unit, pages, npages, scsi_$dir_in, nread, status);
  end;
end;
%elseif ct_atbus_qic02 %then
{ CT_$READ - read blocks from the cartridge tape.

  Image addresses:
    sau8  0x03C7B1EA  CT_$READ

  - With the direction set, ct_transfer moves up to npages 512-byte
    blocks; with the AT bus adapter (`ct_atbus_qic02') a failure sets
    ct_restart (the next transfer gives its command again), a success
    clears it.

  Status stored:
    ct_transfer's status: in either case
}

procedure ct_$read(in unit: integer; in pages: univ ct_$page_list_t;
                   in npages: integer; out nread: integer;
                   out status: status_$t);
var
  st: status_$t;
begin
  ct_reading := true;
  ct_transfer(unit, pages, npages, nread, st);
  status := st;
  if st.all <> 0 then
    ct_restart := true
  else
    ct_restart := false;
end;
%else
{ CT_$READ - read blocks from the cartridge tape.

  Image addresses:
    sau5  0x00E77ABC  CT_$READ

  - With the direction set to reading, ct_transfer reads up to npages
    512-byte blocks into the page list's buffers; the count read is
    returned.

  Status stored:
    ct_transfer's status: in either case
}

procedure ct_$read(in unit: integer; in pages: univ ct_$page_list_t;
                   in npages: integer; out nread: integer;
                   out status: status_$t);
var
  st: status_$t;
begin
  ct_reading := true;
  ct_transfer(unit, pages, npages, nread, st);
  status := st;
end;
%endif
