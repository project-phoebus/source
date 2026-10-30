{ WIN_SCSI_$DO_IO - the driver's I/O entry: format the disk, or run a
  chain of read or write requests.

  Image addresses:
    sau9  0x3C41C1CC  WIN_SCSI_$DO_IO

  - Under the controller's lock (the device entry's flags word), released
    while a FORMAT UNIT runs.
  - A whole-disk format sets the error recovery page (saved), checks it
    and sends FORMAT UNIT.
  - Reads and writes (a write chain sorted first) go in runs of
    consecutive blocks, at most the unit's max_pages each, through
    SCSI_$DO_COMMAND_PHYS on the module's page list; the logical unit's
    statistics count the blocks.
  - On a failure the request the sense names (else the run's first) gets
    the status, its process's io_pending is cleared, and the requests
    after it get -1.  A recovered error on a device of more than one
    block to a disk block, whose information is a disk block's first
    device block, has that request's second 512 bytes, which the stopped
    transfer did not move, redone alone (win_scsi_rw_block); a recovered
    status with no request to name becomes status_$disk_data_check.

  Status stored (in the request):
    status_$ok: the requests were done
    status_$disk_mfg_badspots_not_available: a format request
    status_$disk_illegal_request_for_device: operations 3..8
    status_$unknown_error_status_from_drive: any other operation
    status_$disk_driver_logic_error: a run longer than max_pages
    a command's status: the format or a transfer failed
}

procedure win_scsi_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                          in param_3: univ integer32; out result: boolean);
label
  failed;
var
  lun: integer;
  ctlr: pinteger;
  lock: integer;
  handle: scsi_$handle_t;
  u: win_scsi_unit_ptr_t;
  cdb: scsi_$cdb_t;
  copy: win_scsi_lun_t;
  r: disk_$io_req_ptr_t;
  first: disk_$io_req_ptr_t;
  max_pages: integer32;
  dir: integer;
  st: integer32;
  st2: integer32;
  n: integer;
  i: integer;
  daddr: linteger;
  partial: boolean;
  target: integer32;
begin
  result := false;
  lun := vol.dev_unit;
  ctlr := vol.dev_info^.controller;
  lock := vol.dev_info^.flags;
  case req.owner_op.op of
    0: { nothing to do };

    disk_$req_op_format_whole: begin
      ml_$lock(lock);
      handle := win_scsi_units[ctlr].handle;
      req.status.all :=
        win_scsi_set_error_page(addr(win_scsi_units[ctlr]),
                                addr(win_scsi_units[ctlr].luns[lun]), lun,
                                cdb, true, false);
      if win_scsi_units[ctlr].luns[lun].removable
         and then (req.status.all = status_$disk_illegal_request_for_device) then
        req.status.all :=
          win_scsi_set_error_page(addr(win_scsi_units[ctlr]),
                                  addr(win_scsi_units[ctlr].luns[lun]), lun,
                                  cdb, true, true);
      if req.status.all = status_$ok then begin
        for i := 0 to 5 do
          cdb.b[i] := chr(0);
        cdb.f.lun := lun;
        cdb.f.op := win_scsi_op_format_unit;
        req.status.all :=
          win_scsi_check_error_page(addr(win_scsi_units[ctlr]),
                                    addr(win_scsi_units[ctlr].luns[lun]),
                                    lun);
        if req.status.all = status_$ok then begin
          copy := win_scsi_units[ctlr].luns[lun];
          ml_$unlock(lock);
          req.status.all := win_scsi_command(handle, addr(copy), cdb, lun,
                                             scsi_$dir_out, nil, 0,
                                             win_scsi_format_timeout);
          ml_$lock(lock);
          win_scsi_units[ctlr].luns[lun] := copy;
        end;
      end;
      ml_$unlock(lock);
    end;

    disk_$req_op_format: begin
      req.status.all := status_$disk_mfg_badspots_not_available;
    end;

    disk_$req_op_format_track, 4, 5, 6, 7, 8: begin { the formats of a track and
                                            the other operations below a
                                            format }
      req.status.all := status_$disk_illegal_request_for_device;
    end;

    disk_$req_op_read, disk_$req_op_write: begin
      r := addr(req);
      if (r^.owner_op.op = disk_$req_op_write) and then (r^.next <> nil) then
        disk_$sort(vol, r);
      ml_$lock(lock);
      handle := win_scsi_units[ctlr].handle;
      u := addr(win_scsi_units[ctlr]);
      copy := u^.luns[lun];
      max_pages := win_scsi_units[ctlr].max_pages;
      for i := 0 to 9 do
        cdb.b[i] := chr(0);
      cdb.f.lun := lun;
      if req.owner_op.op = disk_$req_op_read then
        dir := scsi_$dir_in
      else
        dir := scsi_$dir_out;
      st := status_$ok;

      { The runs. }
      while (r <> nil) and then (st = status_$ok) do begin
        n := 0;
        first := r;
        repeat
          daddr := r^.daddr.daddr;
          n := n + 1;
          if n > max_pages then begin
            st := status_$disk_driver_logic_error;
            goto failed;
          end;
          win_scsi_pages[n] := r^.ppn * win_scsi_block_size;
          r := r^.next;
        until (r = nil) or else (r^.daddr.daddr <> daddr + 1);
        if req.owner_op.op = disk_$req_op_read then
          copy.stats.reads := copy.stats.reads + n
        else
          copy.stats.writes := copy.stats.writes + n;
        if dir = scsi_$dir_in then
          cdb.f.op := win_scsi_op_read10
        else
          cdb.f.op := win_scsi_op_write10;
        cdb.g1.lba := first^.daddr.daddr * copy.blocks_per;
        cdb.g1.len := n * copy.blocks_per;
        st := win_scsi_command_phys(handle, addr(copy), cdb, lun, dir,
                                    win_scsi_pages, n,
                                    n * win_scsi_block_size,
                                    win_scsi_timeout);
      end;

      { A failure: the request it names, and those after it. }
failed:
      if st <> status_$ok then begin
        r := first;
        partial := false;
        if copy.valid then begin
          partial := copy.recovered and then (copy.blocks_per <> 1)
                     and then (copy.info mod copy.blocks_per = 0);
          target := copy.info div copy.blocks_per;
          while (r <> nil) and then (r^.daddr.daddr <> target) do
            r := r^.next;
        end;
        if not copy.valid or else (r = nil) then begin
          r := first;
          partial := false;
          if (st = status_$disk_ok_after_device_recovery)
             or else (st = status_$disk_ok_after_retry)
             or else (st = status_$disk_ok_after_crc_correction) then
            st := status_$disk_data_check;
        end;
        if partial then begin
          st2 := win_scsi_rw_block(handle, addr(copy), lun, r);
          if st2 <> status_$ok then
            st := st2;
        end;
        r^.status.all := st;
        if not copy.recovered then
          if req.owner_op.op = disk_$req_op_read then
            copy.stats.reads := copy.stats.reads - 1
          else
            copy.stats.writes := copy.stats.writes - 1;
        disk_bptbl[r^.owner_op.owner].io_pending := false;
        r := r^.next;
        while r <> nil do begin
          r^.status.all := -1;
          r := r^.next;
          if req.owner_op.op = disk_$req_op_read then
            copy.stats.reads := copy.stats.reads - 1
          else
            copy.stats.writes := copy.stats.writes - 1;
        end;
      end;
      u^.luns[lun] := copy;
      ml_$unlock(lock);
    end;

    otherwise begin
      req.status.all := status_$unknown_error_status_from_drive;
    end;
  end;
end;
