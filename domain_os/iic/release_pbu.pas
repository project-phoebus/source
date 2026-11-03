{ iic_release_pbu - set the controller's PBU unit down and unwire the
  driver.

  Image addresses:
    sau3  0x00E71300  iic_release_pbu (module-local)

  - The unit's interrupts are disabled first; each step is taken only
    when the one before it succeeded.

  Status stored:
    pbu_$disable_device's status: the interrupts were not disabled
    pbu_$release_int's status: the unit was set down, or not
}

procedure iic_release_pbu(out status: status_$t); internal;
begin
  pbu_$disable_device(iic_pbu_unit, status);
  if status.all = status_$ok then begin
    pbu_$release_int(iic_pbu_unit, iic_pbu_sharing, status);
    if status.all = status_$ok then begin
      iic_pbu_acquired := false;
      iic_unwire_driver;
    end;
  end;
end;
