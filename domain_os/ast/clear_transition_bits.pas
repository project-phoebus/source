{ ast_$clear_transition_bits - end the transition of a run of segment
  map entries.

  Image addresses:
    sau2  0x00E0283C  ast_$clear_transition_bits (module-local)
    sau4  0x0F802C6A  ast_$clear_transition_bits (module-local)
    sau9  0x3C403BAC  ast_$clear_transition_bits (module-local)

  - Each of the count entries loses its in-transition member; an
    installed one whose page number lies in MMAP's range is first
    handed back to the page pool (MMAP_$AVAIL).
  - The PMAP in-transition eventcount is then advanced.

  Status stored: none.
}

procedure ast_$clear_transition_bits(var entries: univ ast_$pmap_run_t;
                                     count: pinteger);
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with entries[i] do begin
      if (ast_$pmap_installed in flags) and then
         (vpn >= mmap_$first_ppn) and then (vpn <= mmap_$last_ppn) then
        mmap_$avail(vpn);
      flags := flags - [ast_$pmap_in_trans];
    end;

  ec_$advance(ast_$pmap_in_trans_ec);
end;
