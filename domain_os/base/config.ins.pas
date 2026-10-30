{ base/config.ins.pas - the SAU this kernel is compiled for, and the
  optional parts that SAU's kernel has, as conditional compilation
  variables.

  Apollo built one kernel source for every SAU: the SR10.2 install ships
  a kernel and a map for each of sau2..sau9, and the maps show the
  source's conditional parts (a module or a routine that is a stub on
  some SAUs and a body on others, modules only some maps have).  The
  language's conditional compilation expresses them (ref 4.7,
  pp. 4-43..4-50).

  Two kinds of variable (Apollo's names are not known):
  - one per SAU, `sau<N>': the Makefile passes `-config <sau>' (ref
    6.4.8, TARGET_SAU); a compile without it stops with the %error;
  - one per optional part, enabled by the SAU's bank.  Code tests the
    part, not the SAU, so a SAU added later needs only its bank.

  One `%enable' per line: dpc does not continue a directive's name list
  on the next line.  base/base.ins.pas includes this file once per
  module (`%var' twice is an error, ref p. 4-49).  SR10.3 and SR10.4's
  sau11, sau12 and sau14 belong to those releases' branches.

  The banks come from the SR10.2 maps' code segment sizes:

    part             module       sau2   sau3   sau4   sau5   sau6   sau7   sau8   sau9
    color4_driver    COLOR4        0x4    0x4    0x4    0x4    0x4  0xBC4  0xBC4    0x4
    color5_driver    COLOR5        0x4    0x4    0x4    0x4    0x4  0xCDC  0xCDC    0x4
    color7_driver    COLOR7        0x4    0x4    0x4    0x4    0x4 0x174C    0x4    0x4
    ct_driver        CT            0x4    0x4    0x4  0xE34 0x15D8 0x2768 0x1434 0x131C

    dma_driver       DMA_        0x130  0x130    0x4    0x4    0x4  0x508  0x4C0    0x4
    ethernet_driver  ETHERNET     0x10   0x10   0x10   0x10 0x48BC 0x4660 0x465C 0x4684
    gpu_driver       GPU          0x14   0x14   0x14 0x128C 0x1350   0x14   0x14   0x14
    mt_driver        MT            0x4 0x1440 0x1438 0x1448 0x1420    0x4    0x4    0x4

    pbu_driver       PBU          0x18 0x1ADC 0x1938 0x1FC0 0x1F7C 0x1CAC 0x18F0   0x18
                     (IO_$ALLOC's body goes with it: real on SAU3..8)
    scsi_driver      SCSI_        0x14   0x14   0x14   0x14   0x14 0x1CA8   0x14 0x2A48
    tape_boot        TAPE_BOOT    0x10   0x10   0x10  0xA68  0xA60  0xA60  0xA60  0xA60

  The modules some maps lack (COLOR, COLOR2, MBUS_, PBU_MAP, SM, SM_C,
  VME_) are a question for the build's module list, not for these
  banks; MONO9 has its part below (`mono9_display').
}

%var sau2 sau3 sau4 sau5 sau6 sau7 sau8 sau9
%var color4_driver color5_driver color7_driver ct_driver dma_driver
%var ethernet_driver gpu_driver mt_driver pbu_driver scsi_driver tape_boot

%if not %config %then
  %error('compile with -config <sau>, e.g. -config sau2 (domain_os/Makefile DPC_FLAGS)')
%endif

%if sau2 %then
  %enable dma_driver;
%endif
%if sau3 %then
  %enable dma_driver, mt_driver, pbu_driver;
%endif
%if sau4 %then
  %enable mt_driver, pbu_driver;
%endif
%if sau5 %then
  %enable ct_driver, gpu_driver, mt_driver, pbu_driver, tape_boot;
%endif
%if sau6 %then
  %enable ct_driver, ethernet_driver, gpu_driver, mt_driver;
  %enable pbu_driver, tape_boot;
%endif
%if sau7 %then
  %enable color4_driver, color5_driver, color7_driver, ct_driver;
  %enable dma_driver, ethernet_driver, pbu_driver, scsi_driver, tape_boot;
%endif
%if sau8 %then
  %enable color4_driver, color5_driver, ct_driver, dma_driver;
  %enable ethernet_driver, pbu_driver, tape_boot;
%endif
%if sau9 %then
  %enable ct_driver, ethernet_driver, scsi_driver, tape_boot;
%endif

{ ---- The parts of io, network, dtty, fim, peb, win and tape: each
  part's %var, its evidence in this comment's style, and its own %if
  sau<N> %then %enable ... %endif lines for every SAU that has it.
  ---- }

{ The buses, the controllers and the I/O map regions (io/).  Evidence,
  from the SR10.2 maps and images (SAU2..SAU9):

    part             evidence                                  SAUs
    vme_bus          VME_$INIT in the map, and in IO_$BUS_EPV    5 6
                     entry 1 with VME_$DEFINE_USERINT; an I/O
                     map for bus 1 in IO_'s data
    mbus_bus         MBUS_$INIT in the map; in IO_$BUS_EPV       3 4 5 6
                     entry 2 (with MBUS_$DEFINE_INT, and on the
                     SAU5 MBUS_$ENABLE_DEV, MBUS_$DISABLE_DEV);
                     an I/O map for bus 2
    sysbus_routines  SYSBUS_$INIT in the map; IO_$BUS_EPV entry  2 3 4 6 9
                     4 holds it and SYSBUS_$DEFINE_INT (on the
                     SAU5, 7 and 8 entry 4 has only csr_align);
                     the ring DCTE's vector word (0x1B on the
                     SAU2 and SAU3, 0 on the SAU5)
    smd_disk         SMD_DCTE_0 and SMD_DCTE_1 in the map;       3 4 5 6
                     IO_$GET_CONFIG tests CHK(4) (config bit 2)
    floppy_disk      FLP_DCTE in the map; IO_$GET_CONFIG tests   2 4 7 8
                     CHK(1) (config bit 1)
    pbu_mcb_config   IO_$GET_CONFIG adds member 1 to its third   5 6
                     word when PBU_$MCB's top bit is set (the
                     SAU4 assigns [0] instead: not this form)
    io_regions       IO_'s data has a free list of 0x10-byte     3 4 5 6 7
                     region nodes after IO_$WIRING_EXCLUSION,
                     its head after IO_$DCTE_LIST, built by
                     IO_$INIT; IO_$ALLOC_MAP and IO_$FREE_MAP use
                     it (the SAU8 has IO_$ALLOC_MAP, no list)
    few_io_regions   8 nodes (IO_$INIT's count; 0x80 bytes of    5 6
                     IO_'s data) instead of the 64 of the SAU3,
                     SAU4, SAU7 (0x400 bytes)
}

%var vme_bus mbus_bus sysbus_routines smd_disk floppy_disk
%var pbu_mcb_config io_regions few_io_regions

%if sau2 %then
  %enable sysbus_routines, floppy_disk;
%endif
%if sau3 %then
  %enable mbus_bus, sysbus_routines, smd_disk, io_regions;
%endif
%if sau4 %then
  %enable mbus_bus, sysbus_routines, smd_disk, floppy_disk, io_regions;
%endif
%if sau5 %then
  %enable vme_bus, mbus_bus, smd_disk, pbu_mcb_config;
  %enable io_regions, few_io_regions;
%endif
%if sau6 %then
  %enable vme_bus, mbus_bus, sysbus_routines, smd_disk, pbu_mcb_config;
  %enable io_regions, few_io_regions;
%endif
%if sau7 %then
  %enable floppy_disk, io_regions;
%endif
%if sau8 %then
  %enable floppy_disk;
%endif
%if sau9 %then
  %enable sysbus_routines;
%endif

{ The units' I/O descriptors (io/io_desc.pas).  Evidence, from the
  SR10.2 maps and images:

    part             evidence                                  SAUs
    io_descriptors   the map's IO_DESC module, data only in      7 8 9
                     WIRED_DATA after IO_'s block (0x1A0, 0x160,
                     0x1C0 bytes): the units' I/O descriptors,
                     which their DCTEs' disk_dinit cells point
                     at (the map's SCSI9_IO_DESC .. RING1_IO_DESC
                     on the SAU9)
}

%var io_descriptors

%if sau7 %then
  %enable io_descriptors;
%endif
%if sau8 %then
  %enable io_descriptors;
%endif
%if sau9 %then
  %enable io_descriptors;
%endif

{ The static DCTEs' form (io/dctes.pas).  Evidence, from the SR10.2
  maps and images:

    part          evidence                                        SAUs
    named_dctes   the map's DCTES block of 28 DCTEs of kind 2        9
                  (0x774 bytes), each with its unit's name
                  ("ring0", "win3", "sio1") and the PROM's device
                  record at 0x1C, eight per SCSI unit kind; the
                  SAU2's and SAU5's are kind 1 with neither, the
                  SAU7's kind 2 and kind 3 (0x3A4 bytes, not
                  written)
}

%var named_dctes

%if sau9 %then
  %enable named_dctes;
%endif

{ The bus interrupt routines (sysbus/, atbus/).  Evidence, from the
  SR10.2 maps and images:

    part             evidence                                  SAUs
    sysbus_int_vec   SYSBUS_$INT, SYSBUS_$UNDEF_INT and          4 6 9
                     SYSBUS_$INT_VEC in the map: SYSBUS_$INIT
                     traps a range of vectors to SYSBUS_$INT,
                     which calls the handler and argument
                     SYSBUS_$DEFINE_INT stored for the vector;
                     the SAU2's and SAU3's ATBUS_ has
                     RING_INTERRUPT (and DISK_INTERRUPT) instead
    util_pic         the map's UTIL_PIC, the utility interrupt       9
                     controller's registers: the map's
                     SYSBUS_$ENABLE_DEVICE, _DISABLE_DEVICE,
                     _DEVICE_INTERRUPTING and _CLEAR_PENDING
                     (also in IO_$BUS_EPV entry 4), and
                     SYSBUS_$INT disables the level around its
                     handler
    atbus_routines   the map's ATBUS_$ routines, a second ATBUS_   7 8 9
                     compilation unit (segments in WIRED_PROC,
                     WIRED_DATA with ATBUS_$INTLEV_VEC and
                     ATBUS_$INT_VEC, and OS_INIT_PROC with
                     ATBUS_$INIT); IO_$BUS_EPV entry 3 holds
                     them
}

%var sysbus_int_vec util_pic atbus_routines

%if sau4 %then
  %enable sysbus_int_vec;
%endif
%if sau6 %then
  %enable sysbus_int_vec;
%endif
%if sau7 %then
  %enable atbus_routines;
%endif
%if sau8 %then
  %enable atbus_routines;
%endif
%if sau9 %then
  %enable sysbus_int_vec;
  %enable util_pic;
  %enable atbus_routines;
%endif

{ The DN2500's monochrome display (mono9/).

    part             evidence                                  SAUs
    mono9_display    the map's MONO9 module (code segments in       9
                     WIRED_PROC, OS_INIT_PROC and .TEXT, a
                     WIRED_DATA block), MONO9_ASM, MONO9_DESC (in
                     the DCTES section) and the overlay section
                     MONO9_$WIRED_DATA; no other SR10.2 map has
                     them
}

%var mono9_display

%if sau9 %then
  %enable mono9_display;
%endif

{ The IEEE 802.5 token-ring driver (ring_8025/).

    part              evidence                                  SAUs
    ring_8025_driver  the map's RING_8025 module (code segment     7 8 9
                      in RING8025_PROC: 0x49A4, 0x471C, 0x4814
                      bytes; a data segment in RING8025_DATA),
                      the RING8025_UCB and RING8025_$AUX_DA
                      sections and the two units' DCTEs; the
                      SAU2..SAU6 maps have none of them (only
                      RING_8025_$NETWORK_UID, in UID_LIST's run)
}

%var ring_8025_driver

%if sau7 %then
  %enable ring_8025_driver;
%endif
%if sau8 %then
  %enable ring_8025_driver;
%endif
%if sau9 %then
  %enable ring_8025_driver;
%endif

{ The SCSI Winchester disk driver (win_scsi/).

    part             evidence                                  SAUs
    win_scsi_disk    the map's WIN_SCSI_ module (code segments      9
                     in WIRED_PROC and OS_INIT_PROC, a
                     WIRED_DATA block) and WIN_SCSI_DCTE_0..7
                     in the DCTES section; the SAU7's map has
                     the SCSI_ driver (`scsi_driver') but no
                     WIN_SCSI_, and no other SR10.2 map has it
}

%var win_scsi_disk

%if sau9 %then
  %enable win_scsi_disk;
%endif

{ The cartridge tape driver's forms (ct/), on the SAUs with `ct_driver'.

    part             evidence                                  SAUs
    ct_qic02         the map's CT_WAIT, RESET_DRIVE,             5 6 7 8
                     DO_CTL_CMD and CT_$INT in the CT
                     segment, and its CTAPE_DCTE: the driver
                     of a QIC-02 drive behind a tape
                     controller of its own
    ct_scsi          the map's SCSI_WAIT in the CT segment       7 9
                     (and on the SAU9 SCSI_CTAPE_DCTE_0..7,
                     no CT_$INT): the driver of a SCSI tape
                     drive through the SCSI_ driver; its
                     globals test for the drive first, and
                     the SAU7's run the QIC-02 code otherwise
}

%var ct_qic02 ct_scsi

%if sau5 %then
  %enable ct_qic02;
%endif
%if sau6 %then
  %enable ct_qic02;
%endif
%if sau7 %then
  %enable ct_qic02;
  %enable ct_scsi;
%endif
%if sau8 %then
  %enable ct_qic02;
%endif
%if sau9 %then
  %enable ct_scsi;
%endif

{ The request servers (network/).

    part                 evidence                              SAUs
    two_request_servers  NETWORK_$ADD_REQUEST_SERVERS limits     5
                         the count to 2, where the other SAUs'
                         code limits it to 3; the
                         routine is otherwise the same, and the
                         NETWORK segments have the SAU2's sizes
}

%var two_request_servers

%if sau5 %then
  %enable two_request_servers;
%endif

{ The display TTY's displays (dtty/).

    part                 evidence                              SAUs
    second_display_unit  DTTY_$INIT asks SMD_$INQ_DISP_TYPE      4 5
                         about display unit 2 when unit 1 has
                         none, and takes its two color types
                         (smd_$color_display, smd_$800_color);
                         the SAU2, SAU6..SAU9 code has no unit-2
                         inquiry, the SAU3's DTTY_$INIT is a
                         0x1C-byte stub
  The SAU5's color2 and color3 arms (DN580, DN570) go with
  `gpu_driver' (above): the SAU5's and SAU6's DTTY_$INIT have them, and
  their maps' GPU code segments are the real driver.
}

%var second_display_unit

{ The terminal lines and the keyboard (term/, kbd/, tone/, sio/).
  Evidence, from the SR10.2 maps and images:

    part             evidence                                  SAUs
    kbd_tone         the keyboard sounds the tone: TONE_$ENABLE   6 7 8 9
                     sends one of two 3-byte commands of
                     OS_TERM_INIT's block (16#FF 16#21 16#81 or
                     16#82) through KBD_$PUT, where the SAU2..SAU5
                     call SIO2681_$TONE on the speaker's channel
                     (the SAU6's tests a display register first:
                     not expressed); KBD_$RESET writes two reset
                     bytes to the keyboard's serial channel, an
                     empty procedure on the SAU2..SAU5;
                     TONE_$TIME sounds it again for each 75000
                     ticks of the time (the same code on the
                     SAU6..SAU9)
    kbd_key_ring_512 the keyboard descriptor's key ring holds    6 7 8 9
                     512 characters (KBD_$INIT's size word; the
                     console's transmit buffer after it at
                     +0x25E, 64 characters, the descriptor 0x2A4
                     bytes), 64 on the SAU2, SAU4, SAU5
    sio16550_lines   the map's SIO_IO module is SIO16550_, four      9
                     ports (SIO0_DCTE..SIO3_DCTE): its
                     SIO16550_$INIT calls SIO_$INIT for each,
                     which records the console's channel in
                     OS_TERM_INIT's block, and TERM_$INIT only
                     starts the tablet (SUMA_$INIT); the block
                     (0x1A8C bytes) has four TTY and SIO
                     descriptors and no SIO6509 or SIO2681
                     records; KBD_$RESET waits on the 16550's
                     line status; TERM_$PCHIST_ENABLE sets the
                     fourth DTTE's channel's flags; the SAU2's
                     OS_INIT_DATA segment of TERM_$INIT's tables
                     is absent
    kbd_commands     the keyboard driver sends the keyboard         6 7 8 9
                     commands: KBD's code 0x6FC bytes in
                     WIRED_PROC and 0x16C in PROCEDURE$, its data
                     0x108 in WIRED_DATA and 0x14 in DATA$ (0x4F0,
                     0xEC, 0xD4 and none on the SAU2, SAU4,
                     SAU5); kbd_$put_line copies a string into
                     the console's transmit buffer and starts the
                     line, waiting on the line's eventcount while
                     the buffer is full (empty on the SAU2,
                     SAU4, SAU5);
                     KBD_$SET_KBD_MODE sends a mode command,
                     KBD_$GET_CHAR_AND_MODE once an 18-byte
                     command; KBD_$RCV has arms for actions 7, 8,
                     9, 13 and 14 and the state table 36 entries
                     (10); KBD_$INIT records the descriptor at
                     +0xBC, which KBD_$CRASH_INIT resets (an
                     empty procedure there); the SAU3's KBD is
                     another form
}

%var kbd_tone kbd_key_ring_512 sio16550_lines kbd_commands

%if sau6 %then
  %enable kbd_tone;
  %enable kbd_key_ring_512;
  %enable kbd_commands;
%endif
%if sau7 %then
  %enable kbd_tone;
  %enable kbd_key_ring_512;
  %enable kbd_commands;
%endif
%if sau8 %then
  %enable kbd_tone;
  %enable kbd_key_ring_512;
  %enable kbd_commands;
%endif
%if sau9 %then
  %enable kbd_tone;
  %enable kbd_key_ring_512;
  %enable kbd_commands;
  %enable sio16550_lines;
%endif

{ The Winchester controller (win/).

    part                 evidence                              SAUs
    winchester_ctlr      the map's WIN_ module (code in WIRED_PROC  2 3 4 5 6 7 8
                         and OS_INIT_PROC, a WIRED_DATA block):
                         the Winchester controller's driver; the
                         SAU9's disks are SCSI (`win_scsi_disk')
                         and its map has no WIN_
    win_descriptor_ctlr  the WIN_ module drives a controller        5
                         that takes a list of transfer
                         descriptors in its window: the map's
                         WIN_ symbols RESTORE, SEEK,
                         RETRY_DATA_CHECK, WIN_$FIXES,
                         WIN_$RESTORES, WIN_$DT, WIN_$TIMEOUT_ST;
                         the SAU2's ANSI-command driver has
                         DISK_INIT, WIN_$KTHUNKD, WIN_$ATTN,
                         WIN_$CSTAT, WIN_$SENSE instead; every other
                         SAU's WIN_ code differs from both
                         (WIN_$DO_IO, WIN_$INT and WIN_$DINIT have
                         four forms: sau2 | sau4 | sau5 | sau6)
}

%var winchester_ctlr win_descriptor_ctlr

%if sau2 %then
  %enable winchester_ctlr;
%endif
%if sau3 %then
  %enable winchester_ctlr;
%endif
%if sau4 %then
  %enable winchester_ctlr;
%endif
%if sau5 %then
  %enable winchester_ctlr;
%endif
%if sau6 %then
  %enable winchester_ctlr;
%endif
%if sau7 %then
  %enable winchester_ctlr;
%endif
%if sau8 %then
  %enable winchester_ctlr;
%endif
%if sau5 %then
  %enable win_descriptor_ctlr;
%endif

%if sau4 %then
  %enable second_display_unit;
%endif
%if sau5 %then
  %enable second_display_unit;
%endif

{ ---- The parts of sm, sm_c, mbus, vme and mt: as above. ---- }

{ long_iomap: the I/O map entries the storage module drivers write are
  longwords, the physical page number plus 16#48000.  The SR10.2 images:
  SM_$CINIT, SM_$DINIT and SM_$DO_IO add 16#48000 and store a longword
  into IOMAP's entries on the SAU5 and SAU6; the SAU3's same routines
  differ from the SAU5's only there, adding 16#8000 to the page number's
  low word and storing a word; the SAU4's store a word elsewhere
  (SM_$DINIT).  The SAUs without the storage module drivers (SAU2,
  SAU7..SAU9) have none of these routines. }
%var long_iomap
%if sau5 %then
  %enable long_iomap;
%endif
%if sau6 %then
  %enable long_iomap;
%endif

{ ---- The parts of mt and ct: as above. ---- }

{ ---- The parts of ring and os: as above. ---- }

{ The ring controller (ring/).  Evidence, from the SR10.2 maps and
  images (RING_$INT, RING_$SENDP, RING_$GET_ID, RING_$SVC_WRITE):

    part                 evidence                              SAUs
    ring_controller_dma  the ring controller moves its packets   5 6
                         itself: the header's and the data's
                         addresses and word counts are registers
                         of its block (+0x20 .. +0x3E), which
                         ring_$process_rx_packet,
                         RING_$RCV_FROM_UNIT_PRIV and the two
                         set-up routines read and write, and
                         there is no ring_$clear_dma_channel; the
                         SAU2 and SAU3 code drives three channels
                         of the DMA controller (`dma_driver')
                         instead; the SAU4's ring driver
                         (RING_$RCV_INT) and the SAU7..SAU9's
                         (RING8_$INT) are other forms
    ring_vector_regs     ring_$init_internal stores the vector     5
                         word 16#3D00 into the controller's
                         registers at +0x40, +0x48 and +0x50 (the
                         SAU5's RING_DCTE has no vector); the
                         SAU6's stores 16#0D00 and 16#1B00 (the
                         first register's by a mode bit), after
                         SYSBUS_$DEFINE_INT: not this form
    ring_owner_test_reversed
                         RING_$SVC_WRITE tests the packet type's   5 7 8 9
                         owner as `channel <> owner' (the
                         channel the left operand, loaded first);
                         the SAU2, SAU3, SAU4 and SAU6 code has
                         `owner <> channel'
  The operand order changes no behavior; it is kept as the evidence that
  the SAUs' sources were not one text throughout (one compiler gives
  one order for one expression).

    part                 evidence                              SAUs
    ring8_controller     the ring controller has its packet    7 8 9
                         buffers and a command block of its
                         own: the map's RING8_$INT (no
                         RING_$INT), RING_$CCB at the start of
                         the RING_DATA block (0xAB0 bytes, two
                         0x4A4-byte unit records), RING_ASM's
                         RING_$RB_FROM and RING_$RB_TO, and
                         RING's OS_INIT_DATA block (0xB0 bytes);
                         its registers are words from +0x400 to
                         +0x1C06 of the CSR pages the DCTE's I/O
                         descriptor maps (RING_$POLL_STICKY_BPHERR
                         reads the status at +0x1400 and clears
                         the error at +0x400)
    nodeid_prom          RING_$GET_ID reads the node id from       9
                         the map's NODE_ID (IODEFS), bytes +0,
                         +9, +0x11 and +0x19, and crashes the
                         system with 16#0011001F when it is wider
                         than 20 bits; the SAU7's and SAU8's
                         read other PROM words (not expressed),
                         the SAU2..SAU6 take the id from the ring
                         controller's registers
}

%var ring_controller_dma ring_vector_regs ring_owner_test_reversed
%var ring8_controller nodeid_prom

%if sau5 %then
  %enable ring_controller_dma;
  %enable ring_vector_regs;
  %enable ring_owner_test_reversed;
%endif
%if sau6 %then
  %enable ring_controller_dma;
%endif
%if sau7 %then
  %enable ring_owner_test_reversed;
  %enable ring8_controller;
%endif
%if sau8 %then
  %enable ring_owner_test_reversed;
  %enable ring8_controller;
%endif
%if sau9 %then
  %enable ring_owner_test_reversed;
  %enable ring8_controller;
  %enable nodeid_prom;
%endif

{ The start-up and the shutdown (os/).  Evidence, from the SR10.2 maps
  and images (OS_$INIT and OS_$SHUTDOWN, per SAU):

    part              evidence                                 SAUs
    power_off_check   the map's OS_$INIT_POWER_OFF_CHECK (in   3 4 5 6
                      OS_INIT_PROC; OS_$INIT calls it) and
                      OS_$CHECK_POWER_OFF (WIRED_PROC), with
                      an OS data block in WIRED_DATA (0x20
                      bytes): a time queue element whose
                      callback watches MMU_$POWER_OFF
    power_down        OS_$SHUTDOWN ends, when the volumes shut     4 5 6
                      down well and MMU_$POWER_OFF is set, with
                      "Beginning power down sequence...", the
                      disks spun down and the interrupts
                      disabled; then each SAU's own power
                      register (the SAU4 MMU_$SET_CSR, the SAU5
                      `vme_power_off', the SAU6 another word)
    vme_power_off     that register on the SAU5: bit 3 of the      5
                      word at +0x30 of VME_CTL cleared
    disp2_probe       OS_$INIT probes for a second display and     4 5 6
                      installs DISPLAY2_$UID's ASTE when one
                      answers; the map's DISP2_PRESENT (in
                      CRASH_SYSTEM's data) holds the answer
    color_board       the map's COLOR_$COLD_INIT and               4 5
                      COLOR_$SHUTDOWN: OS_$INIT calls the first
                      and probes the color board as the second
                      display when the first probe fails,
                      OS_$SHUTDOWN calls the second
    crash_reboot      the map's CRASH and CRASH_$OK_TO_REBOOT      3 4 6 7 8 9
                      (CRASH_SYSTEM's data): OS_$INIT allows the
                      reboot unless boot flag 15 is set, and a
                      server's node check stores the PROM's
                      restart code 243 in the OS .DATA word at
                      +0xC (OS_$SHUTTING_DOWN_FLAG after it, at
                      +0xE: the map's address); OS_$SHUTDOWN
                      ends in CRASH with that code when the
                      volumes and its status are good
    ring_node_id      OS_$INIT takes NODE_$ME from                 2 3 4 5 6
                      RING_$GET_ID(0) after IO_$INIT; the SAU7..
                      SAU9 code has no such call
    smd_display_memory
                      OS_$INIT calls SMD_$INSTALL_DISP_MEM         7 8 9
                      where the other SAUs probe the display
                      with TESTPAGE and make its ASTE
                      (OS_$INSTALL_DISPLAY_ASTE), and
                      SMD_$COLD_INIT after LOG_$INIT;
                      OS_$SHUTDOWN calls SMD_$SHUTDOWN after
                      CAL_$SHUTDOWN; DTTY_$INIT takes unit 1's
                      sizes from SMD_$INQ_DISP_INFO (no display
                      type kept), its window is cleared with
                      SMD_$CLEAR_SCREEN, which has no parameter
                      (the DTTY code segment is the same on the
                      SAU7..SAU9)
    calendar_service_mode
                      OS_$INIT passes `not SERVER_$FLAG' as        7 8 9
                      CAL_$VERIFY's third argument; on a
                      failure a refused calendar of a
                      non-server shuts the volumes down and
                      crashes, else the node asks for service
                      mode and CALENDAR and blinks the lights
                      for ever (two MMU_$MCR_CHANGE calls)
    fim_nmi           the map's FIM_$NMI: the vector table          6 7 9
                      installs it for vector 31; the SAU2,
                      SAU3, SAU5 and SAU8 maps have
                      FIM_$PARITY_TRAP instead, which the SAU2,
                      SAU3, SAU5 code stores into vector 31
                      after DTTY_$INIT (the SAU4 has neither,
                      the SAU8 another store: not expressed)
    vector_alignment_check
                      OS_$INIT checks every installed              7 9
                      handler's address for the low two bits
                      before PROC1_$INHIBIT_END and crashes
                      with 16#001B0009 ("exception handler is
                      not longword-aligned")
    prom_config_record
                      OS_$INIT takes a third parameter, the          9
                      PROM's 0x38-byte configuration record,
                      whose fields give the terminal's
                      parameters, SERVER_$FLAG, the tape boot
                      and TIME_$SYS_FREQ (set before TIME_$INIT,
                      which with PROC1_$INIT moves ahead of
                      PEB_$INIT), and whose address
                      IO_$INIT and the map's IO_$LOG_SELF_TESTS
                      get; the boot record's unit is set to 1
                      and only it is stored in OS_$BOOT_DEVICE,
                      VOLX_$MOUNT reads the device from there;
                      NETWORK_$DISKLESS from boot flag 7, no
                      NET_IO_$BOOT_DEVICE
    shutdown_kbd_mode OS_$SHUTDOWN calls TERM_$CONTROL with        6 7 8 9
                      line 0, the keyboard-mode option (36) and
                      0 after the display's shutdown
  Reused: `tape_boot' (boot device 5 is a tape boot: PROC2_$INIT's
  mode gets proc2_$boot_from_tape; SAU5..SAU8 have the test, the SAU9's
  boot record is another form throughout); `vme_bus' (the vector table's
  VME_$INT and VME_$ERR_INT for vectors 28 and 29); `pbu_driver'
  (PBU_$TRAP6 for trap 6, PBU_$SHUTDOWN); `gpu_driver' (the graphic
  device id: DISPLAY3_$UID, COLOR2_$COLD_INIT, COLOR2_$SHUTDOWN,
  GPU_$COLD_INIT); `boot_time_lock' (the calendar probe through
  IO_$GET_DCTE, the crash of a disked node without a calendar and the
  time fetched from the mother node: OS_$INIT calls IO_$GET_DCTE,
  CAL_$CLOCK_TO_SEC and SUB48 on the SAU2 and SAU5 only); `pft_mmu'
  (MMU_$INIT, AS_$INIT, MMU_$REMOVE of COLD's two pages and
  MMU_$SET_PROT for the type-4 protections and the vector page, where
  the other SAUs call MMU_$REMOVE_SPECIAL_SEG for COLD's segment,
  MMU_$PAGE_WRITE_BIT and MMU_$PURGE and set the type-4 segments'
  descriptors in SMAPS; the SAU8 calls AS_$INIT too: not expressed;
  OS_$INSTALL_DISPLAY_ASTE's AST_$PMAP_ASSOC, AST_$ASSOC_IOPPN and
  MMU_$PURGE elsewhere); `large_vm' (SERVER_$FLAG, ANDed into the node
  check's automatic shutdown, and MEM_$INIT after IO_$INIT: the
  SAU4, SAU6..SAU9 maps and code); `large_address_space' (COLD's
  RARS entry cleared, also on the SAU6; the page maps of the two
  unused global ranges freed by a module-local routine, os_$free_gap_pmaps,
  the SAU7's and SAU9's OS_INIT_PROC run before OS_$INIT 0x22E bytes);
  `pmmu_page_maps' (the paging loop and OS_$INSTALL_DISPLAY_ASTE clear
  the resident bit of the page descriptors in OS_PMAPS they mapped).
}

