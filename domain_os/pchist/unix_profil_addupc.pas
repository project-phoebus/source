{ PCHIST_$UNIX_PROFIL_ADDUPC - count the current process's pending
  sample into its profil() buffer.

  Image addresses:
    sau2  0x00E5CFAC  PCHIST_$UNIX_PROFIL_ADDUPC

  - The pending pc (or the longword the overflow pointer points at) is
    taken and cleared.
  - A pc at or above the offset counts one more in the buffer's word at
    ((pc - offset) * scale) >> 16, rounded up to even, if inside it.
  - The low part is masked to 15 bits (16#7FFF).

  Status stored: none.
}

procedure pchist_$unix_profil_addupc;
var
  pid: integer;
  pc: linteger;
  hi: linteger;
  p: pchist_$word_ptr_t;
  unused_14: integer32;                   { stand-in }
  unused_18: integer32;                   { stand-in }
begin
  pid := proc1_$current;

  with pchist_$proc_data[pid] do begin
    if overflow_ptr = nil then
      pc := pchist_$addr[pid]
    else
      pc := overflow_ptr^;
    pchist_$addr[pid] := 0;
    if pc >= offset then begin
      pc := pc - offset;
      hi := rshft(pc, 16) * scale;
      pc := pc & 16#7FFF;
      pc := (rshft(pc * scale, 16) + hi + 1) & (-2);
      if pc < bufsize then begin
        p := pchist_$word_ptr_t(pc + buffer);
        p^ := p^ + 1;
      end;
    end;
  end;
end;
