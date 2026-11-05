{ RETRY_DATA_CHECK - the recovery step for a data check.

  Image addresses:
    sau5  0x00E19B6C  RETRY_DATA_CHECK
    sau6  0x78019FA0  RETRY_DATA_CHECK

  - From the third pass of nine retries, a read with error code 10 on a
    controller of revision 2 or later is corrected from the ECC
    (win_$ecc_correct); every ninth retry restores the drive (odd) or
    seeks its last cylinder (even).

  Returns:
    status_$ok: the ECC corrected it
    restore's or seek's status: the heads' move failed
    -1: retry

  Status stored: none.
}

function retry_data_check(in ctlr: pinteger; in dev_unit: pinteger;
                          in retry: integer): integer32;
var
  regs: win_$regs_ptr_t;
  pass: integer;
  status: integer32;
  cyl: pinteger;
begin
  regs := win_units[ctlr].regs;
  pass := retry div 9;

  if (pass > 2) and then (win_cur_req^.owner_op.op = disk_$req_op_read)
     and then (win_err = 10) and then (regs^.rev >= 2) then begin
    win_$ecc_correct(ctlr, regs^.desc[1].page);
    retry_data_check := status_$ok;
  end
  else begin
    if retry mod 9 = 0 then begin
      if odd(pass) then
        status := restore(ctlr, dev_unit)
      else begin
        cyl := regs^.drives[dev_unit].cyls - 1;
        status := seek(ctlr, dev_unit, cyl);
      end;
      if status <> status_$ok then begin
        retry_data_check := status;
        return;
      end;
    end;
    retry_data_check := -1;
  end;
end;
