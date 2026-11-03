{ iic_setup_pbu - wire the driver and set the controller's PBU unit up.

  Image addresses:
    sau3  0x00E71346  iic_setup_pbu (module-local)

  - IIC_$INT becomes the unit's handler, the PBU's IIC page its CSR
    page; the unit's interrupts are then enabled.

  Status stored:
    pbu_$acquire_int's status: overwritten by the next
    pbu_$enable_device's status: the interrupts were enabled, or not
}

procedure iic_setup_pbu(out status: status_$t); internal;
begin
  iic_wire_driver;
  iic_pbu_acquired := true;
  pbu_$acquire_int(iic_pbu_unit, addr(iic_$int), nil, addr(pbu_iic_page),
                   16#6400, 1, iic_pbu_sharing, status);
  pbu_$enable_device(iic_pbu_unit, status);
end;
