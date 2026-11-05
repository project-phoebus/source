{ ethernet_download - load a program file into the adapter.

  Image addresses:
    sau7  0x3C491A64  ethernet_download
    sau8  0x03C85260  ethernet_download
    sau9  0x3C480E60  ethernet_download

  - The file (the callers name /sys/ethernet8_microcode) is resolved,
    locked, mapped and its pages wired; the adapter is given the
    download command with the file's length, the file's bytes go through
    the data register and the reply is awaited, under the unit's command
    lock.  result is the reply's result word.
  - Whatever was done is undone at the end, whatever failed: the pages
    unwired, the file unmapped and unlocked.

  Status stored:
    name_$resolve's, file_$lock's, mst_$maps's status: that step failed
    ethernet_start_cmd's, ethernet_$$pio_write's or ethernet_wait_cmd's
      status: the download
}

procedure ethernet_download(u: ethernet_$unit_ptr_t;
                            in name: univ name_$long_pname_t;
                            name_len: integer; out result: integer;
                            out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
  wired_pages: array[1..32] of integer32;
  file_uid: uid_$t;
  st: status_$t;
  lock_info: integer32;
  len: integer32;
  va: univ_ptr;
  i: integer;
  wired_cnt: integer;
  locked: boolean;
  mapped: boolean;
  wired: boolean;
begin
  locked := false;
  mapped := false;
  wired := false;
  name_$resolve(name, name_len, file_uid, status);
  if status.all <> status_$ok then
    return;
  file_$lock(file_uid, 0, 1, false, lock_info, status);
  if status.all = status_$ok then begin
    locked := true;
    va := mst_$maps(0, true, file_uid, 0, 16#7FFF, 18, 0, false, len,
                    status);
    if status.all = status_$ok then begin
      mapped := true;
      mst_$wire_area(va, univ_ptr(integer32(va) + len - 1), wired_pages, 32,
                     wired_cnt);
      wired := true;
      pcb.cmd := eth_cmd_download_program;
      pcb.len := 2;
      pcb.words[1] := lshft(len, 8) ! rshft(len, 8);
      ml_$exclusion_start(u^.cmd_lock);
      ethernet_start_cmd(u, addr(pcb),
                         eth_cmd_download_program + eth_cmd_reply, status);
      if status.all = status_$ok then
        discard(ethernet_$$pio_write(u^.regs, va, len, status));
      if status.all = status_$ok then begin
        ethernet_wait_cmd(u, status);
        result := pcb.words[1];
      end
      else
        u^.flags := u^.flags - [eth_unit_cmd_pending];
      ml_$exclusion_stop(u^.cmd_lock);
    end;
  end;
  if wired then
    for i := 1 to wired_cnt do
      wp_$unwire(wired_pages[i]);
  if mapped then
    mst_$unmap_privi(1, file_uid, integer32(va), len, 0, st);
  if locked then
    discard(file_$unlock(file_uid, 1, st));
end;