%var power_off_check power_down vme_power_off disp2_probe color_board
%var crash_reboot ring_node_id smd_display_memory calendar_service_mode
%var fim_nmi vector_alignment_check prom_config_record shutdown_kbd_mode

%if sau2 %then
  %enable ring_node_id;
%endif
%if sau3 %then
  %enable crash_reboot;
  %enable ring_node_id;
%endif
%if sau4 %then
  %enable crash_reboot;
  %enable ring_node_id;
%endif
%if sau5 %then
  %enable ring_node_id;
%endif
%if sau6 %then
  %enable crash_reboot;
  %enable ring_node_id;
  %enable fim_nmi;
  %enable shutdown_kbd_mode;
%endif
%if sau7 %then
  %enable crash_reboot;
  %enable smd_display_memory;
  %enable calendar_service_mode;
  %enable fim_nmi;
  %enable vector_alignment_check;
  %enable shutdown_kbd_mode;
%endif
%if sau8 %then
  %enable crash_reboot;
  %enable smd_display_memory;
  %enable calendar_service_mode;
  %enable shutdown_kbd_mode;
%endif
%if sau9 %then
  %enable crash_reboot;
  %enable smd_display_memory;
  %enable calendar_service_mode;
  %enable fim_nmi;
  %enable vector_alignment_check;
  %enable prom_config_record;
  %enable shutdown_kbd_mode;
