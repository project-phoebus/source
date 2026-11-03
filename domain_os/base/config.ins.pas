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
    color7_driver    the COLOR7 display driver (color7/).
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

%var color4_driver color5_driver color7_driver ct_driver dma_driver
%var atbus_dma
%var ethernet_driver gpu_driver mono_driver mt_driver pbu_driver scsi_driver
%var tape_boot

{ The buses, the controllers and the I/O map regions (io/).

    vme_bus          the VME bus (vme/): its entry in IO_$BUS_EPV, its
                     I/O map, VME_$INT and VME_$ERR_INT for vectors 28
                     and 29, and the PBU's units 8..15 on the bus.
    mbus_bus         the Multibus (mbus/): its entry in IO_$BUS_EPV and
                     its I/O map.
    sysbus_routines  SYSBUS_$INIT and SYSBUS_$DEFINE_INT in the system
                     bus's IO_$BUS_EPV entry, and the ring DCTE's
                     interrupt vector.
    smd_disk         the storage module disk drivers (sm/, sm_c/), their
                     DCTEs, and the controller in IO_$GET_CONFIG.
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
    pbu_mcb_config   IO_$GET_CONFIG reports the PBU (member 1 of the
                     third set) when PBU_$MCB's flag is set.
    io_regions       IO_$ALLOC_MAP and IO_$FREE_MAP take the I/O maps'
                     ranges from a free list of region nodes that
                     IO_$INIT builds; without it the PBU's IO_$ALLOC_MAP,
                     IO_$FREE_MAP and IO_$FREE_MAP_REGION refuse with
                     status_$pbu_not_supported.
    few_io_regions   that list has 8 nodes instead of 64.
}

%var vme_bus mbus_bus sysbus_routines smd_disk floppy_disk floppy_atbus
%var pbu_mcb_config io_regions few_io_regions

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
}

%var named_dctes

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
}

%var sysbus_int_vec util_pic atbus_routines atbus_pics

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
}

%var ring_8025_driver ring_8025_dma_channel ring_8025_no_data_bursts

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
}

%var ethernet_int_unmasked ethernet_short_polls

{ The SCSI Winchester disk driver (win_scsi/).

    win_scsi_disk    the WIN_SCSI_ disk driver and its eight units'
                     DCTEs.
}

%var win_scsi_disk

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
}

%var ct_qic02 ct_scsi ct_atbus_qic02

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
}

%var second_display_unit

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
    sio2681_pbu_int   SIO2681_$INIT, after storing the chip's interrupt
                      routine in SIO_VEC, acquires the chip's interrupt
                      as PBU unit 1 (PBU_$ACQUIRE_INT).
}

%var kbd_tone kbd_key_ring_512 sio16550_lines kbd_commands console_sio2681
%var sio2681_pbu_int

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
}

%var winchester_ctlr win_descriptor_ctlr win_atbus_ctlr

{ The I/O map entries of the storage module, tape and PBU drivers (sm/,
  sm_c/, mt/, pbu/).

    long_iomap       the drivers write IOMAP's entries as longwords: the
                     physical page number plus 16#48000, or plus a
                     unit's whole transfer control (PBU2_); the other
                     form writes a word field of each entry, the page
                     number plus 16#8000.
}

%var long_iomap

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
}

%var ring_controller_dma ring_vector_regs ring_owner_test_reversed
%var ring8_controller nodeid_prom nodeid_prom_probe

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
    disp2_probe       OS_$INIT probes for a second display and installs
                      DISPLAY2_$UID's ASTE when one answers;
                      DISP2_PRESENT holds the answer.
    color_board       the COLOR_ color graphics board (color/): OS_$INIT
                      calls COLOR_$COLD_INIT and probes the board as the
                      second display when the first probe fails,
                      OS_$SHUTDOWN calls COLOR_$SHUTDOWN, SMD uses the
                      board's routines for display types 3 and 4, and
                      the COLOR_ system calls.
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
}

%var power_off_check power_down vme_power_off disp2_probe color_board
%var crash_reboot ring_node_id smd_display_memory calendar_service_mode
%var fim_nmi vector_alignment_check prom_config_record shutdown_kbd_mode
%var early_as_init boot_flags_diskless pbu_wire_at_boot atbus_int8_dummy
%var vector_seg_prot boot_flags_server parity_trap_vector_30

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
}

