{ BAT_$N_FREE - return a volume's free and total block counts.

  Image addresses:
    sau2  0x00E3B9E4  BAT_$N_FREE

  - The counts are read under the BAT lock.
  - The failure path also stores the two counts.

  Status stored:
    status_$ok: the counts were returned
    status_$bat_not_mounted: a really diskless node, a volume index of 0
      or above 6, or a volume not mounted
}

{ TODO(pascal) the volume index compared unsigned against the integer heading

  `vol_idx > 6' is compared unsigned, the form of a 0..65535 value; a
  signed integer would compare signed (dpc does, from this heading).
  The reviewed heading (bat/bat.ins.pas, VOLX's) has `in vol_idx:
  integer', and VOLX_$GET_INFO passes its own integer parameter's copy
  by address (volx/get_info.pas), so the parameter's type is not changed
  here.  A pinteger formal would explain the unsigned compare; whether
  VOLX's integer may then be passed to it by address (ref 5.3, the
  argument and formal types of a by-reference parameter) is not
  settled. }

procedure bat_$n_free(in vol_idx: integer; out free_out: integer32;
                      out total_out: integer32; out status: status_$t);
var
  local_status: status_$t;
  free_blocks: linteger;
  total_blocks: linteger;
begin
  if network_$really_diskless then begin
    status.all := status_$bat_not_mounted;
    return;
  end;

  ml_$lock(ml_$bat_lock);
  if (vol_idx = 0) or else (vol_idx > 6)
     or else not bat_$mounted[vol_idx] then
    local_status.all := status_$bat_not_mounted
  else begin
    free_blocks := bat_data[vol_idx].hdr.free_blocks;
    total_blocks := bat_data[vol_idx].hdr.total_blocks;
    local_status.all := status_$ok;
  end;

  ml_$unlock(ml_$bat_lock);
  free_out := free_blocks;
  total_out := total_blocks;
  status := local_status;
end;
