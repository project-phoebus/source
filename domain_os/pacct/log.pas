{ PACCT_$LOG - write a terminated process's accounting record.

  Image addresses:
    sau2  0x00E5AA9C  PACCT_$LOG

  - When accounting is on, the record is built from the arguments, the
    requester's SIDs, the clock and the terminal's device number.
  - As super-user it is copied into the file's mapped window, a new
    32768-byte window mapped at the file's end when the current one is
    full, and the file's length set past it.

  Status stored: none.
}

{ TODO(pascal) the 4 frame bytes at the bottom of PACCT_$LOG's frame

  The stand-in unused_1a4 holds them: below i's slot nothing is
  addressed.  A pointer local for MST_$MAPS's result, which the image
  never keeps (the result goes straight to pacct_map_ptr), would fit as
  a register local's slot.  Not settled. }

procedure pacct_$log(in fork_flag: boolean; in su_flag: boolean;
                     in exit_status: integer;
                     in start_clock: time_$clock_t;
                     in proc_times: univ pacct_$times_t;
                     in io_write_count: integer32;
                     in io_read_count: integer32;
                     in tty_uid: uid_$t; in proc_uid: uid_$t;
                     in comm_ptr: univ pacct_$comm_t;
                     in comm_len: integer);
label
  exit_super;
var
  tty_loc: file_$obj_loc_t;
  file_info: file_$attr_info_t;
  unused_a4: integer32;                   { stand-ins: the header }
  subsys_info: acl_prot_info_t;
  unused_b4: integer32;
  prot_info: acl_prot_info_t;
  unused_c4: integer32;
  cur_sids: acl_sid_block_t;
  unused_ec: integer32;
  sids: acl_sid_block_t;
  rec: pacct_record_t;
  status: status_$t;
  current_clock: time_$clock_t;
  len: integer;
  i: integer;
  unused_1a4: integer32;                  { TODO above }
begin
  if pacct_owner = uid_$nil then
    return;
  time_$clock(current_clock);
  acl_$get_re_all_sids(sids, cur_sids, prot_info, subsys_info, status);

  { the rec }
  rec.ac_flags.word := 0;
  rec.ac_flags.fork_flag := fork_flag;
  rec.ac_flags.su_flag := su_flag;
  rec.ac_stat := exit_status;
  rec.ac_sids := sids;
  rec.ac_prot := prot_info;
  rec.ac_devno := 0;
  rec.ac_zero_42 := 0;
  rec.ac_io_write := pacct_$compress(io_write_count);
  rec.ac_io_read := pacct_$compress(io_read_count);
  rec.ac_mem := pacct_$compress((io_write_count + io_read_count) * 60);
  rec.ac_utime := pacct_$compress(proc_times[2]);
  rec.ac_stime := pacct_$compress(proc_times[3]);
  rec.ac_btime := cal_$clock_to_sec(start_clock) + unix_epoch_offset;
  discard(sub48(current_clock, start_clock));
  rec.ac_etime := pacct_$clock_to_comp(current_clock);
  rec.ac_proc_uid := proc_uid;

  { the command name }
  len := comm_len;
  if len > 32 then
    len := 32;
  for i := 1 to len do
    rec.ac_comm[i] := comm_ptr[i];
  for i := len + 1 to 32 do
    rec.ac_comm[i] := chr(0);

  { the terminal's device }
  file_$get_attr_info(tty_uid, pacct_log_attr_req, file_attr_info_size,
                      tty_loc, file_info, status);
  if status.all <> status_$ok then
    rec.ac_devno := -1
  else
    rec.ac_devno := file_info.devno;

  { the rec into the file }
  acl_$enter_super;
  if pacct_buf_remaining < pacct_record_size then begin
    if pacct_map_ptr <> 0 then begin
      mst_$unmap_privi(1, uid_$nil, pacct_map_ptr, pacct_map_offset, 0,
                       status);
      pacct_map_ptr := 0;
      pacct_map_offset := 0;
      pacct_buf_remaining := 0;
    end;
    pacct_map_ptr := integer32(mst_$maps(0, true, pacct_owner,
                                         pacct_file_pos, pacct_buffer_size,
                                         16#16, 0, true, pacct_map_offset,
                                         status));
    if status.all <> status_$ok then begin
      pacct_map_ptr := 0;
      pacct_buf_remaining := 0;
      goto exit_super;
    end;
    pacct_buf_remaining := pacct_map_offset;
    pacct_write_ptr := pacct_map_ptr;
  end;
  pacct_record_ptr_t(pacct_write_ptr)^ := rec;
  pacct_buf_remaining := pacct_buf_remaining - pacct_record_size;
  pacct_write_ptr := pacct_write_ptr + pacct_record_size;
  pacct_file_pos := pacct_file_pos + pacct_record_size;
  file_$set_len(pacct_owner, pacct_file_pos, status);

exit_super:
  acl_$exit_super;
end;
