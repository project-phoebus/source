{ dir_$old_read_entries - read an old-format directory's entries into a
  caller's buffer.

  Image addresses:
    sau2  0x00E579C0  dir_$old_read_entries (module-local)

  - Under a read lock (mode 1, rights 4), from the position (sub, index):
    page 0's slots, then the overflow blocks; each slot in use becomes
    one canonical directory entry, its name un-mapped (UNMAP_CASE).
  - Super-user mode is left (not after the early success).
  - The unlock's status overwrites status_ret.

  Status stored:
    status_$ok: the entries were read, or none were asked for
    name_$unlock_dir's status: the unlock failed
    name_$lock_dir's status: the directory could not be locked
}

procedure dir_$old_read_entries(in dir_uid: uid_$t;
                                in out cursor: dir_$readu_cont_t;
                                max_entries: integer32;
                                buf_size: linteger;
                                out buf: univ dir_$readu_buf_t;
                                out count_ret: linteger;
                                out status_ret: status_$t);
  internal;
label
  10;
var
  tmp: array[1..32] of char;
  used: linteger;
  handle: dir_$old_dir_ptr_t;
  out_len: integer;
  truncated: boolean;
  sub: pinteger;
  index: pinteger;
  size: pinteger;
  rec: dir_$readu_entry_ptr_t;
  i: integer;
begin
  count_ret := 0;
  used := 0;

  if (max_entries = 0) or else (cursor.all = 0) then begin
    status_ret.all := status_$ok;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 1, 4, status_ret);
  if status_ret.all = status_$ok then begin
    sub := cursor.sub;
    index := cursor.index;

    { the page's own slots }
    if sub = 0 then begin
      if index > handle^.hdr.inline_slots then begin
        status_ret.all := status_$naming_illegal_directory_operation;
        goto 10;
      end;
      while sub = 0 do begin
        with handle^.slots[index] do
          if slot_type <> 0 then begin
            unmap_case(name, name_len, tmp, 16#20, out_len, truncated);
            size := (16#1A + out_len) & (-4);
            if size + used * 2 > buf_size then
              goto 10;
            count_ret := count_ret + 1;
            rec := dir_$readu_entry_ptr_t(addr(buf[used]));
            used := used + size div 2;
            with rec^ do begin
              entnxt := size;
              cursor.index := index;
              cursor.sub := sub;
              enthandle := cursor.all;
              for i := 1 to out_len do
                entname[i] := tmp[i];
              entname[out_len + 1] := chr(0);
              entlen := out_len;
              enttype := slot_type;
              entuid := uid;
              entextra := extra;
            end;
          end;

        if handle^.entries_used <= count_ret then begin
          index := 0;
          sub := 0;
          goto 10;
        end;
        index := index + 1;
        if index > handle^.hdr.inline_slots then begin
          index := 1;
          sub := 1;
        end;
        if max_entries = count_ret then
          goto 10;
      end;
    end;

    { the overflow blocks }
    repeat
      if index > handle^.blocks_used then begin
        sub := 0;
        index := 0;
        goto 10;
      end;
      if handle^.blocks[index].used = 0 then begin
        sub := 1;
        index := index + 1;
        next;
      end;

      with handle^.blocks[index].slots[sub] do
        if slot_type <> 0 then begin
          unmap_case(name, name_len, tmp, 16#20, out_len, truncated);
          size := (16#1A + out_len) & (-4);
          if size + used * 2 > buf_size then
            goto 10;
          count_ret := count_ret + 1;
          rec := dir_$readu_entry_ptr_t(addr(buf[used]));
          used := used + size div 2;
          with rec^ do begin
            entnxt := size;
            cursor.index := index;
            cursor.sub := sub;
            enthandle := cursor.all;
            for i := 1 to out_len do
              entname[i] := tmp[i];
            entname[out_len + 1] := chr(0);
            entlen := out_len;
            enttype := slot_type;
            entuid := uid;
            entextra := extra;
          end;
        end;

      if handle^.max_entries <= count_ret then begin
        index := 0;
        sub := 0;
        goto 10;
      end;
      sub := sub + 1;
      if sub > handle^.hdr.block_slots then begin
        sub := 1;
        index := index + 1;
      end;
      if max_entries = count_ret then
        goto 10;
    until false;

10:
    name_$unlock_dir(status_ret);
    if status_ret.all = status_$ok then begin
      cursor.sub := sub;
      cursor.index := index;
      status_ret.all := status_$ok;
    end;
  end;

  acl_$exit_super;
end;
