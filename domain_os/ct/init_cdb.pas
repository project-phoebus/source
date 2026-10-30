{ ct_init_cdb - clear the command block for the next command.

  Image addresses:
    sau9  0x3C47728C  ct_init_cdb (module-local)

  - Sets ct_cmd_cdb's logical unit and clears its other fields but the
    operation code, which the caller sets.

  Status stored: none.
}

procedure ct_init_cdb; internal;
begin
  ct_cmd_cdb.t.lun := ct_lun;
  ct_cmd_cdb.t.rest := 0;
  ct_cmd_cdb.t.len := 0;
  ct_cmd_cdb.t.control := 0;
end;
