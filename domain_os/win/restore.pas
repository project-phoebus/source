{ RESTORE - recalibrate a drive.

  Image addresses:
    sau5  0x00E199EC  RESTORE

  - The first descriptor is set to the drive and the restore command
    given, up to three times; the descriptor and the current request are
    put back.  WIN_$RESTORES counts the calls.  With the descriptor-list
    controller only.

  Returns:
    win_$command's status: the last try's

  Status stored: none.
}

function restore(in ctlr: pinteger; in dev_unit: pinteger): integer32;
var
  saved_req: disk_$io_req_ptr_t;
  regs: win_$regs_ptr_t;
  saved_desc: win_$desc_t;
  status: integer32;
  tries: integer;
begin
  saved_req := win_cur_req;
  win_cur_req := nil;
  win_$restores := win_$restores + 1;
  regs := win_units[ctlr].regs;
  saved_desc := regs^.desc[1];
  regs^.desc[1].drive := dev_unit;
  regs^.count := 1;

  for tries := 1 to 3 do begin
    status := win_$command(ctlr, win_cmd_restore);
    if status = status_$ok then
      exit;
  end;

  regs^.desc[1] := saved_desc;
  win_cur_req := saved_req;
  restore := status;
end;
