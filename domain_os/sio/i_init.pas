{ SIO_$I_INIT - reset a new SIO descriptor's state.

  Image addresses:
    sau2  0x00E67E5E  SIO_$I_INIT
    sau4  0x0F871952  SIO_$I_INIT
    sau6  0x78070B3A  SIO_$I_INIT
    sau7  0x3C47B4A2  SIO_$I_INIT

  - The state, the pending conditions and the parameters' second flag
    set are cleared and the eventcount initialized.

  Status stored: none.
}

procedure sio_$i_init(var desc: sio_$desc_t);
begin
  desc.state := [];
  desc.pending_int := [];
  desc.params.flags2 := [];
  ec_$init(desc.ec);
end;
