{ SM_$CINIT - initialize the storage module controller at boot.

  Image addresses:
    sau3  0x00E6DF5C  SM_$CINIT
    sau4  0x0F8776B2  SM_$CINIT
    sau5  0x00E6F2B4  SM_$CINIT

  - When the PBU is present and the controller answers the probe, the
    controller's PBU interrupt is acquired, its PBU space allocated and
    the driver registered with DISK_$REGISTER (device type 4).
  - A failure of PBU_$GET_PTR or PBU_$ALLOC crashes the system.
  - Without the controller the command block's 336 bytes are cleared.

  Returns:
    status_$ok: the controller was set up
    status_$io_controller_not_in_system: no PBU, no answer to the probe,
      or the interrupt could not be acquired

  Status stored: none.
}

function sm_$cinit(var dcte: dcte_t): integer32;
label
  failed;
var
  status: status_$t;
  info: integer32;
  i: integer;
  cb_bytes: sm_$cb_bytes_ptr_t;
begin
  sm_dcte := addr(dcte);
  if not pbu_$mcb.present then
    goto failed;
  if not testpage(sm_probe_kind, addr(pbu_sm_page.go), sm_$cb.probe) then
    goto failed;
  pbu_sm_page.go := sm_$cb.go_ack;
  pbu_$acquire_int(sm_pbu_unit, addr(sm_$int), nil, addr(pbu_sm_page),
                   16#6C00, 1, 3, status);
  if status.all <> 0 then
    goto failed;

  sm_pbu_info := pbu_$get_ptr(sm_pbu_unit, sm_pbu_unit, info, status);
  if status.all <> 0 then
    crash_system(status);
  sm_$cb.alloc := pbu_$alloc(sm_pbu_unit, true, 2, sm_cb_iova, status);
  if status.all <> 0 then
    crash_system(status);
  sm_$cb.alloc_count := 2;
%if long_iomap %then
  iomap[sm_iomap_cb] :=
    mmu_$vtop(integer32(addr(sm_$cb)), status) + sm_iomap_bias;
%elseif word_iomap %then
  iomap[sm_iomap_cb] := mmu_$vtop(integer32(addr(sm_$cb)), status);
%else
  iomap[sm_iomap_cb].entry :=
    mmu_$vtop(integer32(addr(sm_$cb)), status) + sm_iomap_bias;
%endif
  discard(disk_$register(sm_pbu_unit, sm_dcte^.cnum, sm_unit_count,
                         sm_dcte^.disk_error_que_hi,
                         addr(sm_jump_table)));
  sm_$cinit := status_$ok;
  return;

failed:
  sm_$cinit := status_$io_controller_not_in_system;
  cb_bytes := addr(sm_$cb);
  for i := 1 to 336 do
    cb_bytes^[i] := chr(0);
end;
