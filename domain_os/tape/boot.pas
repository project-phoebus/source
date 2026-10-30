{ TAPE_$BOOT - boot from tape: load the boot shell, return its entry.

  Image addresses:
    sau2  0x00E32734  TAPE_$BOOT
    sau5  0x00E3433A  TAPE_$BOOT
    sau9  0x3C438AC0  TAPE_$BOOT
    sau5  0x00E33C8C  tape_$print (nested)
    sau9  0x3C438418  tape_$print (nested)
    sau5  0x00E33CA8  tape_$boot_errchk (nested)
    sau9  0x3C438434  tape_$boot_errchk (nested)
    sau5  0x00E33CE6  tape_$wait (nested)
    sau9  0x3C438472  tape_$wait (nested)
    sau5  0x00E33D24  tape_$rewind (nested)
    sau9  0x3C4384B0  tape_$rewind (nested)
    sau5  0x00E33D78  tape_$upcase (nested)
    sau9  0x3C438504  tape_$upcase (nested)
    sau5  0x00E33DD8  tape_$next_block (nested)
    sau9  0x3C438560  tape_$next_block (nested)
    sau5  0x00E33EC2  tape_$check_block (nested)
    sau9  0x3C43864A  tape_$check_block (nested)
    sau5  0x00E3409C  tape_$next_record (nested)
    sau9  0x3C438824  tape_$next_record (nested)
    sau5  0x00E34122  tape_$find_entry (nested)
    sau9  0x3C4388AA  tape_$find_entry (nested)
    sau5  0x00E341B2  tape_$load_file (nested)
    sau9  0x3C43893A  tape_$load_file (nested)

  - Without `tape_boot' (the SAU2..SAU4) the entry point is cleared and
    the result is false.
  - With it, FLOP_$BOOT's counterpart for the cartridge tape: the tape
    is acquired, rewound and spaced forward, and the file ending in
    "bscom/rbak_shell" (or upper-cased) copied into a mapped file.
  - That file is then mapped again at its header's address.
  - A failed step is reported on the boot console and ends it; the tape
    is rewound and released at the end.  The result is whether the
    status is ok.
  - tape_$upcase upper-cases the name in the constant itself.

  Status stored:
    status_$ok: the boot shell was loaded (also after the load-point
      warning)
    name_$not_found: no such file on the tape
    name_$not_file: an object header whose second data byte is not 0
    1, 2, 3, 4, 5: a second object header, data before the header, the
      end without data, another record type, a foreign save set UID
    the callees' statuses: those failed
}

%if tape_boot %then
{ TODO(pascal) the frame of TAPE_$BOOT

  The nested routines reach TAPE_$BOOT's locals where the image's frame
  has them; the declarations below follow that order, two of them
  stand-ins, and dpc lays the frame out its own way. }

[section(os_init_proc, os_init_data)]
function tape_$boot(out entry_point: integer32;
                    out status_ret: status_$t): boolean;
label
  done;
const
  { the file looked for: the end of the directory entries' pathnames }
  tape_shell_name = 'bscom/rbak_shell';
var
  header: tape_$header_t;                 { the file's first 0x400 bytes }
  cur_uid: uid_$t;                        { the save set's UID }
  boot_uid: uid_$t;                       { the backing store file }
  mapped: integer32;                      { the file's mapped address }
  cur: integer32;                         { the current record }
  unused_41c: integer32;
  expected: integer32;                    { the next block's sequence }
  buf: integer32;                         { the block buffer }
  unused_428: integer32;
  out_addr: integer32;                    { where object data goes }
  saved_status: status_$t;
  lock_info: integer32;
  map_info: integer32;
  offset: pinteger;                       { bytes used of the block }
  limit: pinteger;                        { the block's byte count }
  blk_idx: integer;                       { the block in the buffer }
  nblocks: integer;                       { blocks the last read got }
  eof: boolean;                           { the filemark was read }
  map_len: integer32;
  i: integer;

  { Print a 200-character message on the console. }
  procedure tape_$print(in msg: vfmt_$string_t);
  begin
    vfmt_$write2(msg, 0, 0);
  end;

  { Report a failed boot step: OS_$BOOT_ERRCHK prints the message, and
    that the normal shell is tried, when the status is not ok. }
  procedure tape_$boot_errchk(in msg: univ crash_$chars_t);
  begin
    discard(os_$boot_errchk(msg, '- trying normal shell', 21,
                            status_ret));
  end;

  { Wait for the drive, then report. }
  procedure tape_$wait(in msg: univ crash_$chars_t);
  begin
    if status_ret.all = status_$ok then
      ct_$wait(0, 16#168, nblocks, status_ret);
    tape_$boot_errchk(msg);
  end;

  { Rewind the tape. }
  procedure tape_$rewind;
  begin
    ct_$control(0, 8, nblocks, status_ret);
    tape_$boot_errchk('bad rewind%');
    if status_ret.all = status_$ok then
      tape_$wait('bad rewind%');
  end;

  { Upper-case the first len characters of name, in place: through its
    address, the caller's object itself (the constant name). }
  procedure tape_$upcase(in name: tape_$name_t; len: integer);
    options(val_param);
  var
    p: tape_$name_ptr_t;
    k: integer;
  begin
    p := addr(name);
    for k := 1 to len do
      if p^[k] in ['a'..'z'] then
        p^[k] := chr(ord(p^[k]) - 32);
  end;

  { Make the next block current, reading 256 more when the buffer is
    used up; the filemark ends the reads. }
  procedure tape_$next_block;
  label
    10;
  var
    pages: tape_$page_list_t;
    k: integer;
  begin
    status_ret.all := status_$ok;
    blk_idx := blk_idx + 1;
    if blk_idx > nblocks then begin
      if eof then begin
        status_ret.all := status_$ct_filemark_detected;
        return;
      end;
      pages[1] := buf;
      for k := 2 to 256 do
        pages[k] := pages[k - 1] + 512;
      ct_$read(0, pages, 256, nblocks, status_ret);
      if status_ret.all = status_$ct_filemark_detected then begin
        if nblocks = 0 then
          return;
        eof := true;
        status_ret.all := status_$ok;
        goto 10;
      end;
      if status_ret.all <> status_$ok then begin
        tape_$boot_errchk('bad tape read%');
        return;
      end;
10:   blk_idx := 1;
    end;
    cur := buf + (blk_idx - 1) * 512;
    offset := 0;
    limit := tape_$block_ptr_t(cur)^.len;
  end;

  { Make the next block current and check its UID and sequence. }
  procedure tape_$check_block;
  var
    blk: tape_$block_ptr_t;
  begin
    tape_$next_block;
    if status_ret.all <> status_$ok then
      return;
    blk := tape_$block_ptr_t(cur);
    if blk^.uid <> cur_uid then begin
      if cur_uid = uid_$nil then
        cur_uid := blk^.uid
      else begin
        tape_$print('tape error: UID in block header does not match those read from earlier blocks.%.');
        vfmt_$write5('correct uid = %lh.%lh, uid read = %lh.%lh, seq=%lh%.',
                     cur_uid.high, cur_uid.low, blk^.uid.high,
                     blk^.uid.low, blk^.seq);
        status_ret.all := 5;
        return;
      end;
    end;
    if blk^.seq <> expected then
      vfmt_$write2('** Seq out of order: expected %lh, read %lh%.',
                   expected, blk^.seq);
    expected := blk^.seq + 1;
    limit := blk^.len;
  end;

  { The next record, across blocks: a block's header is skipped, and
    from the second block on the record continued from the block before
    too. }
  function tape_$next_record: tape_$rec_ptr_t;
  var
    len: integer32;
  begin
    status_ret.all := status_$ok;
    while offset + 6 > limit do begin
      tape_$check_block;
      if status_ret.all <> status_$ok then
        return;
      cur := cur + 14;
      offset := offset + 14;
      if expected <> 2 then begin
        len := tape_$rec_ptr_t(cur)^.len + 6;
        if odd(len) then
          len := len + 1;
        cur := cur + len;
        offset := offset + len;
      end;
    end;
    tape_$next_record := tape_$rec_ptr_t(cur);
    len := tape_$rec_ptr_t(cur)^.len + 6;
    if odd(len) then
      len := len + 1;
    cur := cur + len;
    offset := offset + len;
  end;

  { Find the directory entry whose pathname ends in name (its first len
    characters). }
  function tape_$find_entry(in name: tape_$name_t; len: integer): boolean;
    options(val_param);
  var
    rec: tape_$rec_ptr_t;
    diff: integer;
    k: integer;
    match: boolean;
  begin
    repeat
      rec := tape_$next_record;
      if status_ret.all <> status_$ok then begin
        tape_$find_entry := false;
        return;
      end;
      case rec^.rtype of
        tape_rec_dir_entry: begin
          diff := rec^.len - 12 - len;
          if diff >= 0 then begin
            match := true;
            for k := 1 to len do
              if name[k] <> rec^.data[12 + diff + k] then begin
                match := false;
                exit;
              end;
            if match then begin
              tape_$find_entry := true;
              return;
            end;
          end;
        end;
        9: { empty };
      end;
    until false;
  end;

  { Copy the object's data records to the mapped file. }
  procedure tape_$load_file;
  var
    rec: tape_$rec_ptr_t;
    seen_hdr: boolean;
    seen_data: boolean;
    k: integer;
  begin
    seen_hdr := false;
    seen_data := seen_hdr;
    out_addr := mapped;
    repeat
      rec := tape_$next_record;
      tape_$boot_errchk('unexpected end of file%');
      if status_ret.all <> status_$ok then
        return;
      case rec^.rtype of
        tape_rec_object_hdr: begin
          if seen_hdr then begin
            status_ret.all := 1;
            tape_$boot_errchk('unexpected object hdr%');
            return;
          end
          else if ord(rec^.data[2]) <> 0 then begin
            status_ret.all := name_$not_file;
            tape_$boot_errchk('bad rbak_shell on tape%');
            return;
          end
          else
            seen_hdr := true;
        end;
        tape_rec_object_data: begin
          if not seen_hdr then begin
            status_ret.all := 2;
            tape_$boot_errchk('object hdr missing%');
            return;
          end
          else begin
            seen_data := true;
            for k := 1 to rec^.len div 2 do
              tape_$words_ptr_t(out_addr)^[k] :=
                tape_$words_ptr_t(addr(rec^.data))^[k];
            out_addr := out_addr + rec^.len;
          end;
        end;
        tape_rec_object_end: begin
          if seen_data then
            return
          else begin
            status_ret.all := 3;
            tape_$boot_errchk('no object data for file%');
            return;
          end;
        end;
        otherwise begin
          status_ret.all := 4;
          tape_$boot_errchk('unexpected entry type on tape%');
          return;
        end;
      end;
    until false;
  end;

begin
  ct_$acquire(0, status_ret);
  if status_ret.all = status_$ct_tape_not_at_load_point then
    status_ret.all := status_$ok;
  tape_$boot_errchk('bad acquire tape%');
  if status_ret.all <> status_$ok then
    goto done;

  tape_$rewind;
  if status_ret.all <> status_$ok then
    goto done;

  ct_$control(0, 3, 2, status_ret);
  tape_$boot_errchk('bad space request%');
  if status_ret.all <> status_$ok then
    goto done;

  { the backing store file, mapped; the block buffer its last 128 KB }
  file_$create(uid_$nil, boot_uid, status_ret);
  tape_$boot_errchk('can''t create backing store file%');
  if status_ret.all <> status_$ok then
    goto done;

  file_$lock(boot_uid, 0, 4, false, lock_info, status_ret);
  tape_$boot_errchk('can''t lock backing store file%');
  if status_ret.all <> status_$ok then
    goto done;

  mapped := integer32(mst_$map(boot_uid, 0, 16#120000, 7, 0, true,
                               map_info, status_ret));
  map_len := map_info;
  tape_$boot_errchk('can''t map backing store file%');
  if status_ret.all <> status_$ok then
    goto done;

  buf := map_len + mapped - 16#20000;
  for i := 1 to 256 do
    tape_$block_ptr_t(buf + (i - 1) * 512)^.w0 := 0;

  tape_$wait('bad space%');
  if status_ret.all <> status_$ok then
    goto done;

  { find the file and load it }
  blk_idx := 0;
  nblocks := 0;
  expected := 1;
  eof := false;
  limit := 0;
  offset := 1;
  cur_uid := uid_$nil;
  if not tape_$find_entry(tape_shell_name, 16) then begin
    tape_$upcase(tape_shell_name, 16);
    if not tape_$find_entry(tape_shell_name, 16) then begin
      status_ret.all := name_$not_found;
      tape_$boot_errchk('can''t find bscom/rbak_shell on tape%');
    end;
    if status_ret.all <> status_$ok then
      goto done;
  end;
  tape_$load_file;
  if status_ret.all <> status_$ok then
    goto done;

  { map it where its header asks }
  header := tape_$header_ptr_t(mapped)^;
  mst_$unmap(boot_uid, mapped, map_info, status_ret);
  tape_$boot_errchk('can''t unmap backing store file%');
  if status_ret.all <> status_$ok then
    goto done;

  mst_$map_at(header[1], boot_uid, 0, 16#100000, 7, 0, false,
              map_info, status_ret);
  tape_$boot_errchk('can''t map at indicated address%');
  if status_ret.all <> status_$ok then
    goto done;

  entry_point := header[2];

done:
  saved_status := status_ret;
  tape_$rewind;
  status_ret := saved_status;
  ct_$release(0, true, saved_status);
  tape_$boot := status_ret.all = status_$ok;
end;
%else

[section(os_init_proc, os_init_data)]
function tape_$boot(out entry_point: integer32;
                    out status_ret: status_$t): boolean;
begin
  entry_point := 0;
  tape_$boot := false;
end;
%endif
