{ SM_$INT - the storage module controller's interrupt routine.

  Image addresses:
    sau5  0x00E6F22A  SM_$INT

  - After a DMA parity error the drive's parity flag is set from
    PARITY_$CHK_IO on the command block's and the buffer's pages.
  - Returns 1 when the unit stopped (status bit 2; the drive is marked
    not ready), else 3, with the drive's eventcount given to the PBU to
    advance.

  Status stored: none.
}

function sm_$int: integer;
var
  unit: 0..3;
begin
  unit := sm_$cb.int_word.unit;
  with sm_$cb.drive[unit] do begin
    status := sm_$cb.int_word.all;
    sm_$cb.int_ack := 0;
    pbu_sm_page.go := sm_$cb.go_ack;
    if parity_$during_dma then
      parity_err := parity_$chk_io(sm_cb_ppn, sm_buf_ppn) <> 0;
    if 2 in status.bits then begin
      ready := false;
      sm_$int := 1;
    end
    else begin
      sm_pbu_info^.int_ec := addr(ec);
      sm_$int := 3;
    end;
  end;
end;