%var two_display_units color_displays blt_request_start display_devices

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
                        21-bit disk addresses in the MMAP entries, the
                        address spaces' segment maps (SMAPS) and a larger
                        MST, where the other form has 20-byte ASTEs,
                        9-bit hints and 22-bit addresses; OS_$INIT's
                        SERVER_$FLAG in the node check and its MEM_$INIT
                        after IO_$INIT.
    vm_5760_astes       5760 ASTEs and 1280 AOTEs, instead of 504 and 280.
    vm_1536_astes       1536 ASTEs and 640 AOTEs.
    pmap_threads        an ASTE heads the thread of the MST entries that
                        point at its page map (MST_$UNTHREAD_PMAP), which
                        ast_$deactivate_segment ends; MST_$FIND and
                        MST_$WIRE always fault the page in.
    pmmu_page_maps      the page maps' entries are MC68030 page
                        descriptors, the frame in bits 31..10 and the
                        flags in the low word (AST_$PTOV,
                        AST_$REMOVE_PAGE, AST_$ALLOC_CONTIG,
                        MMAP_$ALLOC_CONTIG); FIM_$BUILD_DF stores
                        MMU_$BUS_STATUS as the fault's information word,
                        and OS_$INIT clears the resident bit of the
                        descriptors it mapped.
    pmap_cache_inhibit  the page maps' pages are cache-inhibited, with
                        AST_$CACHE_INHIBIT_PPN and AST_$CACHE_ENABLE_PPN,
                        and so are the I/O pages AST_$ASSOC_IOPPN maps.
    mmap_ppns_10000     the pageable pages are 16#10000..16#1FFFF, and
                        the page entries' list links are 22-bit fields.
    mmap_ppns_400       the pageable pages are 16#400..16#23FF.
    mst_7168_words      the MST holds 7168 words.
    large_address_space the regions' segments are constants: private A
                        30336, global A 256 from 30336, private B 128
                        from 30592, global B 2048 from 30720, of 32768;
                        OS_$INIT clears COLD's RARS entry and frees the
                        page maps of the two unused global ranges.
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
    smap_shared_global  MST_$TOUCH and mst_$va_to_aste leave a global
                        segment's map entry with bit 9 set (the MC68851's
                        shared-globally bit) and its bits 15..10 as they
                        are, where the other form clears bit 9 and sets
                        bits 15..10.
}

%var large_vm vm_5760_astes vm_1536_astes pmap_threads pmmu_page_maps
%var pmap_cache_inhibit
%var mmap_ppns_10000 mmap_ppns_400 large_address_space
%var mst_7168_words vm_regions run_time_layout smap_shared_global

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
    cacr_clear_data     CACHE_$FLUSH_VIRTUAL clears the MC68030 data
                        cache (CACR bit 11), where the other form only
                        returns.
}

%var pft_mmu cpu_status_register cacr_clear_data

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
}

%var fpu_enable_ccr fpu_enable_cpu_control

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
}

%var mem_ccr_board_size mem_board_jumpers

{ The memory parity errors (parity/).

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
}

%var parity_err_regs parity_dma_pages parity_cpu_status parity_dma_page_pairs

{ The floating-point hardware (peb/, xpd/).

    peb_board           the Performance Enhancement Board's driver: its
                        parity test, interrupt routine, register load
                        and unload, WCS writer and reader, and XPD_'s FP
                        routines testing PEB_$INFO (a 68881 first, else
                        the board), where the other form has PEB_ drive
                        the MC68881 alone.
}

%var peb_board

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
}

%var cold_proc_tables

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
}

%var mbus_dev_routines mbus_map_reserved pbu_alloc_mbus winchester_config
%var iic_port_config pbu_config_always pbu_alloc_atbus_windows

{ The Multibus adapter (mbus/).

    mbus_polled_adapter  MBUS_$INIT installs MBUS_$INT for one vector,
                         16#1C, and gives levels 0..7 MBUS_$UNDEF_INT;
                         MBUS_$INT reads the adapter's register once and
                         takes the first level from 7 down whose bit and
                         pending bit are set; MBUS_$HIGH_OK is bit 5 of
                         the probed register.
}

%var mbus_polled_adapter

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
}

%var display_driver lpr_driver

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
}

%var pbu_8_units pbu_wire_special pbu_atbus_units pbu_transfer_control

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
}

