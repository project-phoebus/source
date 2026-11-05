{ ct_decode_status - the status of the command the controller ended.

  Image addresses:
    sau5  0x00E76FAC  ct_decode_status (module-local)
    sau6  0x7807DD24  ct_decode_status (module-local)

  - From the controller's and the drive's status words (ct_cstat,
    ct_dstat): the controller's error bits first (7, 6, 5, 3, 2, 1),
    then with bit 8 the drive's status through the module's table.
  - With bit 8 the controller's two counters are added to CT_$DIAG's
    totals (not with the second controller, whose counts CT6_$INT
    totals).

  Returns:
    0: the command succeeded
    the controller error's status: an error bit of the controller
    the table's status: a drive status the table matches
    status_$ct_unrecognized_drive_status: one it does not
    status_$ct_unrecognized_controller_status: no error bit and no
      bit 8

  Status stored: none.
}

function ct_decode_status: integer32; internal;
label
  1;
var
  i: integer;
  status: integer32;
begin
  if (ct_cstat.all & (-16#4C01)) = 16#200 then begin  { 16#B3FF }
    ct_decode_status := 0;
    return;
  end;

  if ct_cst_dma_range in ct_cstat.bits then
    status := status_$ct_dma_not_at_end_of_range
  else if ct_cst_dma_overrun in ct_cstat.bits then
    status := status_$ct_dma_underrun_overrun
  else if ct_cst_dma_parity in ct_cstat.bits then
    status := status_$ct_dma_parity_error
  else if ct_cst_illegal_cmd in ct_cstat.bits then
    status := status_$ct_illegal_controller_command
  else if ct_cst_timeout in ct_cstat.bits then
    status := status_$ct_controller_timeout
  else if ct_cst_diag_failed in ct_cstat.bits then
    status := status_$ct_controller_diag_failed
  else if (ct_cstat.all & 16#100) <> 0 then begin
    { the drive's status }
    if ct_reading then begin
      ct_dstat.bits := ct_dstat.bits - [12];
      if (ct_dstat.all & 16#7F00) = 0 then
        ct_dstat.bits := ct_dstat.bits - [15];
      if ct_dstat.all = 0 then begin
        ct_decode_status := 0;
        return;
      end;
    end;
    for i := 1 to 18 do
      if (ct_dstat.all & ct_status_map[i].mask) = ct_status_map[i].value
      then begin
        status := ct_status_map[i].status;
        goto 1;
      end;
    status := status_$ct_unrecognized_drive_status;
  end
  else
    status := status_$ct_unrecognized_controller_status;

1:
%if win6_ct6_board %then
  if ct6_page = nil then
%endif
  if (ct_cstat.all & 16#100) <> 0 then
    with ct_regs^ do begin
      ct_total_2c := ct_total_2c + count_2c;
      ct_total_2e := ct_total_2e + count_2e;
    end;
  ct_decode_status := status;
end;
