{ win_scsi_check_error_page - read a logical unit's block size and check
  its error recovery page.

  Image addresses:
    sau9  0x3C41B8C4  win_scsi_check_error_page

  - Reads page 1 (MODE SENSE, 20 bytes into the unit's buffer); keeps
    the block descriptor's block length (512 or 1024), the device blocks
    to a 1024-byte block and the page's length (6).
  - The flags must be as win_scsi_set_error_page leaves them: RC and DCR
    clear, and TB, PER and DTE set, or on a removable unit all three
    equal.

  Status stored:
    status_$ok: the page is as the driver wants it
    status_$unrecognized_drive_id: an illegal request, a block descriptor
      other than none or 8 bytes, another block size, page length or
      flags
    win_scsi_command's status: the MODE SENSE failed otherwise
}

function win_scsi_check_error_page(u: win_scsi_unit_ptr_t;
                                   lr: win_scsi_lun_ptr_t;
                                   lun: integer): integer32; internal;
var
  st: integer32;
  i: integer;
  cdb: scsi_$cdb_t;
  mh: win_scsi_mode_hdr_ptr_t;
  bd: win_scsi_block_desc_ptr_t;
  pg: win_scsi_error_page_ptr_t;
begin
  st := status_$ok;
  lr^.page_len := 0;
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := lun;
  cdb.f.op := win_scsi_op_mode_sense;
  cdb.b[4] := chr(20);
  cdb.g0.pc := 0;
  cdb.g0.page := win_scsi_error_recovery_page;
  st := win_scsi_command(u^.handle, lr, cdb, lun, scsi_$dir_in, u^.buf_ptr,
                         ord(cdb.b[4]), win_scsi_timeout);
  if st = status_$disk_illegal_request_for_device then
    st := status_$unrecognized_drive_id;
  if st = status_$ok then begin
    mh := u^.buf_ptr;
    if (mh^.bd_len <> 0) and then (mh^.bd_len <> 8) then
      st := status_$unrecognized_drive_id
    else begin
      bd := univ_ptr(integer32(mh) + 4);
      if mh^.bd_len <> 0 then
        lr^.block_len := bd^.block_len;
      if (lr^.block_len <> 512) and then (lr^.block_len <> 1024) then
        st := status_$unrecognized_drive_id
      else begin
        lr^.blocks_per := win_scsi_block_size div lr^.block_len;
        pg := univ_ptr(ord(mh^.bd_len) + integer32(bd));
        lr^.page_len := pg^.len;
        if lr^.page_len <> 6 then
          st := status_$unrecognized_drive_id
        else if lr^.removable then begin
          if (pg^.rc = 1) or else (pg^.dcr = 1) or else (pg^.per <> pg^.tb)
             or else (pg^.dte <> pg^.per) or else (pg^.dte <> pg^.tb) then
            st := status_$unrecognized_drive_id;
        end
        else if (pg^.tb = 0) or else (pg^.dcr = 1) or else (pg^.rc = 1)
                or else (pg^.per = 0) or else (pg^.dte = 0) then
          st := status_$unrecognized_drive_id;
      end;
    end;
  end;
  win_scsi_check_error_page := st;
end;
