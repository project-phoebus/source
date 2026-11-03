{ win_$read_mfg_badspots - read a drive's manufacturer's bad spots into
  a request's page.

  Image addresses:
    sau8  0x03C1A476  win_$read_mfg_badspots (module-local)

  - The controller's bad-spot command for the request's head; its
    sector, a word at a time, goes to WIN_PAGE mapped at the request's
    page.  With 256-byte sectors the three words after the sector's 128
    are set to -1.

  Status stored (in the request):
    status_$ok: the sector was read
    win_$send_command's, win_$wait_phase's or win_$check_status's
      result: it was not
}

procedure win_$read_mfg_badspots(in vol: disk_$volume_t;
                                 var req: disk_$io_req_t);
  internal;
type
  words_t = array[1..512] of integer;
var
  regs: win_$regs_ptr_t;
  buf: ^words_t;
  status: integer32;
  i: integer;
begin
  win_cmd.unit := vol.dev_unit;
  regs := win_units[0].regs;
  status := win_$send_command(win_cmd_read_badspots, 0, req.daddr.head, 0);
  if status = status_$ok then begin
    regs^.ctl := win_ctl_int_on;
    status := win_$wait_phase(win_phase_data_in);
    if status = status_$ok then begin
      buf := addr(win_page);
      mmu_$set_pmape(buf, win_page_pmape, req.ppn);
      for i := 1 to win_sector_size div 2 do begin
        buf^[i] := regs^.data_w;
        if (win_sector_size = 256) and (i = 128) then begin
          buf^[i + 1] := -1;
          buf^[i + 2] := -1;
          buf^[i + 3] := -1;
        end;
      end;
      status := win_$check_status(vol.dev_unit);
    end;
  end;
  req.status.all := status;
end;
