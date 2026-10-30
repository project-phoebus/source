{ win_scsi_set_error_page - set a logical unit's error recovery page.

  Image addresses:
    sau9  0x3C41B700  win_scsi_set_error_page

  - Reads the page (MODE SENSE of page 1, 20 bytes into the unit's
    buffer), then writes it back with MODE SELECT (PF set, SP when
    save_pages), the block descriptor's block length 512 when save_pages,
    else the descriptor as read.
  - The page's flags: TB, PER and DTE set and the correction span at
    least 11, or with clear_recovery those three cleared; AWRE, ARRE, RC
    and DCR always cleared.
  - Returns the MODE SENSE's status when it fails, else MODE SELECT's.
}

function win_scsi_set_error_page(u: win_scsi_unit_ptr_t;
                                 lr: win_scsi_lun_ptr_t; lun: integer;
                                 var cdb: scsi_$cdb_t;
                                 save_pages: boolean;
                                 clear_recovery: boolean): integer32;
  internal;
var
  st: integer32;
  i: integer;
  mh: win_scsi_mode_hdr_ptr_t;
  bd: win_scsi_block_desc_ptr_t;
  pg: win_scsi_error_page_ptr_t;
  saved_bd: win_scsi_block_desc_t;
  saved_pg: win_scsi_error_page_t;
  words: win_scsi_buf_words_ptr_t;
begin
  { MODE SENSE of the page. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := lun;
  cdb.f.op := win_scsi_op_mode_sense;
  cdb.b[4] := chr(20);
  cdb.g0.pc := 0;
  cdb.g0.page := win_scsi_error_recovery_page;
  st := win_scsi_command(u^.handle, lr, cdb, lun, scsi_$dir_in, u^.buf_ptr,
                         ord(cdb.b[4]), win_scsi_timeout);
  if st <> status_$ok then begin
    win_scsi_set_error_page := st;
    return;
  end;

  mh := u^.buf_ptr;
  if mh^.bd_len <> 0 then begin
    bd := univ_ptr(integer32(mh) + 4);
    saved_bd := bd^;
    pg := univ_ptr(ord(mh^.bd_len) + integer32(bd));
  end
  else begin
    bd := nil;
    pg := univ_ptr(integer32(mh) + 4);
  end;
  saved_pg := pg^;

  { MODE SELECT of it. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := lun;
  cdb.f.op := win_scsi_op_mode_select;
  cdb.g0.pf := true;
  if save_pages then
    cdb.g0.sp := true;
  cdb.b[4] := chr(12 + mh^.bd_len);
  words := win_scsi_buf_words_ptr_t(mh);
  for i := 1 to ord(cdb.b[4]) + mh^.bd_len + lr^.page_len + 2 do
    words^[i] := 0;
  if bd <> nil then begin
    mh^.bd_len := 8;
    if save_pages then
      bd^.block_len := 512
    else
      bd^ := saved_bd;
  end;
  pg^ := saved_pg;
  pg^.ps := 0;
  if not clear_recovery then begin
    if pg^.span < 11 then
      pg^.span := 11;
    pg^.tb := 1;
    pg^.per := 1;
    pg^.dte := 1;
  end
  else begin
    pg^.tb := 0;
    pg^.per := 0;
    pg^.dte := 0;
  end;
  pg^.awre := 0;
  pg^.arre := 0;
  pg^.rc := 0;
  pg^.dcr := 0;
  win_scsi_set_error_page :=
    win_scsi_command(u^.handle, lr, cdb, lun, scsi_$dir_out, u^.buf_ptr,
                     ord(cdb.b[4]), win_scsi_timeout);
end;
