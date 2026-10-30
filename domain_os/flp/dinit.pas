{ FLP_$DINIT - initialize a floppy drive.

  Image addresses:
    sau2  0x00E3E112  FLP_$DINIT

  - The FORMAT TRACK table's page is wired the first time.
  - The geometry and the label come back only when the recalibrate
    succeeded and num_blocks was not positive; the label's word at 6 is
    set to 1 on every path.

  Returns:
    status_$invalid_unit_number: the unit is above 3
    the recalibrate's status: otherwise

  Status stored: none.
}

{ TODO(pascal) FLP_$DINIT's label record copied from a constant in the code

  pvlabel_info is filled by a block copy from the 10 bytes after the
  routine's code, laid out with the routine's other cell as a by-address
  constant would be: so a 10-byte constant of the record's size assigned
  to it.  The reference has no record constants (no structured constant
  in a `const' part, no constructor; dpc refuses `r(...)' and `chr(..) +
  ..' alike), and a string constant cannot hold these bytes; a `static'
  variable would be in the data section, not the code.  The Pascal
  assigns the four fields (the same values; four stores in the code, not
  a copy). }

function flp_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; out num_heads: pinteger;
                    out pvlabel_info: flp_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(val_param);
var
  excs_vol: disk_$volume_t;
  ppn: integer32;
  status: status_$t;
  unused_54: integer32;                   { stand-in }
  unused_58: integer32;                   { stand-in }
begin
  if unit > 3 then begin
    flp_$dinit := status_$invalid_unit_number;
    return;
  end;

  flp_hw_addr := flp_ctlr_table[ctlr].hw_addr;

  { once, the FORMAT TRACK table's page }
  if not flp_initialized then begin
    ppn := mmu_$vtop(integer32(addr(flp_io_buffer)), status);
    wp_$wire(ppn);
    flp_fmt_buf_pa := lshft(ppn, 10) +
                      (integer32(addr(flp_io_buffer)) & 16#3FF);
    flp_initialized := true;
  end;

  { recalibrate }
  flp_hw_addr^.control := 3;
  excs_vol.as_options := [];
  flp_cmd_retry := 0;
  flp_recal_cmd[1] := unit;
  status.all := excs(flp_recal_cmd, 2, excs_vol);

  flp_unit_cyl[unit] := 0;
  flp_disk_change[unit] := false;

  { the geometry }
  if (status.all = status_$ok) and then (num_blocks <= 0) then begin
    flags := 0;
    sec_per_track := 8;
    num_heads := 2;
    num_blocks := 1232;
    pvlabel_info.l_00 := 16#9204B2;
    pvlabel_info.w_04 := 0;
    pvlabel_info.w_06 := 1;
    pvlabel_info.w_08 := 0;
  end;

  pvlabel_info.w_06 := 1;
  flp_$dinit := status.all;
end;
