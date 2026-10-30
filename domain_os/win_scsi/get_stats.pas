{ WIN_SCSI_$GET_STATS - the statistics entry.

  Image addresses:
    sau9  0x3C41C634  WIN_SCSI_$GET_STATS

  - A controller above 8 or a unit other than 0 gets zeros.
}

procedure win_scsi_$get_stats(cnum: pinteger; unit: integer;
                              out stats: win_scsi_stats_t);
var
  zero: win_scsi_stats_t;
  p: ^win_scsi_stats_t;
begin
  if (cnum > win_scsi_max_ctlr) or else (unit <> 0) then begin
    zero.reads := 0;
    zero.writes := 0;
    zero.unused_08 := 0;
    zero.unused_0a := 0;
    zero.seek_errors := 0;
    zero.equip_checks := 0;
    zero.not_ready := 0;
    zero.data_checks := 0;
    zero.unused_14 := 0;
    p := addr(zero);
  end
  else
    p := addr(win_scsi_units[cnum].luns[unit].stats);
  stats := p^;
end;
