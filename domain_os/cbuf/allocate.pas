{ CBUF_$ALLOCATE - allocate a block at a circular buffer's write end.

  Image addresses:
    sau3  0x00E6EB1A  CBUF_$ALLOCATE
    sau4  0x0F87B95A  CBUF_$ALLOCATE

  - The result is the block's data, len bytes after its length word; the
    block is not readable until CBUF_$MAKE_VISIBLE.  A block that does
    not fit before the buffer's end goes to its start, after a zero
    length word at the old write end.
  - Without room the caller waits for a release; a quit ends the wait,
    and the result is then not assigned.
  - A block of length 0, or one the buffer could never hold, crashes the
    system (status_$cbuf_invalid_block_size with its fail bit).

  Status stored:
    status_$ok: the block was allocated
    status_$cbuf_quit_while_waiting: a quit ended the wait for room
}

function cbuf_$allocate(var cb: cbuf_$cb_t; in len: pinteger;
                        out status: status_$t): univ_ptr;
label
  full;
var
  r: integer32;
  token: pinteger;
  wait_value: integer32;
  n: pinteger;
begin
  n := len + 2;
  if odd(n) then
    n := n + 1;
  if (n >= cb.size) or else (len = 0) then
    crash_system(status_$cbuf_invalid_block_size_fail);
  status.all := status_$ok;

  wait_value := cb.ec.value;
  repeat
    wait_value := wait_value + 1;
    token := ml_$spin_lock(cbuf_lock);
    if cb.read = cb.write then begin
      { empty: from the start }
      cb.read := cb.base;
      cb.write := cb.base;
      cbuf_$word_ptr_t(cb.write)^ := len;
      ml_$spin_unlock(cbuf_lock, token);
      cbuf_$allocate := univ_ptr(cb.write + 2);
      return;
    end;
    if cb.read < cb.write then begin
      if n > cb.size + cb.base - cb.write - 2 then begin
        { past the end: from the start, before the read end }
        if n > cb.read - cb.base - 2 then
          goto full;
        cbuf_$word_ptr_t(cb.write)^ := 0;
        cbuf_$word_ptr_t(cb.base)^ := len;
        ml_$spin_unlock(cbuf_lock, token);
        cbuf_$allocate := univ_ptr(cb.base + 2);
        return;
      end;
    end
    else if n > cb.read - cb.write - 2 then
      goto full;
    cbuf_$word_ptr_t(cb.write)^ := len;
    ml_$spin_unlock(cbuf_lock, token);
    cbuf_$allocate := univ_ptr(cb.write + 2);
    return;

  full:
    cb.waiting := true;
    ml_$spin_unlock(cbuf_lock, token);
    r := ec_$wait(addr(cb.ec), addr(fim_$quit_ec[proc1_$as_id]),
                  addr(ec_$nil_ec), wait_value,
                  fim_$quit_value[proc1_$as_id] + 1, 0);
    cb.waiting := false;
  until r > 0;

  status.all := status_$cbuf_quit_while_waiting;
  fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
end;
