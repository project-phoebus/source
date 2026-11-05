{ ring_8025_probe - find out whether a unit's adapter answers.

  Image addresses:
    sau7  0x3C495C5A  ring_8025_probe
    sau8  0x03C89372  ring_8025_probe
    sau9  0x3C484F72  ring_8025_probe

  - Maps the unit's CSR pages and resets the adapter, then reads ten
    words of the controller's memory twice: with auto-increment, and
    one by one.  The address register must follow (bits 5 and up) and
    each word must read the same; a failure unmaps the pages.
  - The result is true when the adapter answered, its CSR pages left
    mapped.
}

function ring_8025_probe(desc: ring_8025_$io_desc_ptr_t): boolean;
  internal;
label
  fail;
var
  saved: array[0..9] of ring_8025_$word_t;
  regs: ring_8025_$regs_ptr_t;
  status: status_$t;
  i: integer;
  j: integer32;
  mismatch: boolean;
begin
  io_$map_csr(desc^, status);
  if status.all <> status_$ok then begin
    ring_8025_probe := false;
    return;
  end;
  regs := ring_8025_$regs_ptr_t(desc^.csr.va);
  regs^.reset := 1;
  for j := 0 to 999999 do
    ;
  regs^.reset := 0;
  for j := 0 to 999999 do
    ;
  regs^.control_7 := regs^.control_7 ! 1;

  { read ten words with auto-increment }
  regs^.sifadr := ring_8025_swap16(r8025_init_params_addr);
  for i := 0 to 9 do begin
    saved[i] := regs^.sifdat_inc;
    mismatch := rshft(xor(regs^.sifadr,
                          ring_8025_swap16(r8025_init_params_addr + 2
                                           + i * 2)), 5) <> 0;
    if mismatch then
      goto fail;
  end;

  { and read them again at their addresses }
  for i := 0 to 9 do begin
    regs^.sifadr := ring_8025_swap16(r8025_init_params_addr + i * 2);
    mismatch := rshft(xor(regs^.sifadr,
                          ring_8025_swap16(r8025_init_params_addr
                                           + i * 2)), 5) <> 0;
    if mismatch then
      goto fail;
    if saved[i] <> regs^.sifdat then
      goto fail;
  end;
  regs^.sifcmd := 0;
  regs^.reset := 0;
  regs^.control_7 := 1;
  regs^.control_3 := 0;
  ring_8025_probe := true;
  return;

fail:
  io_$unmap_csr(desc^, status);
  ring_8025_probe := false;
end;
