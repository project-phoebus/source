{ MBUS_$DISABLE_DEV - disable a Multibus interrupt level.

  Image addresses:
    sau5  0x00E0AD68  MBUS_$DISABLE_DEV

  - The level is not checked.
  - A fragment of the VME_ module (vme/vme.pas), whose code segment holds
    it last.

  Status stored: none.
}

procedure mbus_$disable_dev(id: io_$int_id_t);
  options(val_param);
begin
  pbu_ctl.int_enable := pbu_ctl.int_enable - [id.vector];
end;