%var calendar_own_page calendar_write_unconditional pbu_get_status
%var crash_prom_restart display_lights_stub crash_remap_cold_display

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
  %enable peb_board;
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
  %enable mbus_bus, sysbus_routines, smd_disk, floppy_disk, io_regions;
  %enable sysbus_int_vec;
  %enable second_display_unit;
  %enable winchester_ctlr;
  %enable power_off_check, power_down, disp2_probe, color_board, crash_reboot;
  %enable ring_node_id;
  %enable two_display_units, color_displays, blt_request_start;
  %enable large_vm, vm_regions;
  %enable null_process_spins;
  %enable circular_buffers;
  %enable ring_xmit_light;
  %enable winchester_config;
  %enable display_driver, lpr_driver;
  %enable pbu_8_units;
  %enable calendar_write_unconditional;
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
  %enable peb_board;
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
  %enable vme_bus, mbus_bus, sysbus_routines, smd_disk, pbu_mcb_config;
  %enable io_regions, few_io_regions;
  %enable sysbus_int_vec;
  %enable ct_qic02;
  %enable kbd_tone, kbd_key_ring_512, kbd_commands;
  %enable winchester_ctlr;
  %enable long_iomap;
  %enable ring_controller_dma;
  %enable power_off_check, power_down, disp2_probe, crash_reboot, ring_node_id;
  %enable fim_nmi, shutdown_kbd_mode;
  %enable two_display_units, color_displays, blt_request_start;
  %enable large_vm, vm_5760_astes, pmap_threads, vm_regions;
  %enable display_lights;
  %enable null_process_spins;
  %enable ring_xmit_light;
  %enable winchester_config;
  %enable display_driver;
  %enable pbu_wire_special, pbu_transfer_control;
%endif

{ sau7: the DN3500, DN3550, DN4000 and DN4500. }
%if sau7 %then
  %enable color4_driver, color5_driver, color7_driver, ct_driver, dma_driver;
  %enable atbus_dma;
  %enable ethernet_driver, mono_driver, pbu_driver, scsi_driver, tape_boot;
  %enable floppy_disk, floppy_atbus, io_regions;
  %enable ethernet_int_unmasked;
  %enable io_descriptors;
  %enable named_dctes;
  %enable atbus_routines, atbus_pics;
  %enable ring_8025_driver, ring_8025_dma_channel;
  %enable ct_qic02, ct_scsi, ct_atbus_qic02;
  %enable kbd_tone, kbd_key_ring_512, kbd_commands;
  %enable sio2681_pbu_int;
  %enable winchester_ctlr, win_atbus_ctlr;
  %enable ring_owner_test_reversed, ring8_controller, nodeid_prom_probe;
  %enable crash_reboot, smd_display_memory, calendar_service_mode, fim_nmi;
  %enable vector_alignment_check, shutdown_kbd_mode;
  %enable boot_flags_diskless, pbu_wire_at_boot, boot_flags_server;
  %enable display_devices;
  %enable calendar_mapped_rtc;
  %enable crash_remap_cold_display;
  %enable large_vm, vm_5760_astes, pmap_threads, pmmu_page_maps;
  %enable pmap_cache_inhibit, large_address_space, vm_regions;
  %enable cpu_status_register;
  %enable fpu_enable_cpu_control;
  %enable timer_int_pic;
  %enable parity_dma_page_pairs;
  %enable trap_page_high;
  %enable null_process_spins;
  %enable cold_proc_tables;
  %enable netbuf_cache_inhibit;
  %enable ring_xmit_light;
  %enable winchester_config;
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
  %enable sio2681_pbu_int;
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
  %enable mmap_ppns_400, mst_7168_words, vm_regions, run_time_layout;
  %enable smap_shared_global;
  %enable cpu_status_register;
  %enable fpu_enable_cpu_control;
  %enable timer_int_pic;
  %enable mem_board_jumpers;
  %enable parity_cpu_status, parity_dma_page_pairs;
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
  %enable kbd_tone, kbd_key_ring_512, sio16550_lines, kbd_commands;
  %enable ring_owner_test_reversed, ring8_controller, nodeid_prom;
  %enable crash_reboot, smd_display_memory, calendar_service_mode, fim_nmi;
  %enable vector_alignment_check, prom_config_record, shutdown_kbd_mode;
  %enable display_devices;
  %enable calendar_indexed_rtc;
  %enable large_vm, vm_5760_astes, pmap_threads, pmmu_page_maps;
  %enable pmap_cache_inhibit, mmap_ppns_10000, large_address_space;
  %enable vm_regions;
  %enable cacr_clear_data;
  %enable fpu_enable_ccr;
  %enable mem_ccr_board_size;
  %enable parity_err_regs, parity_dma_pages;
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
