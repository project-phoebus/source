{ MBUS_$INIT - set the Multibus interrupt vector and adapter up at boot.

  Image addresses:
    sau3  0x00E2E0FC  MBUS_$INIT
    sau5  0x00E308FC  MBUS_$INIT

  - Levels 7..15 keep a nil handler until MBUS_$DEFINE_INT gives them
    one; the handlers' arguments are left as they are.
  - With the polled adapter (`mbus_polled_adapter') MBUS_$INT is
    installed for the Multibus's vector first, levels 0..7 get
    MBUS_$UNDEF_INT, MBUS_$HIGH_OK is bit 5 of the probed register and
    the adapter's third register is left alone.
  - MBUS_$PRESENT is the adapter's answer to the probe; PBU_$INIT reads
    it and MBUS_$HIGH_OK afterwards.

  Status stored: none.
}

{ TODO(sau) MBUS_$INIT on the SAU4 and SAU6

  The SAU4's and SAU6's MBUS_$INIT install MBUS_$INT with IO_$TRAP for
  each level's own vector (16#B0 plus the level: eight on the SAU4,
  seven on the SAU6); the SAU4's probes another register and clears
  MBUS_$HIGH_OK, the SAU6's stores 16#1B05 in the third register.  To be
  written as conditional arms when those images are translated. }

[section(os_init_proc, os_init_data)]
procedure mbus_$init;
var
  probe_data: integer;
  csr: integer;
  i: integer;
  ctl: ^mbus_$ctl_t;
begin
%if mbus_polled_adapter %then
  io_$trap(mbus_$int_vector, addr(mbus_$int));

  { the first eight levels: no handler yet }
  for i := 0 to 7 do
    mbus_$int_vec[i].handler := addr(mbus_$undef_int);
%else
  { the first seven levels: no handler yet }
  for i := 0 to 6 do
    mbus_$int_vec[i].handler := addr(mbus_$undef_int);
%endif

  { is the adapter there }
  ctl := addr(pbu_ctl);
  mbus_$present := testpage(1, ctl, probe_data);
  csr := probe_data;

  { every level disabled, the adapter set up }
  if mbus_$present then begin
%if mbus_polled_adapter %then
    mbus_$high_ok := (csr & 16#20) <> 0;
    ctl^.int_enable := [];
    ctl^.word_00 := csr ! 16#293;
%else
    mbus_$high_ok := true;
    ctl^.int_enable := [];
    ctl^.word_04 := 16#3D05;
    ctl^.word_00 := csr ! 16#213;
%endif
  end;
end;
