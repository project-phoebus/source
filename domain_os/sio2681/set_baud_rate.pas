{ sio2681_set_baud_rate - program a channel's clock select register.

  Image addresses:
    sau2  0x00E1D1DA  sio2681_set_baud_rate (module-local)
    sau3  0x00E1C34E  sio2681_set_baud_rate (module-local)
    sau4  0x0F81E3EE  sio2681_set_baud_rate (module-local)
    sau8  0x03C1E90A  sio2681_set_baud_rate (module-local)

  Assume we're called with the driver's spin lock held.

  - The chip's baud-rate set (bit 7 of its ACR shadow) becomes extended,
    and the clock select byte the transmit rate's code (low nibble) and
    the receive rate's (high nibble).
  - The channel records the transmit rate's support bits.

  Status stored: none.
}

procedure sio2681_set_baud_rate(var channel: sio2681_$channel_t;
                                rates: sio2681_$rates_t;
                                extended: boolean); internal;
var
  csr: sio2681_$csr_t;
  chip: sio2681_$chip_ptr_t;
begin
  chip := channel.chip;
  chip^.config1.extended := extended;

  csr.tx := baud_codes[rates.tx];
  csr.rx := baud_codes[rates.rx];

  chip^.regs^.ipcr_acr := chip^.config1.acr;
  channel.regs^.sra_csra := csr.c;
  channel.baud_support := baud_bits[rates.tx];
end;
