%if ct_scsi %then
{ CT_$WRITE - write blocks to the cartridge tape.

  Image addresses:
    sau9  0x3C4784AA  CT_$WRITE

  - For a drive that is set up, ct_scsi_transfer writes up to npages
    512-byte blocks from the page list's buffers; the count written is
    returned.
  - Without a drive that is set up, nothing is stored.

  Status stored:
    ct_check_unit's result: the unit may not be used
    ct_scsi_transfer's status: otherwise
}

procedure ct_$write(in unit: integer; in pages: univ ct_$page_list_t;
                    in npages: integer; out nwritten: integer;
                    out status: status_$t);
var
  st: status_$t;
begin
  if ct_scsi_state = ct_scsi_present then begin
    status.all := ct_check_unit(unit);
    if status.all = 0 then begin
      ct_scsi_transfer(unit, pages, npages, scsi_$dir_out, nwritten, st);
      status := st;
    end;
  end;
end;
%else
{ CT_$WRITE - write blocks to the cartridge tape.

  Image addresses:
    sau5  0x00E77BFA  CT_$WRITE

  - With the direction set to writing, ct_transfer writes up to npages
    512-byte blocks from the page list's buffers; the count written is
    returned.

  Status stored:
    ct_transfer's status: in either case
}

procedure ct_$write(in unit: integer; in pages: univ ct_$page_list_t;
                    in npages: integer; out nwritten: integer;
                    out status: status_$t);
var
  st: status_$t;
begin
  ct_reading := false;
  ct_transfer(unit, pages, npages, nwritten, st);
  status := st;
end;
%endif
