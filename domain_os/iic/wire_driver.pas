{ iic_wire_driver - wire the driver's code and data.

  Image addresses:
    sau3  0x00E7129C  iic_wire_driver (module-local)

  - The IIC_AQWRD_PROC code through the IIC_AQWRD_DATA data; the pages
    go into iic_wire_list, 32 at most.

  Status stored: none.
}

procedure iic_wire_driver; internal;
begin
  mst_$wire_area(addr(iic_$proc_start), addr(iic_$data_end), iic_wire_list,
                 32, iic_wire_count);
end;
