{ base/config.ins.pas - the SAU this kernel is compiled for, and the
  optional parts that SAU's kernel has, as conditional compilation
  variables.

  Apollo built one kernel source for every SAU, with parts that only
  some SAUs' kernels have: a module that is a driver on some SAUs and a
  stub on others, a routine or a data structure with more than one
  form.  The language's conditional compilation expresses them (ref
  4.7, pp. 4-43..4-50).

  Two kinds of variable:
  - one per SAU, `sau<N>': the Makefile passes `-config <sau>' (ref
    6.4.8, TARGET_SAU); a compile without it stops with the %error;
  - one per optional part, declared below with what it means and
    enabled in its SAUs' blocks at the end of the file.  Code tests the
    part, not the SAU, so a SAU added later needs only its block.

  One `%enable' per line: dpc does not continue a directive's name list
  on the next line.  base/base.ins.pas includes this file once per
  module (`%var' twice is an error, ref p. 4-49).
}

%var sau2 sau3 sau4 sau5 sau6 sau7 sau8 sau9

%if not %config %then
  %error('compile with -config <sau>, e.g. -config sau2 (domain_os/Makefile DPC_FLAGS)')
%endif

{ The drivers: each is a module that holds the driver with its part and
  a stub, or nothing, without it.

    color4_driver    the COLOR4 display driver (color4/).
    color5_driver    the COLOR5 display driver (color5/).
    color6_driver    the COLOR6 display driver (color6/), the Matrox
                     board's (display type 12), and its three units'
                     DCTEs (COLOR6_DCTE), which DEV_DCTES lists.
    color7_driver    the COLOR7 display driver (color7/), the coyote
                     board's (display type 14), and its DCTE
                     (COLOR7_DCTE), which DEV_DCTES lists.
    ct_driver        the cartridge tape driver (ct/), its place in
                     IO_$GET_CONFIG, and the CT_ system calls.
    dma_driver       the DMA controller's driver (dma/), set up by
                     IO_$INIT: the MC68450's, or with `atbus_dma' the
                     AT bus's.
    atbus_dma        the AT bus's two DMA controllers' driver (dma/):
                     DMA_$START, DMA_$START_NCHECK, DMA_$STOP and
                     DMA_$STATUS for their channels, DMA_$FREE_ASID's
                     release of an address space's channels, and
                     DMA_$INIT in OS_INIT_PROC.
    atbus_dma_iomap  with `atbus_dma': the channels reach memory through
                     the I/O map: DMA_$START refuses
                     (status_$dma_start_not_supported), DMA_$START_NCHECK
                     takes a bus address of the map's window from
                     16#80000 and writes no page register, a cascade
                     channel is enabled in the master enable register
                     (MAST_ENBL_REG + 16#200) by DMA_$START_NCHECK and
                     disabled by DMA_$STOP, and the CPU status register
                     is read between the controllers' accesses
                     (dma_io_wait, which dma_io_delay reads too).
    ethernet_driver  the Ethernet controller's driver (ethernet/), its
                     units' DCTEs and its place in IO_$GET_CONFIG.
    gpu_driver       the graphics processor's driver (gpu/) and the
                     COLOR2_ board's routines (color2/): display types 5
                     and 6 in SMD and the display TTY, their start-up
                     and shutdown in os/, the graphics board's quieting
                     in CRASH_SYSTEM, and the GPU_ and COLOR2_ system
                     calls.
    mono_driver      the MONO monochrome display driver (mono/) and its
                     four units' DCTEs (MONO_DCTE), which DEV_DCTES
                     lists.
    mt_driver        the magnetic tape driver (mt/) and the MT_ system
                     calls.
    pbu_driver       the PBU driver, the user-device manager (pbu/,
                     pbu_map/), with IO_$ALLOC's body, the PBU's path in
                     the bus error handler, PBU_$TRAP6 for trap 6,
                     PBU_$SHUTDOWN, and the PBU_ and PBU2_ system calls.
    scsi_driver      the SCSI controller's driver (scsi/).
    tape_boot        the boot from cartridge tape (tape/): TAPE_$BOOT
                     loads the boot shell from the tape, and boot device
                     5 gives the process manager its tape-boot mode.
}

%var color4_driver color5_driver color6_driver color7_driver ct_driver
%var dma_driver
%var atbus_dma atbus_dma_iomap
%var ethernet_driver gpu_driver mono_driver mt_driver pbu_driver scsi_driver
%var tape_boot

{ The buses, the controllers and the I/O map regions (io/).

    vme_bus          the VME bus (vme/): its entry in IO_$BUS_EPV, its
                     I/O map, VME_$INT and VME_$ERR_INT for vectors 28
                     and 29 (other vectors with `vme_vectored_ints'),
                     and the PBU's units 8..15 on the bus.
    vme_vectored_ints
                     with `vme_bus': the turbo boards' VME adapter: its
                     user interrupts 8..15 come on vectors 16#F8..16#FF,
                     which VME_$INIT traps to VME_$INT, and VME_$INT
                     calls the handler VME_$DEFINE_USERINT stored for
                     the vector.  The other form's interrupt levels,
                     VME_$DEFINE_INT, VME_$USER_INT and VME_$ERR_INT are
                     not in the module, and VME_$SAVE_VME and VME_$SAVE
                     are hand assembly (VME_ASM).
    mbus_bus         the Multibus (mbus/): its entry in IO_$BUS_EPV and
                     its I/O map.
    sysbus_routines  SYSBUS_$INIT and SYSBUS_$DEFINE_INT in the system
                     bus's IO_$BUS_EPV entry, and the ring DCTE's
                     interrupt vector.
    smd_disk         the storage module disk drivers (sm/, sm_c/), their
                     DCTEs, and the controller in IO_$GET_CONFIG.
    sm_c_clear_go    with `smd_disk': SM_C_$INT goes on with a chain's
                     next request by clearing the controller (16#10) as
                     it takes the request and giving the go command
                     (16#80) once the command block is set up, where the
                     other form gives the continue command (16#90).
    floppy_disk      the floppy disk driver (flp/), its DCTE, and the
                     drive in IO_$GET_CONFIG.
    floppy_atbus     with `floppy_disk': the floppy controller on the
                     AT bus, its ports from the CSR page IO_$MAP_CSR
                     maps, its transfers on DMA channel 2 of the AT
                     bus's controllers (`atbus_dma'), its interrupt
                     through IO_$ACQUIRE when a drive is first
                     initialized, the drives' motor switched off by a
                     time-queue callback, and each write read back
                     into a page of its own to compare.
    floppy_page_dma  with `floppy_disk': the floppy controller's
                     registers at its page's start and its transfers on
                     the DMA controller of its own page (its +16#80)
                     through IOMAP's entries 0 and 1; its interrupt
                     through IO_$ACQUIRE (with `floppy_dcte_request'),
                     and the DMA's count checked after a transfer
                     instead of DMA_$CHECK and a parity check.
    floppy_iomap     with `floppy_atbus': the floppy's DMA reaches
                     memory through the AT bus's I/O map: FLP_$DINIT
                     takes a 2 KB region (IO_$ALLOC_MAP) and FLP_$SHUTDOWN
                     frees it; a transfer's page and the format table's
                     page are mapped into it for the transfer (IOMAP_$MAP,
                     IOMAP_$UNMAP); the overrun page and the transfer
                     page are cache-inhibited.
    floppy_long_delays
                     with `floppy_atbus': the controller's delay loops
                     are twice as long (the settling spins of FLP_$INT
                     and SHAKE, FLP_$INT's ready polls, the reset's hold
                     in FLP_$CINIT and FLP_$DINIT).
    pbu_mcb_config   IO_$GET_CONFIG reports the PBU (member 1 of the
                     third set) when PBU_$MCB's flag is set.
    io_regions       IO_$ALLOC_MAP and IO_$FREE_MAP take the I/O maps'
                     ranges from a free list of region nodes that
                     IO_$INIT builds; without it the PBU's IO_$ALLOC_MAP,
                     IO_$FREE_MAP and IO_$FREE_MAP_REGION refuse with
                     status_$pbu_not_supported.
    few_io_regions   that list has 8 nodes instead of 64.
    iomap_routines   the IOMAP_ module (iomap/): IOMAP_$MAP, IOMAP_$READ,
                     IOMAP_$UNMAP and IOMAP_$INIT keep the AT bus's I/O
                     map, a word entry per 1 KB bus page (`word_iomap').
}

%var vme_bus mbus_bus sysbus_routines smd_disk floppy_disk floppy_atbus
%var vme_vectored_ints sm_c_clear_go
%var floppy_page_dma floppy_iomap floppy_long_delays
%var pbu_mcb_config io_regions few_io_regions
%var iomap_routines

{ The units' I/O descriptors (io/io_desc.pas).

    io_descriptors   the IO_DESC module: an I/O descriptor per unit,
                     which the unit's DCTE points at.
}

%var io_descriptors

{ The static DCTEs' form (io/dctes.pas).

    named_dctes      the DCTEs are of kind 2, most with their unit's
                     name ("ring0", "win3", "sio1") and the PROM's
                     device record, and the floppy's and the
                     Winchester controller's of kind 3, with their
                     units' I/O requests; the other form is kind 1,
                     with neither.
    floppy_dcte_request
                     without `named_dctes': the floppy's DCTE is of
                     kind 3, with its unit's request (the interrupt
                     vector 16#F3, the FLOP page, the system bus).
}

%var named_dctes floppy_dcte_request

{ The bus interrupt routines (sysbus/, atbus/).

    sysbus_int_vec   SYSBUS_$INIT traps a range of vectors to
                     SYSBUS_$INT, which calls the handler and argument
                     SYSBUS_$DEFINE_INT stored for the vector.
    util_pic         the utility interrupt controller (UTIL_PIC): the
                     system bus's routines that enable, disable, test
                     and clear a device's interrupt, and SYSBUS_$INT
                     disables the level around its handler.
    atbus_routines   the AT bus's routines (atbus/): its entry in
                     IO_$BUS_EPV, its vector tables and ATBUS_$INIT.
    atbus_pics       with `atbus_routines': the AT bus's interrupts come
                     through its own two interrupt controllers (PIC1,
                     PIC2), which ATBUS_$INIT programs and whose masks
                     the routines set; ATBUS_$INIT traps the vectors
                     16#A0..16#AF to ATBUS_$INT, which masks the
                     interrupt, acknowledges it and calls the handler
                     ATBUS_$INT_VEC holds for it.  The other form
                     reaches the AT bus's interrupts through the system
                     bus's levels.
    atbus_irq8_unmasked
                     with `atbus_pics': ATBUS_$INIT leaves the slave
                     controller's input 0 (AT bus interrupt 8) unmasked
                     at the end, where the other form masks all eight.
    sysbus_vectors_90
                     with `sysbus_int_vec': the system bus's interrupts
                     come on the vectors 16#90..16#9F and 16#F0..16#FF,
                     and the ring's and the Winchester's DCTEs name
                     vector 16#90.
    sysbus_vectors_88
                     with `sysbus_int_vec': the system bus's interrupts
                     come on the vectors 16#88..16#9F and 16#F0..16#F7,
                     and a level can have a second handler
                     (SYSBUS_$DUP_VEC): SYSBUS_$DEFINE_INT gives a level
                     that has its handler the next one, and SYSBUS_$INT
                     calls it when the first returns false.
}

%var sysbus_int_vec util_pic atbus_routines atbus_pics sysbus_vectors_90
%var sysbus_vectors_88 atbus_irq8_unmasked

{ The MONO9 monochrome display (mono9/).

    mono9_display    the MONO9 display driver, its hand assembly
                     (MONO9_ASM) and its display descriptor
                     (MONO9_DESC).
}

%var mono9_display

{ The IEEE 802.5 token-ring driver (ring_8025/).

    ring_8025_driver  the RING_8025 driver, its unit records and its
                      two units' DCTEs.
    ring_8025_dma_channel
                      the adapter makes its transfers itself through the
                      unit's DMA channel, in cascade mode: the driver
                      stops the channel (DMA_$STOP) before each reset
                      and when the unit goes off line, and starts it
                      (DMA_$START_NCHECK) where the other form enables
                      the device; the burst sizes are zero.  The other
                      form has RING_8025_$INT make the transfers the
                      adapter asks for, a page at a time through the
                      auxiliary area's map page, which only it has.
    ring_8025_no_data_bursts
                      the adapter's initialization options are 16#9C00
                      instead of 16#9F00 (bits 9 and 8 clear).
    ring_8025_iomap   the adapter reaches memory through the I/O map
                      (iomap/): a unit allocates a region of eleven bus
                      pages when it starts (IO_$ALLOC_MAP; the unit
                      record keeps its first page) and frees it when its
                      receive process ends, and the driver maps each
                      buffer it gives the adapter into the region
                      (IOMAP_$MAP) and passes the bus address, where the
                      other form passes the physical one.  The control
                      area's pages are uncached, and the start clears bit
                      1 of the third control register where the other
                      form sets it.
    ring_8025_rif_sum_reversed
                      ring_8025_receive_frame finds the rest of a frame
                      whose routing field it strips at `fp + rif_len +
                      14' instead of `fp + 14 + rif_len'; the two orders
                      behave alike.
}

%var ring_8025_driver ring_8025_dma_channel ring_8025_no_data_bursts
%var ring_8025_iomap ring_8025_rif_sum_reversed

{ The Ethernet driver's forms (ethernet/), with `ethernet_driver'.

    ethernet_int_unmasked
                      ETHERNET_$INTERRUPT leaves the adapter's command
                      interrupt alone, where the other form turns it off
                      while it works (TCEN on, CMDE off) and on again at
                      the end.
    ethernet_short_polls
                      the driver's polling loops end sooner: the reset's
                      and the program start's 3000000 turns instead of
                      4200000, a reply byte's 35000 instead of 50000, a
                      command byte's 20000 and a command block's answer's
                      125000 instead of 30000 and 200000, and
                      ETHERNET_ASM's data-register waits 7500 instead of
                      10000.
    ethernet_long_polls
                      the driver's polling loops end later: the reset's
                      and the program start's 7500000 turns, a reply
                      byte's 87500 (a longword count), a command byte's
                      50000 (an unsigned word) and a command block's
                      answer's 312500, and ETHERNET_ASM's data-register
                      waits 17500.
    ethernet_vme      the driver of the Ethernet controller on the VME
                      bus instead of the 3C505 adapter's: the host and
                      the controller share each unit's block of the
                      ETHERNET_VME_$SH section, with rings of command
                      and reply slots and the receive and transmit
                      buffers; a command is a slot handed to the
                      controller and a byte written to its command
                      register; the unit's interrupt comes through
                      SYSBUS_$DEFINE_INT, nothing is downloaded, and
                      the driver record carries ETHERNET_VME_$NETWORK_UID.
}

%var ethernet_int_unmasked ethernet_short_polls
%var ethernet_long_polls
%var ethernet_vme

{ The SCSI Winchester disk driver (win_scsi/).

    win_scsi_disk    the WIN_SCSI_ disk driver and its eight units'
                     DCTEs.
}

%var win_scsi_disk

{ The SCSI driver's controller (scsi/), with `scsi_driver'.

    scsi_mailbox_ctlr  the SCSI host adapter of the AT bus that takes
                       32-byte command blocks through mailboxes in
                       memory: SCSI_$CINIT initializes it and maps the
                       mailboxes and blocks through the I/O map, a
                       command goes in an outgoing mailbox and is
                       started through the command port, SCSI_$INT
                       finds the block from the incoming mailbox, and a
                       transfer's pages are mapped into a device's I/O
                       map region (IO_$ALLOC); the other form is the
                       NCR 53C90's driver.
}

%var scsi_mailbox_ctlr

{ The cartridge tape driver's forms (ct/), with `ct_driver'.

    ct_qic02         the driver of a QIC-02 drive behind a tape
                     controller of its own (CT_$INT), and its DCTE.
    ct_scsi          the driver of a SCSI tape drive through the SCSI_
                     driver; with `ct_qic02' as well, the driver's
                     routines test for the SCSI drive first and run the
                     QIC-02 code otherwise.
    ct_atbus_qic02   with `ct_qic02': the QIC-02 drive's AT bus adapter,
                     driven through its ports (the data and command byte,
                     the control and status, the DMA go and reset), the
                     drive's six status bytes read after each command,
                     its blocks moved through a DMA_ channel
                     (`atbus_dma'), its interrupt a PBU unit's; the
                     other form's controller takes a block list in its
                     window and keeps its own counts.
    ct_iomap         with `ct_atbus_qic02': the drive's DMA reaches
                     memory through the AT bus's I/O map: a transfer's
                     pages are wired for the adapter's PBU unit
                     (PBU2_$WIRE, PBU2_$UNWIRE) and their page numbers
                     noted (MMU_$VTOP); up to 64 blocks at a time are
                     mapped into an I/O map region of the unit's
                     (PBU2_$ALLOCATE_MAP, IOMAP_$MAP, PBU_$FREE_MAP) and
                     moved by PBU2_$DMA_START and PBU2_$DMA_STOP; the
                     other DMA stops are PBU_$DMA_STOP's.
    ct_reset_delay   with `ct_scsi': the drive's reset is followed by a
                     delay loop of 5000000 rounds.
    ct_vectored_ctlr with `ct_qic02': the turbo boards' form of the
                     controller: CT_$CINIT probes it with 16#1B05 (the
                     other form's 16#3D05) and defines its interrupt on
                     the DCTE's vector (SYSBUS_$DEFINE_INT), and CT_$INT
                     answers false unless the status word shows the
                     controller's interrupt (bit 9).
    ct_wait_ends_busy
                     with `ct_qic02': CT_WAIT and ct_transfer leave no
                     command outstanding when they return.
    ct_owner_test_reversed
                     CT_$ACQUIRE tests the unit's owner as `ct_owner =
                     proc1_$current' instead of `proc1_$current =
                     ct_owner'; the two orders behave alike.
}

%var ct_qic02 ct_scsi ct_atbus_qic02 ct_iomap ct_reset_delay
%var ct_vectored_ctlr ct_wait_ends_busy ct_owner_test_reversed

{ The request servers (network/).

    two_request_servers  NETWORK_$ADD_REQUEST_SERVERS limits the count
                         to 2 instead of 3.
}

%var two_request_servers

{ The display TTY's displays (dtty/).

    second_display_unit  DTTY_$INIT asks SMD_$INQ_DISP_TYPE about display
                         unit 2 when unit 1 has none, and takes its two
                         color types (smd_$color_display,
                         smd_$800_color).
    dtty_color_board     the display TTY drives the COLOR_ board's display
                         itself: dtty_$get_disp_type waits for the board
                         on the color display types, dtty_$clear_window
                         clears a color display's window with the board's
                         command, and dtty_$load_font sends the board its
                         mode word first.
    dtty_gpu             the display TTY drives the graphics processor's
                         color displays (smd_$color2_display,
                         smd_$color3_display) itself: dtty_$get_disp_type
                         waits until the processor is done,
                         dtty_$gpu_command sends it a command's words,
                         dtty_$clear_window clears a color display's
                         window with the processor's clear command, and
                         dtty_$load_font sends it its font command first.
}

%var second_display_unit dtty_color_board dtty_gpu

{ The terminal lines and the keyboard (term/, kbd/, tone/, sio/).

    kbd_tone          the keyboard sounds the tone: TONE_$ENABLE sends
                      the keyboard one of two 3-byte commands through
                      KBD_$PUT, where the other form calls
                      SIO2681_$TONE on the speaker's channel; TONE_$TIME
                      sounds it again for each 75000 ticks, and
                      KBD_$RESET writes two reset bytes to the
                      keyboard's serial channel.
    kbd_key_ring_512  the keyboard descriptor's key ring holds 512
                      characters instead of 64.
    sio16550_lines    the terminal lines are four 16550 serial ports
                      (sio16550/): SIO16550_$INIT calls SIO_$INIT for
                      each, TERM_$INIT only starts the tablet, and
                      OS_TERM_INIT's block holds four TTY and SIO
                      descriptors and no SIO6509 or SIO2681 records;
                      KBD_$RESET waits on the 16550's line status.
    kbd_commands      the keyboard driver sends the keyboard commands:
                      kbd_$put_line copies a string into the console's
                      transmit buffer and starts the line,
                      KBD_$SET_KBD_MODE and KBD_$GET_CHAR_AND_MODE send
                      mode commands, KBD_$RCV takes more actions, and
                      KBD_$CRASH_INIT resets the descriptor KBD_$INIT
                      records.
    console_sio2681   the display console's keyboard line is the
                      SIO2681's channel A, with no SIO6509: TERM_$INIT
                      sets up the console and one serial line on the
                      chip's two channels and records channel A, through
                      which KBD_$RESET sends its bytes; OS_TERM_INIT's
                      block holds two TTY and SIO descriptors.
    sio2681_four_lines
                      the display console and three serial lines are the
                      channels of two SIO2681s, with no SIO6509:
                      TERM_$INIT sets the console and one serial line up
                      on the first chip's two channels and two serial
                      lines on the second's, and initializes each chip
                      after its two lines; OS_TERM_INIT's block holds four
                      TTY and SIO descriptors.
    sio2681_pbu_int   SIO2681_$INIT, after storing the chip's interrupt
                      routine in SIO_VEC, acquires the chip's interrupt
                      as PBU unit 1 (PBU_$ACQUIRE_INT).
    kbd_type_sysrev   the console keyboard is of type 2 or type 3, as bit
                      7 of the system revision word's low byte (MMU+5,
                      the word MMU_$SET_SYSREV reads) says, set for type
                      2: KBD_$INIT sets the type from it; for type 2
                      KBD_$RESET sends nothing and TONE_$ENABLE sounds
                      the tone through SIO2681_$TONE, which this form
                      has with `kbd_tone'; for type 3 they take their
                      `kbd_tone' forms, KBD_$RESET's bytes going through
                      the first SIO2681's channel A, which TERM_$INIT
                      records as `console_sio2681' does.
    sio2681_vec_by_chip
                      with `sio2681_four_lines' TERM_$INIT gives each
                      SIO2681 the interrupt vector of its own number
                      (SIO_VEC 1 for the first chip, 2 for the second),
                      where the other form gives the first chip 2 and
                      the second 1.
    pchist_third_line TERM_$PCHIST_ENABLE sets its count on the third
                      serial line's channel, the second SIO2681's channel
                      A, instead of the last serial line's.
    sio2681_modem_op3_op0
                      SIO2681_$SET_LINE drives channel A's modem lines on
                      output port bits 3 and 0 and channel B's on 2 and
                      1, where the other form gives channel A bits 2 and
                      0 and channel B bits 3 and 1.
    kbd_reset_chan_a  with `sio2681_four_lines': TERM_$INIT records the
                      first SIO2681's channel A as the console's, through
                      which KBD_$RESET sends its two bytes to every
                      keyboard (`kbd_type_sysrev' does the same for the
                      type 3 keyboard alone).
    sio2681_acr_timer with `sio2681_four_lines': the first SIO2681's
                      auxiliary control word (TERM_$INIT's configuration
                      word 5) is 16#EA00, its counter in timer mode and
                      the change interrupts of inputs 3 and 1 alone,
                      where the other form gives 16#8F00.
    sio2681_chip_2_pbu_8
                      with `sio2681_pbu_int' and `sio2681_four_lines': the
                      second SIO2681's registers are 16#100 bytes after
                      the first's (SIO2681_$INIT), and a chip given
                      interrupt vector 2 has its interrupt stub in
                      SIO_VEC2 and is acquired as PBU unit 8.
}

%var kbd_tone kbd_key_ring_512 sio16550_lines kbd_commands console_sio2681
%var sio2681_pbu_int sio2681_four_lines kbd_type_sysrev sio2681_vec_by_chip
%var pchist_third_line sio2681_modem_op3_op0
%var kbd_reset_chan_a sio2681_acr_timer sio2681_chip_2_pbu_8

{ The Winchester controller (win/).

    winchester_ctlr      the WIN_ Winchester disk driver.
    win_descriptor_ctlr  WIN_ drives a controller that takes a list of
                         transfer descriptors in its window, where the
                         other form sends it ANSI commands.
    win_atbus_ctlr       WIN_ is the WIN8_ driver of a controller on the
                         AT bus: 6-byte command blocks and the data
                         through its ports by program (WIN_ASM), a
                         sector buffer in the controller, and its
                         interrupt through IO_$ACQUIRE.
    win_ring_disk_ctlr   WIN_ drives the disk controller of the ring/disk
                         board: up to four drives on its PRIAM or SMD
                         interface, the transfers on two channels of the
                         board's DMA controller through IOMAP's entries
                         64 and 65, the drive found and its geometry by
                         DISK_INIT, its interrupt on the board's vectors
                         (SYSBUS_$DEFINE_INT); no SEEK global.
    win_mailbox_ctlr     with `win_atbus_ctlr': WIN_ also holds the
                         WIN7_ driver of a controller on the AT bus that
                         takes 64-byte command blocks through mailboxes
                         in memory (WIN_SETUP_IOPB, WIN_SETUP_MAILBOX,
                         WIN_SEND_COMMAND), up to two such controllers,
                         each with its interrupt through IO_$ACQUIRE and
                         its transfers on a DMA_ channel in cascade
                         mode (`atbus_dma'), and its own DCTEs and jump
                         table (WIN7_$CINIT).
    win_vectored_ctlr    with `win_descriptor_ctlr': the turbo boards'
                         form of the controller: WIN_$CINIT probes it
                         with the configuration word 16#1B05 (the other
                         form's 16#3D05) and defines its interrupt on
                         the DCTE's vector (SYSBUS_$DEFINE_INT), and
                         WIN_$INT answers false unless the status word
                         shows the controller's interrupt (bit 11).
    win6_ct6_board       the second Winchester and cartridge tape
                         controller on the WIN6 page (TAPE6): their
                         drivers WIN6_ and CT6_, and their DCTEs,
                         WIN6_DCTE and CTAPE6_DCTE.  With `ct_qic02' the
                         CT_ globals drive the tape through the second
                         controller when CT6_$CINIT found it: its
                         commands go in command blocks of the WIN6
                         page (WIN6_$GET_IOPBS) and its completions come
                         through CT6_$INT.
}

%var winchester_ctlr win_descriptor_ctlr win_atbus_ctlr win_ring_disk_ctlr
%var win_mailbox_ctlr win6_ct6_board win_vectored_ctlr

{ The I/O map entries of the storage module, tape and PBU drivers (sm/,
  sm_c/, mt/, pbu/).

    long_iomap       the drivers write IOMAP's entries as longwords: the
                     physical page number plus 16#48000, or plus a
                     unit's whole transfer control (PBU2_); the other
                     form writes a word field of each entry, the page
                     number plus 16#8000.
    word_iomap       IOMAP's entries are words, 2 bytes a page: the
                     physical page number alone, 0 an unused entry,
                     with no transfer control added (PBU2_).
}

%var long_iomap word_iomap

{ The ring controller (ring/).

    ring_controller_dma  the ring controller moves its packets itself:
                         the header's and the data's addresses and word
                         counts are registers of its block, where the
                         other form drives three channels of the DMA
                         controller (`dma_driver').
    ring_vector_regs     ring_$init_internal stores the vector word
                         16#3D00 into the controller's three vector
                         registers.
    ring_owner_test_reversed
                         RING_$SVC_WRITE tests a packet type's owner as
                         `channel <> owner' instead of `owner <>
                         channel'; the two orders behave alike.
    ring_pkt_index_reversed
                         ring_$open_internal indexes a channel's new
                         packet-type entries as `pkt_type_cnt + i'
                         instead of `i + pkt_type_cnt'; the two orders
                         behave alike.
    ring8_controller     the ring controller has packet buffers and a
                         command block of its own (RING8_$INT, RING_$CCB,
                         RING_ASM's RING_$RB_FROM and RING_$RB_TO), its
                         registers in the CSR pages its I/O descriptor
                         maps.
    nodeid_prom          RING_$GET_ID reads the node id from the NODE_ID
                         PROM and crashes the system with 16#0011001F
                         when it is wider than 20 bits, where the other
                         form takes it from the ring controller's
                         registers.
    nodeid_prom_probe    RING_$GET_ID probes the node id PROM and takes
                         the node id from it when the probe answers and
                         its first word is zero, from the first unit's
                         controller registers otherwise (each the high
                         bytes of four words), and crashes the system
                         with 16#0011001F when the id is wider than 20
                         bits.
    ring_board_dma       the ring controller's register block holds two
                         DMA controllers of its own, the transmit's and
                         the receive's, which address the host's pages
                         through I/O map entries from the unit's
                         dma_page; it interrupts on separate transmit and
                         receive vectors (RING_$XMIT_INT, RING_$RCV_INT,
                         which ring_$init_internal defines with
                         SYSBUS_$DEFINE_INT) in place of RING_$INT, and
                         the RING block has no RING_$SCRUB and
                         RING_$FROM_ERR.
    ring_id_not_found    RING_$GET_ID answers 1 when IO_$GET_DCTE does not
                         find the ring controller
                         (status_$io_controller_not_found), as when the
                         controller is not in the system.
    ring_sysbus_vector   ring_$init_internal defines RING_$INT for the
                         DCTE's vector with SYSBUS_$DEFINE_INT and stores
                         the vector words 16#0D00, 16#0D00 and 16#1B00 into
                         the controller's three vector registers, the
                         first 16#1B00 instead when bit 0 of the mode
                         register is clear.
    ring_lights_8_4      RING_$SENDP's transmit light and RING_$INT's
                         receive light are the memory control register's
                         16#8 and 16#4 (MMU_$MCR_CHANGE), where the other
                         form passes 16#4 and 16#5.
}

%var ring_controller_dma ring_vector_regs ring_owner_test_reversed
%var ring_pkt_index_reversed
%var ring8_controller nodeid_prom nodeid_prom_probe ring_board_dma
%var ring_id_not_found ring_sysbus_vector ring_lights_8_4

{ The start-up and the shutdown (os/).

    power_off_check   OS_$INIT starts a time queue element whose
                      callback, OS_$CHECK_POWER_OFF, watches
                      MMU_$POWER_OFF.
    power_down        OS_$SHUTDOWN ends, when the volumes shut down well
                      and MMU_$POWER_OFF is set, with "Beginning power
                      down sequence...", the disks spun down, the
                      interrupts disabled and the power register
                      written.
    vme_power_off     that power register is bit 3 of the word at +0x30
                      of VME_CTL.
    power_off_csr     that power register is the CPU control register:
                      MMU_$SET_CSR writes it with 16#8000.
    shutdown_keeps_fp_savep
                      OS_$SHUTDOWN leaves FP_$SAVEP as it is, where the
                      other form clears it before wiring the shutdown
                      code.
    disp2_probe       OS_$INIT probes for a second display and installs
                      DISPLAY2_$UID's ASTE when one answers;
                      DISP2_PRESENT holds the answer.
    color_board       the COLOR_ color graphics board (color/): OS_$INIT
                      calls COLOR_$COLD_INIT and probes the board as the
                      second display when the first probe fails,
                      OS_$SHUTDOWN calls COLOR_$SHUTDOWN, SMD uses the
                      board's routines for display types 3 and 4, and
                      the COLOR_ system calls.
    color_board_iomap with `color_board': the board reaches the pages
                      COLOR_$MAP wires through the I/O map, entries 95
                      on (the page number, 16#FFF for none), where the
                      other form loads the board's own color map
                      (COLOR_$LOAD_MAP); its display commands are 16#E
                      (on) and 16#6 (off), where the other's are 16#280E
                      and 16#2806; its interrupt is vector 16#CE,
                      which COLOR_$VECTOR_INIT fills itself, where the
                      other's is 16#A8, defined with VME_$DEFINE_INT.
    crash_reboot      the node may restart itself (CRASH,
                      CRASH_$OK_TO_REBOOT): OS_$INIT allows the reboot
                      unless boot flag 15 is set, a server's node check
                      stores the PROM's restart code 243, and
                      OS_$SHUTDOWN ends in CRASH with that code when the
                      volumes and its status are good.
    ring_node_id      OS_$INIT takes NODE_$ME from RING_$GET_ID(0) after
                      IO_$INIT.
    smd_display_memory
                      OS_$INIT installs the display's memory with
                      SMD_$INSTALL_DISP_MEM, where the other form probes
                      the display and makes its ASTE, and calls
                      SMD_$COLD_INIT after LOG_$INIT; OS_$SHUTDOWN calls
                      SMD_$SHUTDOWN; DTTY_$INIT takes unit 1's sizes from
                      SMD_$INQ_DISP_INFO, and the display TTY clears its
                      window with SMD_$CLEAR_SCREEN.
    calendar_service_mode
                      OS_$INIT passes `not SERVER_$FLAG' to CAL_$VERIFY;
                      when the calendar is refused, a non-server shuts
                      the volumes down and crashes, and a server asks
                      for service mode and blinks the lights for ever.
    fim_nmi           the vector table installs FIM_$NMI for vector 31,
                      where the other form stores FIM_$PARITY_TRAP there
                      after DTTY_$INIT.
    vector_alignment_check
                      OS_$INIT checks every installed handler's address
                      for the low two bits and crashes with 16#001B0009
                      ("exception handler is not longword-aligned").
    prom_config_record
                      OS_$INIT takes a third parameter, the PROM's
                      configuration record, whose fields give the
                      terminal's parameters, SERVER_$FLAG, the tape boot
                      and TIME_$SYS_FREQ, and whose address IO_$INIT and
                      IO_$LOG_SELF_TESTS get; OS_$BOOT_DEVICE holds the
                      boot record's unit alone.
    shutdown_kbd_mode OS_$SHUTDOWN sets the keyboard's mode
                      (TERM_$CONTROL of line 0, option 36, value 0)
                      after the display's shutdown.
    early_as_init     OS_$INIT calls AS_$INIT right after MST_$PRE_INIT,
                      before COLD's segment is removed (with `pft_mmu'
                      it follows MMU_$INIT).
    boot_flags_diskless
                      OS_$INIT takes NETWORK_$DISKLESS from boot flag 7
                      (diskless) and 8 (disked, the network boot device
                      in the diskless reply's first two words), each
                      still telling NET_IO_$BOOT_DEVICE, and from
                      NET_IO_$BOOT_DEVICE's answer otherwise.
    pbu_wire_at_boot  OS_$INIT wires the PBU page (PBU_$WIRE_PBU) after
                      the checksum passes.
    atbus_int8_dummy  OS_$INIT then acquires AT bus interrupt 8, with no
                      CSR pages, for DUMMY_INTERRUPT_HANDLER.
    vector_seg_prot   OS_$INIT makes the vector page read-only by its
                      segment (MMU_$SET_SEG_PROT), where the other form
                      write-protects the page (MMU_$PAGE_WRITE_BIT).
    boot_flags_server OS_$INIT sets SERVER_$FLAG from boot flag 1 when
                      boot flag 0 (the display's modes) is set.
    parity_trap_vector_30
                      FIM_$PARITY_TRAP is installed for vector 30 as
                      well as 31.
    fp_five_exceptions
                      the vector table installs five floating-point
                      exceptions, vectors 49..53, and the format error
                      (14) alone: no coprocessor protocol violation
                      (13), branch on unordered (48) or signalling NaN
                      (54); FIM_UNWIRED has no stubs for those three,
                      and the FP stubs' frame helper is a return.
    mmu_fault_vectors the vector table installs the MMU's faults, vectors
                      128..130 (region, segment and page fault) on
                      FIM_$COLD_BUS_ERR, the access violation (131,
                      FIM_$ACC_VIOL) and the FP ASID exception (132,
                      FIM_$FP_TRAP); with `ecc_memory' also FIM_$ECCC_TRAP
                      and FIM_$ECCU_TRAP for vectors 240 and 255.
                      OS_$INIT later puts FIM_$REG_FAULT on 128 and
                      FIM_$PAGE_FAULT on 129 and 130, with the bus
                      error's FIM_$BUS_ERR.
    vme_undef_vectors OS_$INIT points vectors 128..255 at VME_$UNDEF_INT
                      before the table's, and the table has no VME cells
                      (VME_$INT and VME_$ERR_INT for vectors 28 and 29,
                      the other `vme_bus' form's).
    node_id_boot_record
                      when RING_$GET_ID answers 1 (no ring controller)
                      OS_$INIT takes NODE_$ME from the PROM's boot
                      record, and it crashes the system with 16#0011001F
                      when the node id is wider than 20 bits.
    fpx_eco_check     after PRINT_BUILD_TIME a disked boot with an FPX
                      (FPX_EXISTS) on a CPU board whose system revision
                      word has bit 2 clear prints a request for ECO 14078
                      and crashes the system with 16#001B0005 ("CPU board
                      below minimum revision level").
    io_space_0ff      OS_$INIT's display apertures and color board
                      register (constant cells) are in the I/O space at
                      16#0FFA0000 .. 16#0FFFFFFF, where the other form's
                      are at 16#FA0000 .. 16#FFFFFF.
    io_space_7ff      the same at 16#7FFA0000 .. 16#7FFFFFFF, and so
                      are DISP_LITES's frame buffer and display
                      controller word.
    color2_shutdown_in_smd
                      with `gpu_driver' OS_$SHUTDOWN does not shut the
                      COLOR2 board down: SMD's code calls
                      COLOR2_$SHUTDOWN.
    nmi_vector_30     with `fim_nmi': the vector table installs FIM_$NMI
                      for vector 30 as well, in a descriptor of its own
                      before vector 31's.
    pic_vector_cells  the vector table has descriptors for vectors
                      160..163, 165..166, 168..170 and 174 whose handler
                      cells are nil: the installation leaves those
                      vectors as they are, and the alignment check
                      (`vector_alignment_check') tests them.
    boot_record_bus   the PROM's boot record gives the boot device's bus
                      in the controller word's high byte: OS_$INIT moves
                      it to the record's word at 0x0C and clears the
                      byte, stores the bus in OS_$BOOT_DEVICE and passes
                      it to VOLX_$MOUNT, where the other form stores and
                      passes 0.
    physical_cache_enable
                      OS_$INIT turns the physical cache on
                      (CACHE_$ENABLE_PHYSICAL) after AUDIT_$INIT on a
                      board that has one (ROADRUNNER).
}

%var power_off_check power_down vme_power_off power_off_csr
%var shutdown_keeps_fp_savep disp2_probe color_board color_board_iomap
%var crash_reboot ring_node_id smd_display_memory calendar_service_mode
%var fim_nmi vector_alignment_check prom_config_record shutdown_kbd_mode
%var early_as_init boot_flags_diskless pbu_wire_at_boot atbus_int8_dummy
%var vector_seg_prot boot_flags_server parity_trap_vector_30
%var fp_five_exceptions mmu_fault_vectors vme_undef_vectors
%var node_id_boot_record fpx_eco_check io_space_0ff io_space_7ff
%var color2_shutdown_in_smd nmi_vector_30 pic_vector_cells boot_record_bus
%var physical_cache_enable

{ The display driver's displays (smd/).

    two_display_units  two display unit records, a second font table and
                       free list, and a second blink routine
                       (SMD_$BLINK_CURSOR_2); the unit loops run to 2.
    color_displays     the driver knows the color display types 3..6:
                       its drawing routines refuse them with
                       smd_$not_on_color.
    blt_request_start  SMD_$BLT passes the caller's BLT request itself
                       to the hand-written SMD_$START_BLT and refuses
                       only the main-memory modes, where the other form
                       builds the controller's parameter words in its
                       frame.
    display_devices    the driver drives up to eight display units
                       through their devices' descriptors and routine
                       vectors (SMD_$ADD_DEVICE, the SMD_$NOP_*
                       defaults), without SMD_$BLT, SMD_$WS_INIT and the
                       other drawing and font routines; and the
                       hand-written COLOR4_ASM.
    blt_main_memory    the BLT moves between a display and main memory:
                       SMD_$WIRE_MM wires up to 32 pages of a buffer
                       into the display's record, SMD_$BLT puts them in
                       the I/O map from the unit's first entry and
                       starts the main-memory modes, the hand-written
                       SMD_$UNWIRE_MM unwires them, and SMD_$INQ_MM_BLT
                       answers true; the other form refuses the modes
                       (smd_$not_implemented).
    smd_unit_280_bytes with `display_devices': each display unit record
                       is 0x118 bytes instead of 0x114, 4 bytes at +0x0C
                       before the mapped addresses (the place of the
                       `two_display_units' record's I/O map word), which
                       nothing reaches; every later field is 4 bytes on,
                       and SMD_$WIRED_DATA is 0x900 bytes instead of
                       0x8E0.
    gpu_displays_only  with `two_display_units' and `gpu_driver': the
                       units' displays are the graphics board's alone.
                       SMD_$INIT probes no unit's controller (no TESTPAGE
                       of its registers, no SMD_$GET_DTYPE), so a unit
                       without the board keeps the type none; unit 1's
                       record without the board is the kind-0 one, where
                       the other form starts from kind 1 and takes kinds
                       0 and 1 alike.
}

%var two_display_units color_displays blt_request_start display_devices
%var blt_main_memory smd_unit_280_bytes gpu_displays_only

{ The graphics processor and its board (gpu/, color2/).

    gpu_own_vectors      with `gpu_driver': the processor's and the
                         COLOR2 board's interrupts have vectors of their
                         own.  GPU_$COLD_INIT puts GPU_ASM's
                         GPU_$DONE_INT and GPU_$PAGE_INT in GPU_DONE_VEC
                         and GPU_PAGE_VEC, COLOR2_$INT_INIT puts
                         COLOR2_$INT_DECODE in COLOR2_DONE_VEC, and the
                         handlers raise the IPL to 7, switch to the
                         interrupt stack and leave through
                         PROC1_$INT_ADVANCE; where the other form's
                         GPU_$INTERRUPT and COLOR2_$INT_DECODE are entered
                         from the VME bus's and the color board's
                         decoders with the vector.
    gpu_reset_registers  with `gpu_driver': after a reset (gpu_$reset)
                         and at the end of GPU_$COLD_INIT the driver writes
                         two of the processor's registers with 16#41C3
                         commands: 16#71BA := 16#000D, and 16#2007 := the
                         processor's status word with bit 7 set.
}

%var gpu_own_vectors gpu_reset_registers

{ The locator (tpad/).

    tpad_block_head  TPAD's .DATA block begins with 40 bytes before the
                     unit records (0x1A8 bytes instead of 0x180), and
                     TPAD_$INIT's touchpad maximum is 4096, or 1500 when
                     the byte at +5 of those bytes is true, where the
                     other form's is always 1500.
}

%var tpad_block_head

{ The crash reports and the calendar (misc/m68k/, fim/m68k/, time/,
  cal/; the hand assembly's `.if' arms).

    crash_report_blank_lines
                          the crash reports' templates begin with extra
                          line feeds (FIM_$CRASH's "FAULT IN DOMAIN/OS:",
                          CRASH_SYSTEM's "Crash_Status").
    calendar_word_port    the MSM5832 calendar is reached through a word
                          at +0x200 of its page: TIME_$READ_CAL reads the
                          digits uninverted, and CAL_$WRITE_CALENDAR
                          writes each digit as one word (select high,
                          digit low, strobe 16#200).
    calendar_indexed_rtc  the calendar is a clock chip of numbered
                          registers, the number written to CAL, the
                          register at CAL + 4: CAL_$WRITE_CALENDAR sets
                          registers 10, 13, 11 and the binary time in
                          0..9, and TIME_ASM reads that chip
                          (cal/sau9/, time/sau9/).
    calendar_mapped_rtc   the calendar is a clock chip whose registers
                          are the bytes of its page (CALENDAR + n), the
                          time binary in registers 0..9 and the control
                          in 10 and 11: CAL_$WRITE_CALENDAR stops the
                          clock (register 11 SET), writes the time and
                          starts it, and TIME_ASM reads it with SET held
                          after its update bit (register 10 bit 7) is
                          clear (cal/m68k/, time/m68k/).
}

%var crash_report_blank_lines calendar_word_port
%var calendar_indexed_rtc calendar_mapped_rtc

{ The virtual memory tables (ast/, mmap/, mst/, area/, pmap/).

    large_vm            the large layout: 28-byte ASTEs, each holding its
                        page map's physical address, 14-bit ASTE hints,
                        the address spaces' segment maps (SMAPS) and a
                        larger MST, where the other form has 20-byte
                        ASTEs and 9-bit hints; OS_$INIT's SERVER_$FLAG in
                        the node check and its MEM_$INIT after IO_$INIT.
    vm_5760_astes       5760 ASTEs and 1280 AOTEs, instead of 504 and 280.
    vm_1536_astes       1536 ASTEs and 640 AOTEs.
    vm_2432_astes       2432 ASTEs and 1280 AOTEs.
    pmap_threads        an ASTE heads the thread of the MST entries that
                        point at its page map (MST_$UNTHREAD_PMAP), which
                        ast_$deactivate_segment ends.
    bst_va_lookup       with `pmap_threads': MST_$BST_TO_VA finds the
                        virtual address an address space maps a page map
                        at through its thread, and MST_$ASSOC associates
                        a physical page with a virtual address's page.
    find_touches        MST_$FIND and MST_$WIRE always fault the page in
                        through MST_$TOUCH, where the other form looks
                        the page up in the MMU first.
    pmmu_page_maps      the page maps' entries are MC68030 page
                        descriptors, the frame in bits 31..10 and the
                        flags in the low word (AST_$PTOV,
                        AST_$REMOVE_PAGE, AST_$ALLOC_CONTIG,
                        MMAP_$ALLOC_CONTIG), and the MMAP entries' disk
                        addresses 21 bits, not 22; FIM_$BUILD_DF stores
                        MMU_$BUS_STATUS as the fault's information word,
                        and OS_$INIT clears the resident bit of the
                        descriptors it mapped.
    pmap_cache_inhibit  the page maps' pages are cache-inhibited, with
                        AST_$CACHE_INHIBIT_PPN and AST_$CACHE_ENABLE_PPN,
                        and so are the I/O pages AST_$ASSOC_IOPPN maps
                        and a PBU unit's physically contiguous buffer
                        (PBU_$WIRE_SPECIAL).
    mmap_ppns_10000     the pageable pages are 16#10000..16#1FFFF, and
                        the page entries' list links are 22-bit fields.
    mmap_ppns_400       the pageable pages are 16#400..16#23FF.
    mmap_ppns_200_3fff  the pageable pages are 16#200..16#3FFF.
    mmap_ppns_4000      the pageable pages are 16#4000..16#FFFF.
    mmap_ppns_4000_bfff the pageable pages are 16#4000..16#BFFF.
    mst_7168_words      the MST holds 7168 words.
    mst_55808_words     the MST holds 55808 words.
    mst_pages_tiered    MST_$INIT lets the MSTE pages take a tenth of the
                        first 4096 real pages and a fifth of the rest, at
                        most 9420, where the other form takes a share of
                        all of them.
    large_address_space the regions' segments are constants: private A
                        30336, global A 256 from 30336, private B 128
                        from 30592, global B 2048 from 30720, of 32768;
                        OS_$INIT clears COLD's RARS entry and frees the
                        page maps of the two unused global ranges.
    vm_8192_segs        the regions' segments are constants: private A
                        7424, global A 256 from 7424, private B 256 from
                        7680, global B 256 from 7936, of 8192.
    vm_65536_segs       the regions' segments are constants: private A
                        60928, global A 256 from 60928, private B 256
                        from 61184, global B 4096 from 61440, of 65536;
                        a region is 256 segments, an ASID's RARS entries
                        512 longwords apart, and MST_$INIT gives every
                        ASID its MMU_$RARS_PHADDR from ASID 0's.
    region_mmu          the MMU's tables are longwords: a RARS entry
                        holds a region's valid and global bits and the
                        physical address of its page of segment map
                        entries; a segment map entry its valid bit, the
                        MST entry's five protection bits and the page
                        map's physical address.  The other form's tables
                        are the MC68030's descriptors: 256 root entries
                        and 8-byte segment map entries.
    region_registers    with `region_mmu': the MMU translates through 32
                        region registers (the DNx60's), which
                        MMU_$INSTALL_REGION loads: an ASID's RARS is 32
                        longwords, several ASIDs' to a page
                        (MST_$RAR_PAGES); a region is a 32nd of the
                        segments.
    va_to_aste_smap_bit_0
                        with `region_mmu': mst_$va_to_aste sets bit 0 of
                        the segment map entry it makes valid, which
                        MST_$TOUCH leaves clear.
    vm_regions          an address space's segments are grouped in
                        regions: each ASID has a root table in RARS with
                        an entry per region for its page of segment map
                        entries (MMU_$RARS_PHADDR), a set of its active
                        regions (MST_$REGIONS_ACTIVE), a count of its
                        mapped segments per region (MST_$SEGS_MAPPED) and
                        a set of its BST pages (MST_$BST_PAGES); a region
                        whose last segment is unmapped is freed
                        (mst_$free_region), and MST_$MAP_SPECIAL maps the
                        special segments.
    run_time_layout     the segment layout is chosen at boot: MST_$PRE_INIT
                        replaces the words of the default layout (2048
                        segments) with the MC68851 PMMU's (8192) when
                        MMU_$HAVE_PMMU says there is one.  The words are
                        the MST_$SEG_ words, the REGION_$ words (the
                        regions, 64 segments each) and SPECIAL_$SEG; an
                        ASID's RARS is REGION_$TN entries, several ASIDs'
                        to a page (MST_$RAR_PAGES), its BST pages a
                        longword set, and each new ASID gets a copy of
                        the OS wired segment's segment map entry.
    set_mstes_no_cache_clear
                        mst_$set_mstes leaves the cache alone, where the
                        other form ends with CACHE_$CLEAR.
    smap_shared_global  MST_$TOUCH and mst_$va_to_aste leave a global
                        segment's map entry with bit 9 set (the MC68851's
                        shared-globally bit) and its bits 15..10 as they
                        are, where the other form clears bit 9 and sets
                        bits 15..10.
    smap_shared_global_68851
                        MST_$TOUCH and mst_$va_to_aste clear bit 9 and
                        set bits 15..10 only when M68030 says the CPU is
                        an MC68030; with the MC68851 PMMU the entry keeps
                        them as `smap_shared_global' leaves them.
}

%var large_vm vm_5760_astes vm_1536_astes pmap_threads pmmu_page_maps
%var vm_2432_astes
%var bst_va_lookup find_touches
%var pmap_cache_inhibit
%var mmap_ppns_10000 mmap_ppns_400 mmap_ppns_200_3fff large_address_space
%var vm_8192_segs region_mmu set_mstes_no_cache_clear
%var mmap_ppns_4000 mst_55808_words mst_pages_tiered vm_65536_segs
%var region_registers va_to_aste_smap_bit_0
%var mst_7168_words vm_regions run_time_layout smap_shared_global
%var mmap_ppns_4000_bfff smap_shared_global_68851

{ The start-up of the page purifiers (pmap/, os/).

    boot_time_lock      OS_$INIT holds ml_$mt_lock while a node without a
                        calendar takes the time from its mother node, and
                        PMAP_$PURIFIER_L and PMAP_$PURIFIER_R start by
                        locking and unlocking it, waiting for OS_$INIT;
                        OS_$INIT probes for the calendar through
                        IO_$GET_DCTE and crashes a disked node without
                        one.
}

%var boot_time_lock

{ The MMU and the caches (mmu/, cache/; the hand assembly's `.if' arms).

    pft_mmu             the page frame table and page translation table
                        MMU (mmu/m68k/), the MC68010's bus error frame in
                        FIM_$BUILD_DF, and OS_$INIT's MMU_$INIT, AS_$INIT
                        and its MMU_$REMOVE and MMU_$SET_PROT of COLD's
                        pages, the type-4 protections and the vector page.
    cpu_status_register the bus error status is the CPU status
                        register's word (MMU): FIM_$BUS_ERR keeps it,
                        ORed with the process's fault status word, in
                        MMU_$BUS_STATUS; FIM_$FLINE, FIM_$SPURIOUS_INT and
                        the I/O probe clear it, and the dispatcher ORs it
                        into the outgoing process's fault status word and
                        clears it.
    dispatch_clear_sc_page
                        with `cpu_status_register': the dispatcher clears
                        the word at the start of the system control page
                        (SC_PAGE) where the other form clears the CPU
                        status register.
    cacr_clear_data     CACHE_$FLUSH_VIRTUAL clears the MC68030 data
                        cache (CACR bit 11), where the other form only
                        returns.
    flush_virtual_68030 CACHE_$FLUSH_VIRTUAL tests M68030: on an MC68030
                        it clears the data cache as with
                        `cacr_clear_data', else it stores a zero byte at
                        SC_PAGE + 16#E.
}

%var pft_mmu cpu_status_register cacr_clear_data dispatch_clear_sc_page
%var flush_virtual_68030

{ The FPU's enable (fim/m68k/, fp/m68k/).

    fpu_enable_ccr      FIM_$FP_INIT, FIM_$FP_GET_STATE and the FP owner
                        switch set and clear bit 7 of MMU_CCR, where the
                        other form writes the FPU owner register.
    fpu_enable_cpu_control
                        FIM_$FP_INIT, FIM_$FP_GET_STATE and the FP owner
                        switch set and clear bit 2 of the CPU control
                        register (MMU + 16#101) and of its copy, the low
                        byte of MMU_$PID_PRIV, at IPL 7: set while no
                        address space owns the FPU, cleared when one
                        takes it.
    fp_state_in_cpu     the floating-point registers are the CPU's own:
                        FIM_$BUILD_DF neither aborts nor saves an FPU's
                        state (FIM_$FP_ABORT, FIM_$FSAVE), and the
                        delivery frame's FP save pointer is 0; there
                        is no line-F trap or FPU owner switch: an FP
                        instruction of another address space traps on
                        the FP ASID (FIM_$FP_TRAP), which switches the
                        registers; FIM_$FRESTORE is a return, and trap
                        1's entry for it is SVC_$UNIMPLEMENTED.
    fault_frame_addr    FIM_$BUILD_DF takes an access fault's address
                        from the exception frame's longword at +0x0A,
                        the information's status and instruction words
                        zero, where the other form decodes the frame by
                        its format; FIM_$GET_USER_SR_PTR looks for the
                        user's frame as format 4 vector 2 or format 8
                        vector 3 below format 0, and no other format.
    fim_fp_frame_margin FIM_$BUILD_DF keeps the user's stack 1208 bytes
                        above the private area and puts a stack it does
                        not take 1208 bytes above AS_$STACK_LOW: 1024 and
                        the MC68881's largest saved state, 184 bytes,
                        where the other form keeps 1024.
    fpu_enable_mmu_9    the FPU is enabled by bit 7 of the byte at MMU +
                        9, set while no address space owns it and
                        cleared when one takes it, and its routines
                        (FIM_$FLINE .. FIM_$FP_PUT_STATE, fim/sau6/)
                        work around the FPU interface: with
                        M68881_EXISTS clear an `fsave' is followed by a
                        write of 16#443E to the interface's register
                        16#FFFFFC0A, and the interface's registers at
                        16#FFFFFC82 and 16#FFFFFFF8 are reached with bit
                        5 (or 4) of the byte at MMU + 16#1B cleared;
                        where the other form writes the FPU owner
                        register.  OS_$INIT's vector table installs
                        FIM_$FP_PARITY for vector 127.
    fpa_board           the floating-point accelerator board: the
                        hand-written FIM_WIRED keeps its save-area base
                        FPA_$SAVEP and its owner FPA_$OWNER beside the
                        FPU's, and OS_$SHUTDOWN clears FPA_$SAVEP after
                        FP_$SAVEP; PEB_$INIT probes the board when
                        FPX_EXISTS is set, and PEB_$LOAD_WCS checks its
                        version and maps its save area before the
                        MC68881's.
}

%var fpu_enable_ccr fpu_enable_cpu_control fp_state_in_cpu fault_frame_addr
%var fim_fp_frame_margin fpu_enable_mmu_9 fpa_board

{ The memory parity statistics (mem/).

    mem_ccr_board_size  MEM_$INIT and MEM_$PARITY_LOG: the board size, 4
                        or 16 MB, from bit 3 of MMU_CCR; MEM_$INIT counts
                        the boards from MEM_$SIZE, and MEM_$PARITY_LOG
                        counts an error against its address div the board
                        size and matches a page record by its whole
                        address.
    mem_board_jumpers   MEM_$INIT and MEM_$PARITY_LOG: the memory
                        configuration from bits 16#74 of the SIO DUART's
                        input port; MEM_$INIT takes the board count, 1 to
                        4, from it, and MEM_$PARITY_LOG the board that
                        holds an error's address, by the address's MB
                        above the first, and matches a page record by the
                        address's low 24 bits.
    ecc_memory          the memory boards correct their errors: MEM_$INIT
                        finds each board's error-correcting controller
                        among the eight slots of its page of MEM, counts
                        the boards and turns reporting on, and
                        MEM_$ECCC_LOG, which the hand-written
                        FIM_$ECCC_TRAP calls, logs and counts a corrected
                        error by board and by page, quiets a board after
                        2000 of them, and crashes the system on an
                        uncorrectable one.  MEM_$MEM_REC's first word
                        is 1 and the board slots precede MEM_$SIZE.
    ecc6_memory         the memory boards correct their errors through
                        registers in each board's 128-byte page of MEM:
                        MEM_$INIT probes up to two boards, counts them,
                        adds each to MCSR_CONFIG and turns their
                        reporting on, and MEM_$ECCC6_LOG, which the
                        hand-written ECC trap calls with a board's
                        registers, logs and counts a corrected error by
                        board and by page and quiets a board after 2000
                        of them.  MEM_$MEM_REC's first word is 3 and its
                        page records hold the error's registers.
    mem_jumpers_16mb    with `mem_board_jumpers': the memory starts at 16
                        MB and each configuration's boards are four times
                        as large (MEM_$PARITY_LOG's limits); a page
                        record matches the address's low 26 bits; on a
                        board with the physical cache (ROADRUNNER)
                        MEM_$PARITY_LOG takes the board from the
                        configuration's halves and address bit 2;
                        MEM_$MEM_REC's first word is 16#2A.
}

%var mem_ccr_board_size mem_board_jumpers ecc_memory ecc6_memory
%var mem_jumpers_16mb

{ The memory parity errors (parity/).

    memory_parity       the memory's parity errors are handled: the
                        PARITY module, and AST_'s recovery from them, a
                        failed page frame dropped when it is clean
                        (AST_$REMOVE_CORRUPTED_PAGE) and the object of a
                        page whose memory failed while it was sent
                        marked in trouble (AST_$SAVE_CLOBBERED_UID,
                        AST_$SET_TROUBLE); and, for the ring controllers
                        without `ring_board_dma' and `ring8_controller',
                        their bus errors: RING_$SENDP asks PARITY_$CHK_IO
                        whether a transmit's was a parity error, and a
                        receive's crashes the system, where without the
                        part both are only counted.
    parity_err_regs     PARITY_$CHK reads the failing byte lanes from
                        MMU_BESR and the page from MMU_PEARH and
                        MMU_PEARL, sets bits of MMU_CCR around
                        CACHE_$CLEAR and while PAR_BUFF maps the page,
                        takes the page's address and ASID from AST_$PTOV
                        and scans 256 words of PAR_BUFF for the lane.
    parity_dma_pages    PARITY_$DMA_TABLE, three DMA channels of 32 page
                        numbers each, which PARITY_$SET_STATE fills;
                        PARITY_$CHK_IO takes the channel and PARITY_$CHK
                        flags the channel holding the failing page.
    parity_cpu_status   PARITY_$CHK reads the failing byte lanes from the
                        CPU status register (MMU) and the page from
                        MMU_$PARITY_PPN, clears bit 0 of MMU_$PID_PRIV's
                        privilege byte in the CPU control register while
                        PAR_BUFF maps the page, takes the page's address
                        and ASID from AST_$PTOV and scans 256 longwords
                        of PAR_BUFF for the lane; PARITY_$INFO is a
                        device to it.
    parity_dma_page_pairs
                        PARITY_$DMA_TABLE, three DMA channels of two page
                        numbers each, which PARITY_$SET_STATE fills;
                        PARITY_$CHK flags the failing page and
                        PARITY_$CHK_IO, given the channel and its pages,
                        tells which of the two it was.
    parity_cache_check  with `parity_cpu_status': PARITY_$CHK, on a
                        board with the physical cache (ROADRUNNER),
                        turns the cache off while it runs and crashes
                        the system with fault_$cache_parity when the
                        cache's register (MMU + 16#200) shows an error,
                        and takes status bit 14 for an error in the
                        second longword of the memory's 8-byte word
                        (PARITY_$INFO's word at 16#14); on any board it
                        takes the page number unmasked, only logs an
                        error with status bit 9 (an AT bus channel
                        check) and crashes the system with
                        fault_$io_chan_chk when that bit is set and no
                        lane failed.
}

%var memory_parity
%var parity_err_regs parity_dma_pages parity_cpu_status parity_dma_page_pairs
%var parity_cache_check

{ The floating-point hardware (peb/, xpd/).

    peb_board           the Performance Enhancement Board's driver: its
                        parity test, interrupt routine, register load
                        and unload, WCS writer and reader, and XPD_'s FP
                        routines testing PEB_$INFO (a 68881 first, else
                        the board), where the other form has PEB_ drive
                        the MC68881 alone.
    peb_setup           the PEB_ module's set-up, PEB_$INIT and
                        PEB_$LOAD_WCS, which OS_$INIT calls before IO_$INIT
                        and after NETWORK_$LOAD.
    peb_fpx             with `peb_setup': the FPX floating-point
                        accelerator, FPX_EXISTS (PEB_UNWIRED's first
                        byte, before M68881_EXISTS): PEB_$INIT tests it
                        first, an FPX asking for the FP save area as an
                        MC68881 does (PEB_$INFO's savep_flag), and either
                        gets FIM_$FLINE at the line-F vector;
                        PEB_$LOAD_WCS's check disables the FPX's save
                        area as it does the 68881's.
}

%var peb_board peb_setup peb_fpx

{ The exception vector page (the PROM's cells, arch/, dtty/m68k/).

    trap_page_high      the vector page and the PROM's entry cells
                        (TRAP_PAGE) are in the kernel's data, not at 0:
                        the hand-written DTTY_WIRED reaches the PROM's
                        putc, font reload and clear cells at
                        TRAP_PAGE + 0x108, 0x114 and 0x140.
}

%var trap_page_high

{ The interrupts' PC histogram (io/m68k/).

    interrupt_pc_histogram
                        the first-level interrupt dispatcher stores the
                        interrupted PC in HISTOGRAM_ADDRESS.
}

%var interrupt_pc_histogram

{ The lights drawn on the display (misc/m68k/).

    display_lights      DISP_LITES, SMD_$LITES's hand-written routine
                        that draws the 16 lights into the first display's
                        memory.
}

%var display_lights

{ The null process (os/m68k/).

    null_process_spins  NULLPROC's idle loop forces IPL 0 and branches
                        back, where the other form loops on the stop
                        instruction.
}

%var null_process_spins

{ The kernel's first translation tables (os/cold.pas).

    cold_proc_tables    the OS_COLD module: OS_$COLD_START in the
                        COLD_PROC section and its boot map in COLD, both
                        run by COLD before the MMU is on.
    cold_ram_16mb       with `cold_proc_tables': the RAM starts at 16 MB:
                        the kernel is loaded at 0x1003C00 for OS_PROC,
                        DUMP's copy is at 0x1000C00, the root table at
                        0x1001400, MMAP's first page is 0x4000 (0x80000
                        bytes cleared), COLD's segment is 512; COLD
                        moves the kernel past its first 0x54000 bytes to
                        the pages from MOVE_TO_PPN, where cold_phys and
                        the boot map's entry of page count 0 find it.
    cold_probed_devices with `cold_proc_tables': the boot map has 29
                        entries; OS_$COLD_START maps the kernel's and
                        the I/O pages' first, then by COLD's flags
                        (mem_flags) the physical cache's tags and the
                        display's registers and memory, and stores the
                        display's CSR and frame pages and counts in
                        COLD's remap cells (COLD_REMAP_*); without flag
                        2 the segment descriptors are shared globally.
}

%var cold_proc_tables cold_ram_16mb cold_probed_devices

{ The hardware timers (timer/, time/).

    timer_dcte          the timer is a device, TIMER_DCTE, whose
                        initialization routine IO_$INIT's device walk
                        calls: TIMER_$INIT sets the TIMER block up from
                        TIME_$SYS_FREQ, programs the real-time counter
                        with 4167, and enables the interrupts
                        16#A9..16#AB.
    timer_int_pic       the timers' interrupt comes through the first
                        interrupt controller (PIC1): TIME_$TIMER_HANDLER
                        acknowledges it there and serves every timer that
                        is pending before it leaves, the word after
                        TIME_$CURRENT_DELTA's MCR countdown telling whether
                        it served any (if none, the interrupt is
                        spurious); a clock carry advances TIME_$CLOCKH_EC
                        without dispatching and calls MMU_$MCR_CHANGE(1).
}

%var timer_dcte timer_int_pic

{ The network buffers (netbuf/).

    netbuf_cache_inhibit
                        NETBUF_$ADD_PAGES and NETBUF_$GET_HDR make each
                        header page uncached (MMU_$CACHE_INHIBIT_VA)
                        once it is in the window, before they clear it.
}

%var netbuf_cache_inhibit

{ The internet interface controller (iic/).

    iic_driver          the IIC driver, a PBU controller with a NET_IO
                        port per line; OS_$INIT calls IIC_$INIT after
                        NETWORK_$INIT, and the IIC_ system calls.  The
                        other form is nine stubs.
}

%var iic_driver

{ The circular buffer manager (cbuf/).

    circular_buffers    the CBUF module, whose circular buffers the line
                        printer driver (`lpr_driver') uses.
}

%var circular_buffers

{ The ring transmit light (ring/).

    ring_xmit_light     RING_$SENDP toggles a light of the memory control
                        register (MMU_$MCR_CHANGE) when a send has
                        completed, before it reads the transmit status.
}

%var ring_xmit_light

{ The I/O manager's buses and configuration (io/).

    mbus_dev_routines   IO_$BUS_EPV's Multibus entry holds
                        MBUS_$ENABLE_DEV and MBUS_$DISABLE_DEV.
    mbus_map_reserved   IO_'s Multibus I/O map starts with the range
                        16#70000..16#80000 taken.
    pbu_alloc_mbus      IO_$ALLOC allocates in the Multibus's map (bus 2)
                        below 1 MB, whatever the unit's bus, where the
                        other form takes the unit's bus and no limit.
    winchester_config   a Winchester DCTE and IO_$GET_CONFIG's report of
                        it; SYSBUS_$INIT traps DISK_INTERRUPT and keeps
                        the Winchester's and the floppy's DCTEs.
    iic_port_config     IO_$GET_CONFIG reports the internet interface
                        controller (member 2 of the second set) when one
                        of its routing ports is active.
    pbu_config_always   IO_$GET_CONFIG reports the PBU (member 1 of the
                        third set) without a test.
    pbu_alloc_atbus_windows
                        IO_$ALLOC allocates only at a fixed address, and
                        for a unit on the AT bus within the window of
                        the bus's memory that holds it, 16#80000..
                        16#100000 or 16#900000..16#1000000.
    mbus_map_64k        the Multibus's I/O map is 64 KB: IO_$ALLOC
                        allocates below 16#10000 (with `pbu_alloc_mbus'),
                        IO_$ALLOC_MAP in 16#0..16#10000 for every unit,
                        and a region's page is its start's page plus 192
                        (IO_$ALLOC_MAP, PBU2_$ALLOCATE_MAP,
                        pbu_clear_iomap); PBU_$SETUP gives no unit the
                        wide map, and PBU_$GET_INFO's second word is 1.
    mcb_config_member_0 with `pbu_mcb_config': PBU_$MCB's flag gives
                        member 0 of the third set instead of member 1.
    io_atbus_map_windows
                        with `pbu_alloc_atbus_windows' and
                        `io_regions': IO_$ALLOC takes a range at no fixed
                        address (iova 0) from the AT bus's 0..16#80000,
                        and its second window is 16#100000..16#1000000;
                        IO_$ALLOC_MAP takes an AT bus unit's region from
                        0..16#80000 for a bus master (attribute 0), else
                        from 16#80000 to 16#90000, or to 16#A0000 with
                        io_$attr_wide_iomap.
}

%var mbus_dev_routines mbus_map_reserved pbu_alloc_mbus winchester_config
%var iic_port_config pbu_config_always pbu_alloc_atbus_windows
%var mbus_map_64k mcb_config_member_0
%var io_atbus_map_windows

{ The Multibus adapter (mbus/).

    mbus_polled_adapter  MBUS_$INIT installs MBUS_$INT for one vector,
                         16#1C, and gives levels 0..7 MBUS_$UNDEF_INT;
                         MBUS_$INT reads the adapter's register once and
                         takes the first level from 7 down whose bit and
                         pending bit are set; MBUS_$HIGH_OK is bit 5 of
                         the probed register.
    mbus_vectored_adapter
                         MBUS_$INIT traps the vectors 16#B0..16#B7 to
                         MBUS_$INT, one per level, gives levels 0..7
                         MBUS_$UNDEF_INT, probes the adapter's register
                         at +0x80 by a write and clears MBUS_$HIGH_OK;
                         MBUS_$INT takes the vector, acknowledges the
                         level at +0x80 and masks it at +0x82 while its
                         handler runs.
    mbus_vectored_enable MBUS_$INIT traps the vectors 16#B0..16#B6 to
                         MBUS_$INT, one per level, and sets the adapter's
                         word at +4 to 16#1B05; MBUS_$INT takes the vector
                         and clears the level's enable bit while its
                         handler runs, setting it again when the handler
                         returns true.
}

%var mbus_polled_adapter mbus_vectored_adapter mbus_vectored_enable

{ The display and the line printer (os/, smd/, term/, kbd/, dtty/,
  lpr/).

    display_driver      the display driver (SMD's code) and the touch
                        pad (TPAD): OS_$INIT starts them before
                        DTTY_$INIT, probes the display and makes its
                        ASTE, and takes the terminal's mode from boot
                        flags 0 and 1; the display console's terminal
                        line, keyboard and drain handlers (term/, kbd/,
                        sio/), the display TTY (dtty/), the display
                        routines of the hand assembly and the display's
                        system calls.  The other form's SMD routines are
                        stubs, with no unit valid.
    lpr_driver          the line printer driver (lpr/): OS_$INIT calls
                        LPR_$INIT after RING_$GET_ID, and the LPR_ system
                        calls.
    lpr_pbu_unit        with `lpr_driver': the printer port is the PNA's
                        (the PBU's unit 6, in PBU_CTL's page): LPR_$ACQUIRE
                        sets the unit up with PBU_$ACQUIRE_INT for
                        LPR_$INT, LPR_$WRITE enables it with
                        PBU_$ENABLE_DEVICE, LPR_$RELEASE sets it down,
                        LPR_$INIT finds the PNA by PBU_$MCB's present bit;
                        no modes (LPR_$STATE refuses a mode).  The other
                        form drives the port at LPR on the level 5
                        autovector, with three modes.
}

%var display_driver lpr_driver lpr_pbu_unit

{ The PBU units (pbu/).

    pbu_8_units         8 PBU units, 0..7, instead of 16: the DCTE
                        table's size, the unit loops' bound, and
                        PBU_$PPN_OWNERS a byte per physical page instead
                        of a word.
    pbu_wire_special    PBU_$WIRE_SPECIAL's body, where the other form
                        returns a count of 0 and
                        status_$pbu_not_supported.
    pbu_atbus_units     the PBU's units are the AT bus's: PBU_$SETUP
                        takes a unit's CSR pages as 8-byte groups of the
                        bus's I/O ports (16#100..16#3FF), PBU_ASM holds 16
                        DCTEs, PBU2_$ASSOC maps an AT bus unit's
                        controller memory, the CSR routines read and
                        write the registers directly, PBU_$WIRE_SPECIAL
                        can allocate a physically contiguous buffer
                        (options member 1), PBU_$SHUTDOWN leaves unit 3
                        set up, PBU_$RELEASE_INT notes the unit in
                        PBU_$NONSYS_DEVICE, and PBU_MAP's DMA entries
                        drive the bus's DMA channels (`atbus_dma');
                        the other form's units are the Multibus's and
                        the VME bus's.
    pbu_transfer_control
                        PBU_$CONTROL's body and a new unit's transfer
                        control from the module's initial value, where
                        the other form's PBU_$CONTROL answers [] and
                        refuses with status_$pbu_not_supported and a
                        unit's control is 0.
    mbus_low_window     the Multibus is one 64 KB window of the physical
                        address space at 16#10000: a unit's controller
                        memory is mapped from page 16#40 (PBU2_$ASSOC)
                        and its CSR pages from page 16#60 (PBU_$SETUP),
                        where the other form maps the memory from page
                        16#200, or 16#C00 for an address from 16#80000,
                        and the CSR pages from page 16#1C0.
    pbu_iomap_unmap     with `pbu_atbus_units': the units' freed I/O map
                        space is cleared through IOMAP_$UNMAP (the AT
                        bus's I/O map, iomap/) where the other forms
                        write the map's entries.
    pbu_ppns_4000       PBU_$PPN_OWNERS is a word per physical page from
                        16#4000 to 16#BFFF.
    pbu_dma_iomap       with `pbu_atbus_units' and `io_regions': the DMA
                        entries reach the buffer through the unit's I/O
                        map space: PBU_$DMA_START maps it (PBU2_$MAP,
                        after PBU2_$ALLOCATE_MAP when the unit has no
                        space) and keeps the mapping in the unit's record
                        for the channel (PBU_$MAPPED_INFO), PBU_$DMA_STOP
                        unmaps it, PBU2_$DMA_START checks its bus address
                        against the space; PBU2_$MAP and PBU2_$UNMAP take
                        a unit with its attribute set at page-aligned bus
                        addresses; PBU_$SETUP and PBU_$FREE_MAP clear a
                        byte of the unit's records.  The other form
                        checks a buffer's pages are contiguous and passes
                        their physical address, and its PBU2_$DMA_START
                        is PBU_$DMA_START's.
    pbu_vme_windows     with `vme_bus': the turbo boards' VME windows:
                        PBU2_$ASSOC takes a VME unit's memory in
                        16#310000..16#3FFFFF (the Multibus's upper half
                        free when the memory reaches 16#380000),
                        16#200000..16#2FFFFF, 16#600000..16#FFFFFF
                        (16#600000..16#7FFFFF when display unit 1 or 2
                        is the GPU's) and 16#3000000..16#3FFFFFF, where
                        the other form takes 16#380000..16#3FFFFF with
                        the Multibus's upper window allowed; PBU_$SETUP
                        takes a VME unit's CSR pages in 16#0..16#8000 or
                        16#C000..16#D000, those of the short space
                        outside 16#C000..16#D000 mapped from 16#300000.
    pbu_iomap_page_mask pbu_map_owned_ppn answers a page number's low 14
                        bits, the I/O map entry's page field.
}

%var pbu_iomap_unmap pbu_ppns_4000 pbu_dma_iomap
%var pbu_vme_windows pbu_iomap_page_mask
%var pbu_8_units pbu_wire_special pbu_atbus_units pbu_transfer_control
%var mbus_low_window

{ The calendar, the PBU status call, the crash restart and the lights
  (time/, cal/, svc/, misc/m68k/; the hand assembly's `.if' arms).

    calendar_own_page   the calendar has a page of its own, with the
                        MSM5832's registers at its start: TIME_$READ_CAL
                        writes the control at +0 and the data at +2, and
                        reads the digits at +4, inverted.
    calendar_write_unconditional
                        CAL_$WRITE_CALENDAR writes the calendar without
                        a test of NETWORK_$REALLY_DISKLESS.
    pbu_get_status      the PBU_$GET_STATUS system call (trap 3's entry
                        16#3B): the PBU's control words and status.
    crash_prom_restart  CRASH_SYSTEM always ends in a restart through the
                        PROM's cell 16#128: a clean restart at
                        DUMP_$AUTO_REBOOT's physical address, code 16#FF
                        on a shutdown, 16#F1 at DUMP + 4 on a crash.
    display_lights_stub DISP_LITES is a return and a zero word.
    crash_remap_cold_display
                        the crash console's REMAP_DISPLAY maps the display
                        COLD found: REMAP_CSR_CNT pages from REMAP_CSR_PPN
                        at DISP1, then REMAP_FRM_CNT pages from
                        REMAP_FRM_PPN at DISP1_MEM, where the other form
                        maps 128 pages from PPN 16#4000 at DISP1_MEM.
    calendar_timer_page the MSM5832's registers are bytes of the timer's
                        page (CALENDAR = TIMR): TIME_$READ_CAL and
                        CAL_$WRITE_CALENDAR write the control at +16#81
                        and the data at +16#83, and read the digits at
                        +16#85, inverted, where the other form's are at
                        +16#20, +16#22 and +16#24 of the calendar page.
    cache_clear_stub    CACHE_$CLEAR is a return (the CPU has no CACR),
                        and FIM_$DELIVER_TRACE_FAULT, FIM_$CLEAR_TRACE_FAULT
                        and FIM_$EXIT do not call it after they patch
                        FIM_$EXIT's first word.
    mmu_status_word     the MMU's fault status is the word at MMU + 2:
                        FIM_$BUS_ERR, PROC1_$DISPATCH and IO_$PROBE clear
                        it with a word store, where the other form clears
                        the byte at MMU + 3.
    mmu_status_bit_6    the MMU's fault status is bit 6 of the byte at
                        MMU + 3: PROC1_$DISPATCH and IO_$PROBE clear that
                        bit alone, where the other form clears the byte;
                        FIM_$BUS_ERR (fim/sau6/) keeps the status word
                        in MMU_$BUS_STATUS and clears its bit 6; it,
                        FIM_$FLINE and FIM_$COLD_BUS_ERR read the MMU's
                        word at MMU + 16#E first.
    fim_vme_ack         FIM_WIRED's handlers acknowledge the VME
                        adapter (bits 16#440 of its control word, VME_CTL
                        + 8): JMP_TO_BUS_ERR before its jump, and
                        FIM_$SPURIOUS_INT when the adapter's interrupt
                        is pending (VME_CTL + 8 bit 6, + 16#90 bit 7);
                        FIM_$BUS_ERR saves the VME state, which
                        IO_$PROBE's bus error path then does not.
    probe_settle_read   IO_$PROBE reads the word at 16#400 after a
                        completed access, before it disarms
                        BUS_ERROR_SWITCH.
    probe_settle_calls  IO_$PROBE waits after a completed access with two
                        calls of its own return, before it disarms
                        BUS_ERROR_SWITCH.
    mcr_change_low_bits the timer interrupt's every other CLOCKH step
                        calls MMU_$MCR_CHANGE with 16#10F, which flips
                        the low four bits of the MCR's copy, where the
                        other form passes 7.
    mcr_change_bit_0    the timer interrupt's every other CLOCKH step
                        calls MMU_$MCR_CHANGE with 1, where the other
                        form passes 7.
    crash_cache_check   CRASH_SYSTEM first runs CRASH_CHK_CACHES, which
                        reports the data cache's RAM failures from the
                        CPU's failure log, and its restart is the
                        SAU3's through the PROM's cell 16#128 with the
                        SAU9's restart check and keyboard reset: the
                        module is another form.
    crash_win6_save     CRASH_SYSTEM first copies the eight longwords at
                        +16#1FC0 of the second Winchester board's
                        command blocks (WIN_$DT's first longword, when
                        set) to +16#1F40; its restart is the one of
                        `crash_cache_check' without the cache check, and
                        its REMAP_DISPLAY maps the graphics processor's
                        and the color board's displays: the module is
                        another form.
    sr_user_bits_76     the status register's bits 7 and 6 belong to the
                        user's state: FIM_$SINGLE_STEP and
                        FIM_$FAULT_RETURN keep them, and not T0, in the
                        SR they return with (mask 16#80DF, the other
                        form's 16#C01F), and FIM_$GET_USER_SR_PTR accepts
                        a user frame's SR with them set.
    crash_cache_off     CRASH_SYSTEM (unless the status is 16#000B0008,
                        manual stop) and FIM_$CRASH first turn the
                        physical cache off, a zero byte stored at MMU +
                        16#200, on a ROADRUNNER board or an MC68020 CPU
                        (M68030 clear).
}

%var calendar_own_page calendar_write_unconditional pbu_get_status
%var crash_prom_restart display_lights_stub crash_remap_cold_display
%var calendar_timer_page cache_clear_stub mmu_status_word mmu_status_bit_6
%var fim_vme_ack
%var probe_settle_read probe_settle_calls mcr_change_low_bits mcr_change_bit_0
%var crash_cache_check sr_user_bits_76 crash_cache_off crash_win6_save

{ Each SAU's parts: one block per SAU, its parts in the order of their
  `%var's above, one `%enable' line for each section's parts. }

{ sau2: the DN300, DN320 and DN330. }
%if sau2 %then
  %enable dma_driver;
  %enable sysbus_routines, floppy_disk;
  %enable winchester_ctlr;
  %enable ring_node_id;
  %enable boot_time_lock;
  %enable pft_mmu;
  %enable memory_parity;
  %enable peb_board, peb_setup;
  %enable display_lights;
  %enable ring_xmit_light;
  %enable winchester_config;
  %enable display_driver;
%endif

{ sau3: the DSP80, DSP80A and DSP90. }
%if sau3 %then
  %enable dma_driver, mt_driver, pbu_driver;
  %enable mbus_bus, sysbus_routines, smd_disk, io_regions;
  %enable power_off_check, crash_reboot, ring_node_id;
  %enable pft_mmu;
  %enable memory_parity;
  %enable peb_setup;
  %enable iic_driver;
  %enable circular_buffers;
  %enable mbus_map_reserved, pbu_alloc_mbus, iic_port_config;
  %enable pbu_config_always;
  %enable mbus_polled_adapter;
  %enable lpr_driver;
  %enable pbu_8_units, pbu_transfer_control;
  %enable calendar_own_page, calendar_write_unconditional, pbu_get_status;
  %enable crash_prom_restart, display_lights_stub;
%endif

{ sau4: the DN460, DN660 and DSP160. }
%if sau4 %then
  %enable mt_driver, pbu_driver;
  %enable mbus_bus, sysbus_routines, smd_disk, floppy_disk, floppy_page_dma;
  %enable pbu_mcb_config;
  %enable io_regions;
  %enable floppy_dcte_request;
  %enable sysbus_int_vec, sysbus_vectors_90;
  %enable second_display_unit, dtty_color_board;
  %enable sio2681_four_lines;
  %enable winchester_ctlr, win_ring_disk_ctlr;
  %enable word_iomap;
  %enable ring_board_dma;
  %enable power_off_check, power_down, power_off_csr;
  %enable shutdown_keeps_fp_savep, disp2_probe, color_board;
  %enable color_board_iomap, crash_reboot;
  %enable ring_node_id;
  %enable boot_flags_server, fp_five_exceptions, mmu_fault_vectors;
  %enable io_space_0ff;
  %enable two_display_units, color_displays, blt_request_start;
  %enable blt_main_memory;
  %enable large_vm, vm_2432_astes, pmap_threads, vm_regions;
  %enable mmap_ppns_200_3fff, mst_7168_words, vm_8192_segs, region_mmu;
  %enable region_registers;
  %enable set_mstes_no_cache_clear;
  %enable fp_state_in_cpu, fault_frame_addr;
  %enable ecc_memory;
  %enable null_process_spins;
  %enable circular_buffers;
  %enable ring_xmit_light;
  %enable pbu_alloc_mbus, winchester_config, mbus_map_64k;
  %enable mcb_config_member_0;
  %enable mbus_vectored_adapter;
  %enable display_driver, lpr_driver, lpr_pbu_unit;
  %enable pbu_8_units, mbus_low_window;
  %enable calendar_write_unconditional;
  %enable calendar_timer_page, cache_clear_stub, mmu_status_word;
  %enable probe_settle_read, mcr_change_low_bits, crash_cache_check;
  %enable sr_user_bits_76;
%endif

{ sau5: the DN550, DN560, DN570, DN580 and DN590. }
%if sau5 %then
  %enable ct_driver, gpu_driver, mt_driver, pbu_driver, tape_boot;
  %enable vme_bus, mbus_bus, smd_disk, pbu_mcb_config, io_regions;
  %enable few_io_regions;
  %enable ct_qic02;
  %enable two_request_servers;
  %enable second_display_unit;
  %enable winchester_ctlr, win_descriptor_ctlr;
  %enable long_iomap;
  %enable ring_controller_dma, ring_vector_regs, ring_owner_test_reversed;
  %enable power_off_check, power_down, vme_power_off, disp2_probe, color_board;
  %enable ring_node_id;
  %enable two_display_units, color_displays, blt_request_start;
  %enable crash_report_blank_lines, calendar_word_port;
  %enable boot_time_lock;
  %enable pft_mmu;
  %enable memory_parity;
  %enable peb_board, peb_setup;
  %enable display_lights;
  %enable ring_xmit_light;
  %enable mbus_dev_routines, winchester_config;
  %enable display_driver;
  %enable pbu_wire_special, pbu_transfer_control;
%endif

{ sau6: the DN560T, DN570T, DN580T and DN590T. }
%if sau6 %then
  %enable ct_driver, ethernet_driver, gpu_driver, mt_driver, pbu_driver;
  %enable tape_boot;
  %enable ethernet_vme;
  %enable vme_bus, mbus_bus, sysbus_routines, smd_disk, pbu_mcb_config;
  %enable vme_vectored_ints;
  %enable sm_c_clear_go;
  %enable io_regions, few_io_regions;
  %enable sysbus_int_vec, sysbus_vectors_88;
  %enable ct_qic02;
  %enable ct_vectored_ctlr, ct_wait_ends_busy, ct_owner_test_reversed;
  %enable dtty_gpu;
  %enable kbd_tone, kbd_key_ring_512, kbd_commands, sio2681_four_lines;
  %enable kbd_type_sysrev, sio2681_vec_by_chip, pchist_third_line;
  %enable winchester_ctlr, win6_ct6_board;
  %enable win_descriptor_ctlr;
  %enable win_vectored_ctlr;
  %enable long_iomap;
  %enable ring_controller_dma;
  %enable ring_id_not_found, ring_sysbus_vector, ring_lights_8_4;
  %enable power_off_check, power_down, disp2_probe, crash_reboot, ring_node_id;
  %enable fim_nmi, shutdown_kbd_mode;
  %enable boot_flags_diskless, boot_flags_server, vme_undef_vectors;
  %enable node_id_boot_record, fpx_eco_check, io_space_7ff;
  %enable color2_shutdown_in_smd;
  %enable two_display_units, color_displays, blt_request_start;
  %enable gpu_displays_only;
  %enable gpu_own_vectors, gpu_reset_registers;
  %enable tpad_block_head;
  %enable calendar_mapped_rtc;
  %enable large_vm, vm_5760_astes, pmap_threads, vm_regions;
  %enable find_touches, region_mmu;
  %enable mmap_ppns_4000, mst_55808_words, mst_pages_tiered, vm_65536_segs;
  %enable va_to_aste_smap_bit_0;
  %enable fim_fp_frame_margin, fpu_enable_mmu_9;
  %enable ecc6_memory;
  %enable peb_setup;
  %enable peb_fpx;
  %enable display_lights;
  %enable null_process_spins;
  %enable ring_xmit_light;
  %enable winchester_config;
  %enable mbus_vectored_enable;
  %enable display_driver;
  %enable pbu_wire_special, pbu_transfer_control;
  %enable pbu_vme_windows;
  %enable pbu_iomap_page_mask;
  %enable mmu_status_bit_6, fim_vme_ack, probe_settle_calls, mcr_change_bit_0;
  %enable crash_win6_save;
%endif

{ sau7: the DN3500, DN3550, DN4000 and DN4500. }
%if sau7 %then
  %enable color4_driver, color5_driver, color6_driver, color7_driver;
  %enable ct_driver, dma_driver;
  %enable atbus_dma;
  %enable atbus_dma_iomap;
  %enable ethernet_driver, mono_driver, pbu_driver, scsi_driver, tape_boot;
  %enable floppy_disk, floppy_atbus, io_regions;
  %enable floppy_iomap, floppy_long_delays;
  %enable iomap_routines;
  %enable ethernet_int_unmasked;
  %enable ethernet_long_polls;
  %enable io_descriptors;
  %enable named_dctes;
  %enable atbus_routines, atbus_pics;
  %enable atbus_irq8_unmasked;
  %enable ring_8025_driver, ring_8025_dma_channel;
  %enable ring_8025_iomap;
  %enable ring_8025_rif_sum_reversed;
  %enable ct_qic02, ct_scsi, ct_atbus_qic02;
  %enable ct_iomap;
  %enable scsi_mailbox_ctlr;
  %enable pbu_iomap_unmap, pbu_ppns_4000;
  %enable pbu_dma_iomap;
  %enable word_iomap;
  %enable kbd_tone, kbd_key_ring_512, kbd_commands;
  %enable sio2681_four_lines, sio2681_vec_by_chip, kbd_reset_chan_a;
  %enable sio2681_acr_timer, sio2681_chip_2_pbu_8;
  %enable sio2681_pbu_int, sio2681_modem_op3_op0;
  %enable winchester_ctlr, win_atbus_ctlr;
  %enable win_mailbox_ctlr;
  %enable ring_owner_test_reversed, ring8_controller, nodeid_prom_probe;
  %enable ring_pkt_index_reversed;
  %enable crash_reboot, smd_display_memory, calendar_service_mode, fim_nmi;
  %enable vector_alignment_check, shutdown_kbd_mode;
  %enable boot_flags_diskless, pbu_wire_at_boot, boot_flags_server;
  %enable nmi_vector_30;
  %enable pic_vector_cells;
  %enable boot_record_bus;
  %enable physical_cache_enable;
  %enable fpa_board;
  %enable display_devices;
  %enable smd_unit_280_bytes;
  %enable calendar_mapped_rtc;
  %enable crash_remap_cold_display;
  %enable crash_cache_off;
  %enable large_vm, vm_5760_astes, pmap_threads, pmmu_page_maps;
  %enable pmap_cache_inhibit, large_address_space, vm_regions;
  %enable bst_va_lookup, find_touches;
  %enable mmap_ppns_4000_bfff;
  %enable smap_shared_global_68851;
  %enable cpu_status_register;
  %enable dispatch_clear_sc_page;
  %enable flush_virtual_68030;
  %enable fpu_enable_cpu_control;
  %enable timer_int_pic;
  %enable mem_board_jumpers, mem_jumpers_16mb;
  %enable memory_parity, parity_cpu_status, parity_dma_page_pairs;
  %enable parity_cache_check;
  %enable peb_setup;
  %enable trap_page_high;
  %enable null_process_spins;
  %enable cold_proc_tables;
  %enable cold_ram_16mb;
  %enable cold_probed_devices;
  %enable netbuf_cache_inhibit;
  %enable ring_xmit_light;
  %enable winchester_config, pbu_alloc_atbus_windows;
  %enable io_atbus_map_windows;
  %enable display_driver;
  %enable pbu_wire_special, pbu_atbus_units;
%endif

{ sau8: the DN3000, DN3010, DN3010A and DN3040. }
%if sau8 %then
  %enable color4_driver, color5_driver, ct_driver, dma_driver, ethernet_driver;
  %enable atbus_dma;
  %enable mono_driver, pbu_driver, tape_boot;
  %enable floppy_disk, floppy_atbus;
  %enable io_descriptors;
  %enable named_dctes;
  %enable atbus_routines, atbus_pics;
  %enable ring_8025_driver, ring_8025_dma_channel, ring_8025_no_data_bursts;
  %enable ethernet_int_unmasked, ethernet_short_polls;
  %enable ct_qic02, ct_atbus_qic02;
  %enable kbd_tone, kbd_key_ring_512, kbd_commands, console_sio2681;
  %enable sio2681_pbu_int, sio2681_modem_op3_op0;
  %enable winchester_ctlr, win_atbus_ctlr;
  %enable ring_owner_test_reversed, ring8_controller, nodeid_prom_probe;
  %enable crash_reboot, smd_display_memory, calendar_service_mode;
  %enable shutdown_kbd_mode;
  %enable early_as_init, boot_flags_diskless, pbu_wire_at_boot;
  %enable calendar_mapped_rtc;
  %enable crash_remap_cold_display;
  %enable atbus_int8_dummy, vector_seg_prot, boot_flags_server;
  %enable parity_trap_vector_30;
  %enable display_devices;
  %enable large_vm, vm_1536_astes, pmap_threads, pmmu_page_maps;
  %enable bst_va_lookup, find_touches;
  %enable mmap_ppns_400, mst_7168_words, vm_regions, run_time_layout;
  %enable smap_shared_global;
  %enable cpu_status_register;
  %enable fpu_enable_cpu_control;
  %enable timer_int_pic;
  %enable mem_board_jumpers;
  %enable memory_parity, parity_cpu_status, parity_dma_page_pairs;
  %enable peb_setup;
  %enable null_process_spins;
  %enable ring_xmit_light;
  %enable winchester_config, pbu_alloc_atbus_windows;
  %enable display_driver;
  %enable pbu_wire_special, pbu_atbus_units;
%endif

{ sau9: the DN2500. }
%if sau9 %then
  %enable ct_driver, ethernet_driver, scsi_driver, tape_boot;
  %enable sysbus_routines;
  %enable io_descriptors;
  %enable named_dctes;
  %enable sysbus_int_vec, util_pic, atbus_routines;
  %enable mono9_display;
  %enable ring_8025_driver;
  %enable win_scsi_disk;
  %enable ct_scsi;
  %enable ct_reset_delay;
  %enable kbd_tone, kbd_key_ring_512, sio16550_lines, kbd_commands;
  %enable ring_owner_test_reversed, ring8_controller, nodeid_prom;
  %enable crash_reboot, smd_display_memory, calendar_service_mode, fim_nmi;
  %enable vector_alignment_check, prom_config_record, shutdown_kbd_mode;
  %enable display_devices;
  %enable calendar_indexed_rtc;
  %enable large_vm, vm_5760_astes, pmap_threads, pmmu_page_maps;
  %enable pmap_cache_inhibit, mmap_ppns_10000, large_address_space;
  %enable bst_va_lookup, find_touches;
  %enable vm_regions;
  %enable cacr_clear_data;
  %enable fpu_enable_ccr;
  %enable mem_ccr_board_size;
  %enable memory_parity, parity_err_regs, parity_dma_pages;
  %enable peb_setup;
  %enable trap_page_high;
  %enable interrupt_pc_histogram;
  %enable null_process_spins;
  %enable cold_proc_tables;
  %enable timer_dcte;
  %enable netbuf_cache_inhibit;
  %enable ring_xmit_light;
  %enable winchester_config;
  %enable display_driver;
%endif
