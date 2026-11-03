{ PBU_$GET_INFO - the PBU manager's information.

  Image addresses:
    sau3  0x00E590FE  PBU_$GET_INFO
    sau4  0x0F861D0A  PBU_$GET_INFO
    sau5  0x00E592CE  PBU_$GET_INFO
    sau8  0x03C6192A  PBU_$GET_INFO

  - The three words 1, pbu_info_2 and pbu_info_3: 2 and 1 on the
    Multibus SAUs (1 and 1 with the 64 KB Multibus map), 8 and 0 on the
    AT bus without the I/O map space.

  Status stored:
    status_$ok: the information was returned
    status_$pbu_bad_parameter: len is under 6 bytes
}

procedure pbu_$get_info(in len: pinteger; out info: pbu_$info_t;
                        out status: status_$t);
begin
  if len < 6 then
    status.all := status_$pbu_bad_parameter
  else begin
    info.info_1 := 1;
    info.info_2 := pbu_info_2;
    info.info_3 := pbu_info_3;
    status.all := status_$ok;
  end;
end;
