{ MBUS_$INIT - set the Multibus interrupt vector and adapter up at boot.

  Image addresses:
    sau5  0x00E308FC  MBUS_$INIT

  - Levels 7..15 keep a nil handler until MBUS_$DEFINE_INT gives them
    one; the handlers' arguments are left as they are.
  - MBUS_$PRESENT is the adapter's answer to the probe; PBU_$INIT reads
    it and MBUS_$HIGH_OK afterwards.

  Status stored: none.
}

{ TODO(sau) MBUS_$INIT on the other SAUs with a Multibus

  The SAU3's, SAU4's and SAU6's MBUS_$INIT differ from this one: they
  install their bus's interrupt routine with IO_$TRAP (MBUS_$INT, which
  the SAU5 lacks: there VME_$INT dispatches the Multibus's levels), the
  SAU3 sets eight handlers and MBUS_$HIGH_OK from a bit of the probed
  register, and the third register's value and the first's bits differ.
  To be written as conditional arms when those images are translated. }

[section(os_init_proc, os_init_data)]
procedure mbus_$init;
var
  probe_data: integer;
  csr: integer;
  i: integer;
  ctl: ^mbus_$ctl_t;
begin
  { the first seven levels: no handler yet }
  for i := 0 to 6 do
    mbus_$int_vec[i].handler := addr(mbus_$undef_int);

  { is the adapter there }
  ctl := addr(pbu_ctl);
  mbus_$present := testpage(1, ctl, probe_data);
  csr := probe_data;

  { every level disabled, the adapter set up }
  if mbus_$present then begin
    mbus_$high_ok := true;
    ctl^.int_enable := [];
    ctl^.word_04 := 16#3D05;
    ctl^.word_00 := csr ! 16#213;
  end;
end;