%endif

%if sau3 %then
  %enable power_off_check;
%endif
%if sau4 %then
  %enable power_off_check;
  %enable power_down;
  %enable disp2_probe;
  %enable color_board;
%endif
%if sau5 %then
  %enable power_off_check;
  %enable power_down;
  %enable vme_power_off;
  %enable disp2_probe;
  %enable color_board;
%endif
%if sau6 %then
  %enable power_off_check;
  %enable power_down;
  %enable disp2_probe;
%endif

{ ---- The parts of smd and gpu: as above. ---- }

{ The display driver's displays (smd/).  Evidence, from the SR10.2 maps
  and images (SMD_$REL_DISPLAY, SMD_$WS_INIT, SMD_$INIT; the SMD data
  segments' sizes):

    part               evidence                                SAUs
    two_display_units  two display unit records of 0x110 bytes   4 5 6
                       (one of 0x10C on the SAU2) in the overlay
                       section SMD_$WIRED_DATA (0x250 bytes, the
                       SAU2's 0x13C); a second font table and
                       free list in SMD's .DATA block (0x1E58
                       bytes, the SAU2's 0x1DA8); two blink
                       routines (the map's SMD_$BLINK_CURSOR_2);
                       the unit loops run to 2.  The SAU7..SAU9's
                       SMD_$WIRED_DATA (0x8E0, 0x900 bytes) is
                       another form; the SAU3 has no SMD driver
    color_displays     the driver knows the color display types  4 5 6
                       3..6: SMD_$WS_INIT, SMD_$UTIL_INIT,
                       SMD_$INVERT_S, SMD_$BLT, SMD_$SOFT_SCROLL
                       and SMD_$EOF_WAIT answer them with
                       smd_$not_on_color (16#00130027, six sites
                       in each of the three images)
    blt_request_start  SMD_$BLT passes the caller's BLT request      4 5 6
                       itself to the hand-written SMD_$START_BLT
                       (its address the first argument) and
                       refuses only the main-memory modes; the
                       SAU2's builds the controller's parameter
                       words in its frame, refuses non-conforming
                       areas too, and passes those (the SAU4's
                       routine has main-memory BLTs besides:
                       SMD_$BLT's three forms, sau2 | sau4 | sau5,
                       sau6)
    display_devices    the driver drives up to eight display units   7 8 9
                       through their devices' descriptors and
                       routine vectors: the map's SMD_$ADD_DEVICE
                       and SMD_$NOP_* (the vector's defaults, in
                       SMD's OS_INIT_DATA block of 0x88 bytes),
                       unit records of 0x114 bytes in an
                       SMD_$WIRED_DATA of 0x8E0 (the SAU7's 0x900)
                       with the unit count at its end, eight
                       display records in SMD_$DISPLAY_COM; no
                       SMD_$BLT, SMD_$WS_INIT and the other drawing
                       and font routines, no SMD_WIRED code; the
                       map's hand-written COLOR4_ASM
                       (COLOR4_$LOAD_LUT, COLOR4_$END_WIRED_PROC;
                       color4/m68k/color4_asm.s), in the SAU7..SAU9
                       maps only
  Reused: `color_board' (the SAU4's and SAU5's COLOR_ module: SMD calls
  COLOR_$LOAD_CRSR, _$DISSOC, _$SHUTDOWN and _$VIDEO_CTL for display
  types 3 and 4); `gpu_driver' (the SAU5's and SAU6's COLOR2_ module and
  the graphics board: SMD_$INIT reads SMD_$GRAPHIC_DEVICE_ID, SMD calls
  COLOR2_$LOAD_CRSR, _$DISSOC, _$SHUTDOWN and _$VIDEO_CTL for types 5
  and 6, and type 6's hidden memory starts at offset 5, the constant
  16#00050357 in both images).
}

%var two_display_units color_displays blt_request_start display_devices

%if sau7 %then
  %enable display_devices;
%endif
%if sau8 %then
  %enable display_devices;
%endif
%if sau9 %then
  %enable display_devices;
%endif
%if sau4 %then
  %enable two_display_units;
  %enable color_displays;
  %enable blt_request_start;
%endif
%if sau5 %then
  %enable two_display_units;
  %enable color_displays;
  %enable blt_request_start;
%endif
%if sau6 %then
  %enable two_display_units;
  %enable color_displays;
  %enable blt_request_start;
%endif

{ ---- The parts of pbu, pbu_map, color and color2: as above. ---- }

{ ---- Parts added for the SAU5 hand assembly (*/m68k/*.s, the `.if'
  arms; tools/gen_asm_config.py writes them to base/config.inc). ----

    part                      evidence                              SAUs
    crash_report_blank_lines  the crash reports' templates have extra      5
                              line feeds: FIM_$CRASH's starts
                              "\r\n\r\n\n\nFAULT IN DOMAIN/OS:"
                              and CRASH_SYSTEM's report block
                              "\n\n\n\r\r\nCrash_Status" on the SAU5;
                              "\r\n\r\nFAULT IN DOMAIN/OS:" and
                              "\r\nCrash_Status" on the SAU2..SAU4 and
                              SAU6..SAU9 (each image file's only copy
                              of the two strings)
    calendar_word_port        TIME_$READ_CAL's body (TIME_ASM, no map      5
                              symbol) reaches the MSM5832 calendar
                              through a word at +0x200 of its page:
                              control +0x200, digits read at +0x201
                              uninverted, the leap-year flag written
                              as a word; the SAU2's body uses bytes at
                              +0x20 control, +0x22 write, +0x24 read
                              (inverted); the SAU3's and SAU4's bodies
                              have other offsets (+0x0, +0x81) and the
                              SAU8's another chip's sequence (the
                              bodies' first bytes in each image; the
                              SAU6, SAU7 and SAU9 bodies not compared);
                              CAL_$WRITE_CALENDAR writes each digit as
                              one word there (select high, digit low,
                              strobe 16#200), the SAU2's as bytes at
                              +0x22 and +0x20
    calendar_indexed_rtc      the calendar is a clock chip of numbered     9
                              registers, the number written to the
                              map's CAL (16#3FF9F280), the register at
                              CAL + 4: CAL_$WRITE_CALENDAR (0x110
                              bytes) sets registers 10, 13, 11 and the
                              binary time in 0..9, and TIME_ASM's
                              calendar read is that chip's
                              (cal/sau9/, time/sau9/)
  Reused: `pbu_driver' (fim/m68k/bus_err.s: CPU_B_PBU_SWITCH, a map
  symbol of exactly the pbu_driver SAUs' maps, SAU3..SAU8, and
  FIM_$BUS_ERR's PBU fault path; fim/m68k/spurious_int.s: the distance
  those bytes add ahead of FIM_$SPURIOUS_INT; svc/m68k/svc_tables.s:
  the dispatch entries of the PBU_ and PBU2_ calls); `color_board',
  `gpu_driver', `mt_driver', `ct_driver' (svc/m68k/svc_tables.s: the
  entries of the COLOR_, COLOR2_ and GPU_, MT_ and CT_ calls, which the
  SAUs without the driver fill with SVC_$UNIMPLEMENTED); `disp2_probe'
  (misc/m68k/crash_system.s: the map's DISP2_PRESENT, SAU4..SAU6);
  `gpu_driver' (misc/m68k/crash_system.s: the SAU5's REMAP_DISPLAY,
  which quiets the graphics board and maps its memory, 0x100 bytes as
  the SAU6's).
}

%var crash_report_blank_lines calendar_word_port

%if sau5 %then
  %enable crash_report_blank_lines;
  %enable calendar_word_port;
%endif

%var calendar_indexed_rtc

%if sau9 %then
  %enable calendar_indexed_rtc;
%endif

{ The virtual memory tables (ast/, mmap/, mst/, area/, pmap/).  Evidence,
  from the SR10.2 maps and images:

    part                evidence                                  SAUs
    large_vm            28-byte ASTEs (the map's AST: 0x1C bytes  4 6 7 8 9
                        per 0x80-byte page map of AST_PMAPS),
                        each holding its page map's physical
                        address (AST_$ADD_ASTES); 14-bit ASTE
                        hints (AST_$LOCATE_ASTE); 21-bit disk
                        addresses in the MMAP entries
                        (AST_$FREE_PAGES); 20-byte ASTEs, 9-bit
                        hints and 22-bit addresses elsewhere
    vm_5760_astes       5760 ASTEs and 1280 AOTEs (the map's AST,     6 7 9
                        AOT and AST_PMAPS; the limits of
                        AST_$ADD_ASTES and AST_$ADD_AOTES); 504
                        and 280 on the SAU2, SAU3, SAU5 (the
                        SAU4's 2432 ASTEs and the SAU8's 1536
                        are not expressed yet)
    pmap_threads        MST_$UNTHREAD_PMAP in the map: an ASTE     6 7 8 9
                        heads the thread of the MST entries that
                        point at its page map (+0x10), which
                        ast_$deactivate_segment ends; MST_$FIND and
                        MST_$WIRE always fault the page in
    pmmu_page_maps      the page maps' entries are MC68030 page      7 8 9
                        descriptors: the frame in bits 31..10,
                        the flags in the low word (AST_$PTOV,
                        AST_$REMOVE_PAGE and AST_$ALLOC_CONTIG
                        in the map; AST_$INVALIDATE_PAGE calls
                        MMU_$PURGE, not MMU_$REMOVE; MMAP_$ALLOC_CONTIG
                        has a body); FIM_$BUILD_DF stores the
                        MMU's MMU_$BUS_STATUS (FIM_WIRED's word,
                        in the SAU6 map too but unread there) as
                        the fault's information word
    pmap_cache_inhibit  the page maps' pages are cache-inhibited     7 9
                        (AST_$ADD_ASTES), and AST_$CACHE_INHIBIT_PPN
                        and AST_$CACHE_ENABLE_PPN are in the map
    large_address_space the regions' segments are constants: private   7 9
                        A 30336, global A 256 from 30336, private
                        B 128 from 30592, global B 2048 from 30720
                        of 32768 (MST_$VA_TO_SEGNO, AS_$GET_ADDR;
                        no MST_$SEG_* variables in the map)
    mmap_ppns_10000     the pageable pages are 16#10000..16#1FFFF      9
                        (the map's MMAP, 0x100000 bytes of 16 per
                        page; AST_$PTOV's range), the page entries'
                        list links 22-bit fields (MMAP_$FREE_LIST);
                        16#200..16#FFF on the SAU2, SAU3, SAU5 (the
                        other SAUs' ranges differ again: not
                        expressed yet)
}

%var large_vm vm_5760_astes pmap_threads pmmu_page_maps
%var pmap_cache_inhibit
%var mmap_ppns_10000 large_address_space

%if sau4 %then
  %enable large_vm;
%endif
%if sau6 %then
  %enable large_vm;
  %enable pmap_threads;
  %enable vm_5760_astes;
%endif
%if sau7 %then
  %enable large_vm;
  %enable pmap_threads;
  %enable vm_5760_astes;
  %enable pmmu_page_maps;
  %enable pmap_cache_inhibit;
  %enable large_address_space;
%endif
%if sau8 %then
  %enable large_vm;
  %enable pmap_threads;
  %enable pmmu_page_maps;
%endif
%if sau9 %then
  %enable large_vm;
  %enable pmap_threads;
  %enable vm_5760_astes;
  %enable pmmu_page_maps;
  %enable pmap_cache_inhibit;
  %enable mmap_ppns_10000;
  %enable large_address_space;
%endif

{ The start-up of the page purifiers (pmap/, os/).  Evidence, from the
  SR10.2 images:

    part                evidence                                  SAUs
    boot_time_lock      PMAP_$PURIFIER_L and PMAP_$PURIFIER_R      2 5
                        start with ML_$LOCK and ML_$UNLOCK of lock
                        1 (ml_$mt_lock), waiting for OS_$INIT, which
                        holds that lock while a node without a
                        calendar takes the time from its mother
                        node; the SAU3, SAU4 and SAU6..SAU9 have
                        neither the purifiers' pair nor OS_$INIT's
}

%var boot_time_lock

%if sau2 %then
  %enable boot_time_lock;
%endif
%if sau5 %then
  %enable boot_time_lock;
%endif

{ The MMU and the caches (mmu/, cache/; the hand assembly's `.if' arms).
  Evidence, from the SR10.2 maps and images:

    part                evidence                                  SAUs
    pft_mmu             the page frame table and page translation  2 3 5
                        table MMU: the map's MMU_ASM is 0x5B8
                        bytes, with MMU_$PID_PRIV, M68020,
                        MMU_$INIT, MMU_$REMOVE_LIST, MMU_$PTOV,
                        MMU_$SET_CSR and MMU_$CLR_USED, the same
                        code on the three (tools/sau_catalog.py):
                        mmu/m68k/*.s; the SAU4 and SAU6..SAU9 have
                        their own MMU_ASM (the SAU9's
                        mmu/sau9/mmu_asm.s); the MC68010 SAUs:
                        FIM_$BUILD_DF takes the 68010's bus error
                        frame (format 8) only there
    cacr_clear_data     CACHE_$FLUSH_VIRTUAL clears the MC68030        9
                        data cache (CACR bit 11); a bare `rts' on
                        the SAU2..SAU6 and SAU8 (the SAU7's tests
                        M68030 first: not expressed)
}

%var pft_mmu cacr_clear_data

%if sau2 %then
  %enable pft_mmu;
%endif
%if sau3 %then
  %enable pft_mmu;
%endif
%if sau5 %then
  %enable pft_mmu;
%endif
%if sau9 %then
  %enable cacr_clear_data;
%endif

{ The FPU's enable (fim/m68k/, fp/m68k/).  Evidence, from the SR10.2
  images:

    part                evidence                                  SAUs
    fpu_enable_ccr      FIM_$FP_INIT, FIM_$FP_GET_STATE and the FP     9
                        owner switch set and clear bit 7 of the
                        map's MMU_CCR (16#3FF9F2D0) where the SAU2,
                        SAU3, SAU5 write the FPU owner register
                        (16#FFB402); the SAU6 sets bit 7 of
                        16#7FFFB409, the SAU4, SAU7, SAU8 other
                        code (not compared)
}

%var fpu_enable_ccr

%if sau9 %then
  %enable fpu_enable_ccr;
%endif

{ The memory parity statistics (mem/).  Evidence, from the SR10.2 maps
  and images:

    part                evidence                                  SAUs
    mem_ccr_board_size  the map's MEM_ code is MEM_$INIT and           9
                        MEM_$PARITY_LOG (0x104 bytes): the board
                        size, 4 or 16 MB, from bit 3 of MMU_CCR
                        (16#3FF9F2D0); MEM_$INIT counts the boards
                        from MEM_$SIZE, MEM_$PARITY_LOG counts an
                        error against its address div the board
                        size and matches a page record by its whole
                        address; MEM_$MEM_REC's first word 16#2B (2
                        on the SAU2, SAU3, SAU5); the SAU2, SAU3,
                        SAU5 have MEM_$PARITY_LOG alone (0xB8
                        bytes), the SAU4 and SAU6..SAU8 other MEM_
                        code (tools/sau_catalog.py)
}

%var mem_ccr_board_size

%if sau9 %then
  %enable mem_ccr_board_size;
%endif

{ The memory parity errors (parity/).  Evidence, from the SR10.2 maps
  and images:

    part                evidence                                  SAUs
    parity_err_regs     PARITY_$CHK reads the failing byte lanes          9
                        from the map's MMU_BESR (four bits, all set
                        when none failed) and the page from
                        MMU_PEARH and MMU_PEARL (pages from
                        16#10000), sets bit 4 of MMU_CCR around
                        CACHE_$CLEAR and bit 2 while PAR_BUFF maps
                        the page, takes the page's address and
                        ASID from AST_$PTOV and scans 256 words of
                        PAR_BUFF for the lane; the SAU2, SAU3, SAU5
                        read the MMU page's error word or longword
                        and the PFT, the SAU7 and SAU8 other
                        registers (tools/sau_catalog.py)
    parity_dma_pages    the map's PARITY_$DMA_TABLE (0x18C bytes:         9
                        three channels of 32 page numbers, a count
                        and a flag) and PARITY_$SET_STATE, which
                        notes a channel's pages; PARITY_$CHK_IO
                        takes the channel and PARITY_$CHK flags the
                        channel holding the failing page; no
                        PARITY_$DURING_DMA (the SAU2, SAU3, SAU5's
                        4-byte PARITY data); the SAU7's and SAU8's
                        table has two pages a channel (0x24 bytes,
                        PARITY_$SET_STATE takes the two): not this
                        form
}

%var parity_err_regs parity_dma_pages

%if sau9 %then
  %enable parity_err_regs;
  %enable parity_dma_pages;
%endif

{ The floating-point hardware (peb/, xpd/).  Evidence, from the SR10.2
  maps and images:

    part                evidence                                  SAUs
    peb_board           the Performance Enhancement Board's            2 5
                        driver: the map's PEB_PARITY code
                        (PEB_$TEST_PARITY_ERR), PEB_ASM (PEB_$INT),
                        PEB_UNWIRED's .TEXT segment (PEB_$ASSOC ..
                        PEB_$PUT_FP) and its WCS writer and reader,
                        PEB_WIRED's 0x22C bytes (PEB_$LOAD_REGS,
                        PEB_$UNLOAD_REGS, PEB_$GET_FP, PEB_$PUT_FP) and
                        its data (PEB_$REGS, 0x658 bytes), and XPD_KER's
                        FP routines testing PEB_$INFO (a 68881 first,
                        else the board); elsewhere PEB_UNWIRED is
                        PEB_$INIT and PEB_$LOAD_WCS for the MC68881
                        alone (0x1D8 bytes on the SAU3, SAU8, SAU9; the
                        SAU6's 0x244 and the SAU7's 0x410 not compared;
                        the SAU4 has none), PEB_WIRED 0x60 bytes
                        (PEB_$TOUCH false, PEB_$GET_INFO),
                        PEB_$PROC_CLEANUP an empty procedure, and
                        XPD_$FP_PUT_STATE, _FP_GET_STATE, _GET_FP_INT
                        and _PUT_FP_INT go straight to FIM_ and FP_
                        (tools/sau_catalog.py)
}

%var peb_board

%if sau2 %then
  %enable peb_board;
%endif
%if sau5 %then
  %enable peb_board;
%endif

{ The exception vector page (the PROM's cells, arch/, dtty/m68k/).
  Evidence, from the SR10.2 maps and images:

    part                evidence                                  SAUs
    trap_page_high      the map's TRAP_PAGE (0x400 bytes, the        7 9
                        vector page and the PROM's entry cells
                        from 0x100) is in the kernel's data,
                        where the other maps have it at 0: the
                        hand-written DTTY_WIRED reaches the
                        PROM's putc, font reload and clear cells
                        absolute long at TRAP_PAGE + 0x108, 0x114,
                        0x140 (0x4C bytes on the SAU9, the SAU2's
                        0x48 with absolute short operands)
}

%var trap_page_high

%if sau7 %then
  %enable trap_page_high;
%endif
%if sau9 %then
  %enable trap_page_high;
%endif

{ The interrupts' PC histogram (io/m68k/).  Evidence, from the SR10.2
  maps and images:

    part                    evidence                              SAUs
    interrupt_pc_histogram  the map's HISTOGRAM_ADDRESS (a 4-byte        9
                            IO_$TBLS segment in the wired data):
                            the first-level interrupt dispatcher
                            stores the interrupted PC there; the
                            other SAUs' dispatcher has no such store
}

%var interrupt_pc_histogram

%if sau9 %then
  %enable interrupt_pc_histogram;
%endif

{ The lights drawn on the display (misc/m68k/).  Evidence, from the
  SR10.2 maps and images:

    part                evidence                                  SAUs
    display_lights      the map's DISP_LITES, a hand-written data    2 5 6
                        segment of 0xD4 bytes in the wired area:
                        SMD_$LITES's routine that draws the 16
                        lights into the first display's memory
                        (misc/m68k/disp_lites.s); the SAU3's is 4
                        bytes and the SAU4's 0xE8, other forms;
                        the SAU7..SAU9 maps have no DISP_LITES
}

%var display_lights

%if sau2 %then
  %enable display_lights;
%endif
%if sau5 %then
  %enable display_lights;
%endif
%if sau6 %then
  %enable display_lights;
%endif

{ The null process (os/m68k/).  Evidence, from the SR10.2 images:

    part                evidence                                  SAUs
    null_process_spins  NULLPROC's idle loop forces IPL 0 and      4 6 7 8 9
                        branches back: the null process spins;
                        the SAU2, SAU3, SAU5 loop on the stop
                        instruction (os/m68k/nullproc.s)
}

%var null_process_spins

%if sau4 %then
  %enable null_process_spins;
%endif
%if sau6 %then
  %enable null_process_spins;
%endif
%if sau7 %then
  %enable null_process_spins;
%endif
%if sau8 %then
  %enable null_process_spins;
%endif
%if sau9 %then
  %enable null_process_spins;
%endif

{ The kernel's first translation tables (os/cold.pas).  Evidence, from
  the SR10.2 maps and images:

    part                evidence                                  SAUs
    cold_proc_tables    the map's OS_COLD module: its code in the      7 9
                        COLD_PROC section (OS_$COLD_START), its data
                        (the boot map) in COLD, both run by COLD
                        before the MMU is on; the SAU7's another
                        form (0x728 and 0x15C bytes, not compared)
}

%var cold_proc_tables

%if sau7 %then
  %enable cold_proc_tables;
%endif
%if sau9 %then
  %enable cold_proc_tables;
%endif

{ The hardware timers (timer/, time/).  Evidence, from the SR10.2 maps
  and images:

    part                evidence                                  SAUs
    timer_dcte          the map's TIMER_DCTE (DCTES) names               9
                        TIMER_$INIT its initialization routine
                        (IO_$INIT's device walk calls it; TIME_$INIT
                        does not): TIMER_$INIT sets the map's TIMER
                        block (IODEFS, not TIMR) up from
                        TIME_$SYS_FREQ, programs the real-time
                        counter with 4167, and enables the
                        interrupts 16#A9..16#AB
                        (SYSBUS_$ENABLE_DEVICE); the other maps have
                        TIMR and no TIMER_DCTE
}

%var timer_dcte

%if sau9 %then
  %enable timer_dcte;
%endif

{ The network buffers (netbuf/).  Evidence, from the SR10.2 maps and
  images:

    part                  evidence                                SAUs
    netbuf_cache_inhibit  NETBUF_$ADD_PAGES and NETBUF_$GET_HDR      7 9
                          make each header page uncached
                          (MMU_$CACHE_INHIBIT_VA) once it is in the
                          window, before they clear it; the
                          SAU2..SAU6 and SAU8 code has no such call
}

%var netbuf_cache_inhibit

%if sau7 %then
  %enable netbuf_cache_inhibit;
%endif
%if sau9 %then
  %enable netbuf_cache_inhibit;
%endif
