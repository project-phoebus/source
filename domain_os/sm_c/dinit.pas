{ SM_C_$DINIT - bring an SM_C drive up.

  Image addresses:
    sau3  0x00E6F4C2  SM_C_$DINIT
    sau4  0x0F87C280  SM_C_$DINIT
    sau5  0x00E75026  SM_C_$DINIT
    sau6  0x7807BD3C  SM_C_$DINIT

  - The driver is wired, and the first time the controller set up; a
    failure there crashes the system.
  - The drive is brought up under the controller's ML lock; the result
    is sm_c_$start_drive's status.

  Status stored: none.
}

function sm_c_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     var sec_per_track: pinteger; var num_heads: pinteger;
                     out pvlabel_info: univ disk_$pvlabel_info_t;
                     out flags: pinteger): integer32;
  options(val_param);
var
  status: status_$t;
  cb_pa: sm_c_$pa_t;
  hi: sm_$byte_t;
  result_status: integer32;
begin
  sm_c_$wire;
  if not sm_c_started then begin
    sm_c_cb_ppn := mmu_$vtop(integer32(addr(sm_$cb)), status);
    if status.all <> 0 then
      crash_system(status);
%if long_iomap %then
    iomap[sm_c_iomap_index] := sm_c_cb_ppn + sm_iomap_bias;
%elseif word_iomap %then
    iomap[sm_c_iomap_index] := sm_c_cb_ppn;
%else
    iomap[sm_c_iomap_index].entry := sm_c_cb_ppn + sm_iomap_bias;
%endif
    cb_pa.all := (integer32(addr(sm_$cb)) & 16#3FF) + sm_c_alloc;
    pbu_sm_c_page.addr0 := 0;
    sm_c_$delay;
    hi := rshft(cb_pa.b1, 4);
    pbu_sm_c_page.addr1 := hi;
    sm_c_$delay;
    pbu_sm_c_page.addr2 := cb_pa.b3;
    sm_c_$delay;
    pbu_sm_c_page.addr3 := cb_pa.b2;
    sm_c_$delay;
    sm_$cb.c_op := 8;
    sm_$cb.c_mode_unit.mode := 1;
    sm_$cb.c_b0e := 0;
    sm_$cb.c_buf_hi := hi;
    sm_c_hdr_hi.all := sm_$cb.c_buf_hi;
    sm_c_hdr_lo.all := 16#E0;
    sm_c_hdr_mid.all := 3;
    pbu_sm_c_page.cmd := sm_c_reg_ack;
    pbu_$enable_device(sm_pbu_unit, status);
    if status.all <> 0 then
      crash_system(status);
    sm_c_started := true;
  end;

  ml_$lock(sm_c_dcte^.disk_error_que_hi);
  result_status := sm_c_$start_drive(unit, sm_c_dcte, num_blocks,
                                     sec_per_track, num_heads,
                                     pvlabel_info, flags);
  ml_$unlock(sm_c_dcte^.disk_error_que_hi);
  sm_c_$dinit := result_status;
end;
