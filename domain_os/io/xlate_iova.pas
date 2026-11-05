{ IO_$XLATE_IOVA - translate a bus address through a unit's bus.

  Image addresses:
    sau2  0x00E1A970  IO_$XLATE_IOVA
    sau3  0x00E19A20  IO_$XLATE_IOVA
    sau4  0x0F81B5D8  IO_$XLATE_IOVA
    sau5  0x00E1ACD0  IO_$XLATE_IOVA
    sau6  0x7801C274  IO_$XLATE_IOVA
    sau7  0x3C41E4D8  IO_$XLATE_IOVA
    sau8  0x03C1BAF4  IO_$XLATE_IOVA

  - The result is the bus's xlate_iova answer, a physical page number;
    for a unit not acquired it is not set.

  Status stored:
    io_$check_unit's status: always
}

function io_$xlate_iova(unit: io_$unit_num_t; iova: linteger;
                        out status: status_$t): integer32;
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      io_$xlate_iova := io_$bus_epv[bus].xlate_iova^(iova);
end;
