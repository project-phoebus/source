{ win_scsi_rw_block - read or write the second half of a request's block
  alone.

  Image addresses:
    sau9  0x3C41B5EA  win_scsi_rw_block

  - Maps the request's page at WIN_PAGE, cache inhibited, and moves its
    second 512 bytes with READ(10) or WRITE(10) of one device block
    (block 2 * daddr + 1); the page is unmapped after.
  - Works on a copy of the logical unit: the copy goes back, with the
    data check it counted taken off again, only when the command fails;
    a recovered error counts as success.
}

function win_scsi_rw_block(handle: scsi_$handle_t; lr: win_scsi_lun_ptr_t;
                           lun: integer;
                           req: disk_$io_req_ptr_t): integer32; internal;
var
  copy: win_scsi_lun_t;
  cdb: scsi_$cdb_t;
  i: integer;
  dir: integer;
  va: univ_ptr;
  buf: univ_ptr;
  st: integer32;
begin
  copy := lr^;
  for i := 0 to 9 do
    cdb.b[i] := chr(0);
  cdb.f.lun := lun;
  if req^.owner_op.op = disk_$req_op_read then begin
    cdb.f.op := win_scsi_op_read10;
    dir := scsi_$dir_in;
  end
  else begin
    cdb.f.op := win_scsi_op_write10;
    dir := scsi_$dir_out;
  end;
  cdb.g1.lba := req^.daddr.daddr * 2 + 1;
  cdb.g1.len := 1;

  va := addr(win_page);
  mmu_$install(req^.ppn, va, 0, 16#16);
  mmu_$cache_inhibit_va(va);
  buf := univ_ptr(integer32(va) + 512);
  st := win_scsi_command(handle, addr(copy), cdb, lun, dir, buf, 512,
                         win_scsi_timeout);
  if copy.recovered then
    st := status_$ok;
  if st <> status_$ok then begin
    copy.stats.data_checks := copy.stats.data_checks - 1;
    lr^ := copy;
  end;
  mmu_$remove(va, 0);
  win_scsi_rw_block := st;
end;
