{ AS_$INIT - relocate the address-space layout for a 68020.

  Image addresses:
    sau2  0x00E3151C  AS_$INIT
    sau8  0x03C348C8  AS_$INIT

  - On a 68010 it does nothing: the hand-written block's defaults stand.
  - With the layout chosen at boot the test is MMU_$HAVE_PMMU, and the
    layout the PMMU's (MST_$PRE_INIT).
  - The field moved at +0x44 is l_44; the map's AS_$STACK_OFFSET, at
    +0x40, is not touched (as/as.ins.pas).

  Status stored: none.
}

{ TODO(pascal) 8 frame bytes unexplained (stand-in unused_8)

  The frame has 8 bytes and no operand addresses them.  A local holding
  m68020_as_offset would explain 4 bytes, the temporary of a `with
  as_$info do' 4 more; the plain reading leaves both to the stand-in. }

[section(os_init_proc, os_init_data)]
procedure as_$init;
var
  unused_8: array[1..2] of integer32;     { the stand-in (TODO) }
begin
%if run_time_layout %then
  if mmu_$have_pmmu then begin
%else
  if m68020 then begin
%endif
    as_$info.global_a.base := m68020_global_a_base;
    as_$info.global_a.size := m68020_global_a_size;
    as_$info.global_a_m68020 := as_$info.global_a;
    as_$info.stack_file_low := as_$info.stack_file_low + m68020_as_offset;
    as_$info.cr_rec := as_$info.cr_rec + m68020_as_offset;
    as_$info.cr_rec_end := as_$info.cr_rec_end + m68020_as_offset;
    as_$info.stack_file_high := as_$info.stack_file_high + m68020_as_offset;
    as_$info.stack_low := as_$info.stack_low + m68020_as_offset;
    as_$info.stack_high := as_$info.stack_high + m68020_as_offset;
    as_$info.l_44 := as_$info.l_44 + m68020_as_offset;
    as_$info.cr_rec_file := as_$info.cr_rec_end;
  end;
end;
