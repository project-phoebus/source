%if ct_scsi %then
{ CT_$RELEASE - release the cartridge tape unit.

  Image addresses:
    sau9  0x3C478310  ct_scsi_release (nested)
    sau9  0x3C4783D6  CT_$RELEASE

  - For a drive that is set up: with mode, an outstanding command is
    ended with a reset (10 seconds' wait); then the sense and mode
    answers are unwired, the SCSI device released and the unit given up.
  - The module's code and data are unwired unless a command is
    outstanding.
  - Without a drive that is set up, nothing is stored.
  - The frame holds the QIC-02 arm's dma_status, PBU_$DMA_STOP's status
    in the SAU7's copy (at -4), which this arm does not use.

  Status stored:
    status_$ok: the unit was released
    ct_check_unit's result: the unit may not be used (an outstanding
      command without mode)
    ct_scsi_reset's or SCSI_WAIT's result: those failed
    SCSI_$UNWIRE's or SCSI_$RELEASE's status: those failed
}

procedure ct_$release(in unit: integer; in mode: boolean;
                      out status_ret: status_$t);
var
  dma_status: status_$t;                  { the QIC-02 arm's }

  { ct_scsi_release - release a drive that is set up. }
  procedure ct_scsi_release;
  var
    st2: status_$t;
    st1: status_$t;
  begin
    status_ret.all := ct_check_unit(unit);
    if (status_ret.all = status_$ct_operation_in_progress) and then mode then
    begin
      status_ret.all := ct_scsi_reset;
      status_ret.all := scsi_wait(ct_scsi_timeout, false);
    end;
    if status_ret.all = 0 then begin
      scsi_$unwire(ct_handle, ct_sense, ct_scsi_wired_len, true, st1);
      scsi_$release(ct_handle, st2);
      ct_owner := 0;
    end;
    if status_ret.all = 0 then
      status_ret := st1;
    if status_ret.all = 0 then
      status_ret := st2;
    if not ct_busy then
      ct_unwire_pages(ct_area_pages, ct_area_flags, ct_area_count);
  end;

begin
  if ct_scsi_state = ct_scsi_present then
    ct_scsi_release;
end;
%elseif ct_atbus_qic02 %then
{ CT_$RELEASE - release the cartridge tape unit.

  Image addresses:
    sau8  0x03C7B23A  CT_$RELEASE

  - With the AT bus adapter (`ct_atbus_qic02'): an operation in
    progress is no error; with mode the adapter is reset (960 ticks'
    wait with quit), and a successful reset marks a command outstanding.
  - The DMA channel is stopped and the PBU unit given up
    (PBU_$RELEASE_INT); the module's code and data are unwired unless a
    command is outstanding, and the ownership given up.

  Status stored:
    pbu_$release_int's status: the unit was released, or the PBU unit
      not given up
    ct_check_unit's result: the unit may not be used
}

procedure ct_$release(in unit: integer; in mode: boolean;
                      out status_ret: status_$t);
var
  dma_status: status_$t;
begin
  status_ret.all := ct_check_unit(unit);
  if status_ret.all = status_$ct_operation_in_progress then begin
    if mode then begin
      reset_drive;
      status_ret.all := ct_wait(960, true);
      ct_busy := status_ret.all = 0;
    end;
    status_ret.all := 0;
  end;
  if status_ret.all = 0 then begin
    dma_$stop(ct_dma_channel, ct_residue, dma_status);
    pbu_$release_int(ct_pbu_unit, 3, status_ret);
    if not ct_busy then
      ct_unwire_pages(ct_area_pages, ct_area_flags, ct_area_count);
    ct_owner := 0;
  end;
end;
%elseif ct_qic02 %then
{ CT_$RELEASE - release the cartridge tape unit.

  Image addresses:
    sau2  0x00E70AF4  CT_$RELEASE
    sau5  0x00E77AF8  CT_$RELEASE

  - With the QIC-02 driver (`ct_qic02'): an operation in progress is no error;
    with mode the controller is reset (960 ticks' wait with quit).
  - The module's code and data are then unwired unless a command is
    outstanding, and the ownership given up.
  - Without the driver (the SAU2) an empty procedure.
  - A successful reset marks a command outstanding.

  Status stored:
    status_$ok: the unit was released
    ct_check_unit's or ct_wait's result: those failed
}

procedure ct_$release(in unit: integer; in mode: boolean;
                      out status_ret: status_$t);
begin
  status_ret.all := ct_check_unit(unit);
  if status_ret.all = status_$ct_operation_in_progress then begin
    if mode then begin
      ct_reading := true;
      status_ret.all := do_ctl_cmd(ct_cmd_reset, 0);
      status_ret.all := ct_wait(960, true);
      ct_busy := status_ret.all = 0;
    end;
    status_ret.all := 0;
  end;
  if status_ret.all = 0 then begin
    if not ct_busy then
      ct_unwire_pages(ct_area_pages, ct_area_flags, ct_area_count);
    ct_owner := 0;
  end;
end;
%else
procedure ct_$release(in unit: integer; in mode: boolean;
                      out status_ret: status_$t);
begin
end;
%endif
