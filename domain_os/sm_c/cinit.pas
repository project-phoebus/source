{ SM_C_$CINIT - initialize the SM_C controller at boot.

  Image addresses:
    sau3  0x00E6F33A  SM_C_$CINIT
    sau4  0x0F87C0F2  SM_C_$CINIT
    sau5  0x00E74E9E  SM_C_$CINIT

  - The result is status_$ok, or status_$io_controller_not_in_system
    when the PBU is absent, the probe fails or the interrupt cannot be
    acquired.
  - A failure to get the PBU's pointer or space crashes the system.

  Status stored: none.
}

function sm_c_$cinit(var dcte: dcte_t): integer32;
label
  failed;
var
  status: status_$t;
  info: integer32;
  probe_data: sm_$byte_t;
  unit: integer;
begin
  sm_c_dcte := addr(dcte);
  if not pbu_$mcb.present then
    goto failed;
  if not testpage(0, addr(pbu_sm_c_page.probe), probe_data) then
    goto failed;
  sm_c_hdr := addr(sm_blk_hdr);
  sm_c_dcte^.io_va := integer32(sm_c_hdr);
  pbu_$acquire_int(sm_pbu_unit, addr(sm_c_$int), nil,
                   addr(pbu_sm_c_page), 16#6800, 1, 3, status);
  if status.all <> 0 then
    goto failed;

  sm_c_pbu_info := pbu_$get_ptr(sm_pbu_unit, sm_pbu_unit, info, status);
  if status.all <> 0 then
    crash_system(status);
  sm_c_alloc := pbu_$alloc(sm_pbu_unit, false, 2, 0, status);
  if status.all <> 0 then
    crash_system(status);
  sm_c_alloc_count := 2;
%if mbus_map_64k %then
  sm_c_iomap_index := rshft(sm_c_alloc, 10) + 192;
%else
  sm_c_iomap_index := rshft(sm_c_alloc, 10);
%endif
  sm_c_iomap_entry := addr(iomap[sm_c_iomap_index + 1]);
  for unit := 0 to sm_max_unit do begin
    ec_$init(sm_$cb.c_unit[unit].ec);
    sm_$cb.c_unit[unit].flags.parity_err := false;
  end;
  discard(disk_$register(sm_pbu_unit, sm_c_dcte^.cnum, sm_c_unit_count,
                         sm_c_dcte^.disk_error_que_hi,
                         addr(sm_c_jump_table)));
  sm_c_$cinit := status_$ok;
  return;

failed:
  sm_c_$cinit := status_$io_controller_not_in_system;
end;
