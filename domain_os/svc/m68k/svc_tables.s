|
| svc/m68k/svc_tables.s - the SVC dispatch tables at the tail of SVC_CATCHER
| (SAU2, SAU3, SAU5, SAU9)
|
| The SAU2 and SAU5 images have the same tables except 67 entries that
| name a driver's routine on the SAU5 and SVC_$UNIMPLEMENTED on the SAU2,
| the SAU2 lacking the driver.  Those entries are `svc_entry PART, NAME'
| (below): NAME with base/config.ins.pas's PART, else SVC_$UNIMPLEMENTED.
| The parts are the drivers' (each module's code segment real on exactly
| those SAUs' maps): COLOR_ color_board (6 entries), COLOR2_ and GPU_
| gpu_driver (11), PBU_ and PBU2_ pbu_driver (30), MT_ mt_driver (13),
| CT_ ct_driver (7).  The SAU9 fills 14 more: SCSI_ scsi_driver (11),
| and SMD_$SHARE_DEVICE, SMD_$SET_COLOR_TABLE and SMD_$DEVICE_INFO,
| display_devices (3: the device-descriptor driver's calls); and it lacks
| 17 the SAU2 has: PEB_$ASSOC and PEB_$DISSOC (peb_board) and 15 calls
| of the display controller's driver (!display_devices: 11 entries
| SVC_$UNIMPLEMENTED, 4 SVC_$TRAP8_INVALID, svc_entry_invalid).  The SAU5's
| and the SAU9's SVC_CATCHER (`D 3C48C308 SVC_CATCHER size = E40') are
| the SAU2's segment laid out elsewhere, the tables at 0xE825A2 and
| 0x3C48C5A2.  The SAU5's SVC_CATCHER is the SAU2's segment
| 0x72C4 higher (`D E82308 SVC_CATCHER size = E40'): its tables start at
| 0xE825A2, every distance below the same.  The SAU3's (`D E7C708
| SVC_CATCHER size = E40') is the same segment, the tables at 0xE7C9A2;
| it has no display (`display_driver'): the 70 calls of the display
| driver, the touch pad and DTTY_$RELOAD_FONT are SVC_$UNIMPLEMENTED
| (svc_display, svc_display_ctl, svc_display_ctl_invalid below; the four
| SMD_ stubs the SAU3 keeps, SMD_$N_DEVICES, SMD_$INQ_DISP_TYPE,
| SMD_$INQ_DISP_INFO and SMD_$INQ_DISP_UID, stay), and it fills 13 the
| SAU2 does not: LPR_ lpr_driver (4), IIC_ iic_driver (8) and
| PBU_$GET_STATUS pbu_get_status (pbu/sau3/pbu_asm.s).  The addresses
| below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): every entry is a
| relocation, resolved against the image's word; the argument counts and
| the pad are compared as bytes.
|
| The nine tables are packed back to back after SVC_$TRAP8's fault tail, in
| the SVC_CATCHER segment of .DATA (SAU2 map: "D E7B044 SVC_CATCHER size =
| E40", 0xE7B044..0xE7BE84; PROC2 starts at 0xE7BE84).  The map names none
| of them; each address is the target of the `lea (TABLE:w,%pc)' in the
| matching svc/m68k/trapN.s, and every table's size is the distance to the
| next one:
|
|   0xE7B2DE  SVC_$TRAP0_TABLE      32 entries * 4 = 0x080  (lea at 0xE7B04C)
|   0xE7B35E  SVC_$TRAP1_TABLE      66 entries * 4 = 0x108  (lea at 0xE7B064)
|   0xE7B466  SVC_$TRAP2_TABLE     133 entries * 4 = 0x214  (lea at 0xE7B09C)
|   0xE7B67A  SVC_$TRAP3_TABLE     155 entries * 4 = 0x26C  (lea at 0xE7B0E0)
|   0xE7B8E6  SVC_$TRAP4_TABLE     131 entries * 4 = 0x20C  (lea at 0xE7B128)
|   0xE7BAF2  SVC_$TRAP5_TABLE      99 entries * 4 = 0x18C  (lea at 0xE7B184)
|   0xE7BC7E  SVC_$TRAP7_TABLE      59 entries * 4 = 0x0EC  (lea at 0xE7B1E0)
|   0xE7BD6A  SVC_$TRAP8_TABLE      56 entries * 4 = 0x0E0  (lea at 0xE7B27C,
|                                                 0xE7B28E and 0xE7B2CC)
|   0xE7BE4A  SVC_$TRAP8_ARGCOUNT   56 entries * 1 = 0x038  (lea at 0xE7B240)
|   0xE7BE82  2 bytes to the segment's end
|
| The map names none of the tables.  tools/gen_layout_ld.py ANCHORS keys
| this section at 0xE7B2DE, and tools/asm_compare.py LOCAL_SYMBOLS gives
| each table's image address.
|
| Entries:
|   - An invalid call number's entry is SVC_$TRAP8_INVALID (0xE7B28E), in
|     every table: the image's word (157 entries).  That stub tears down
|     TRAP #8's LINK frame when A1 still holds SVC_$TRAP8_TABLE, then falls
|     into SVC_$INVALID_SYSCALL (0xE7B298).  SVC_$UNIMPLEMENTED
|     (0xE7B2CC, 100 entries) is the fault tail's label.  Both labels
|     are in svc/m68k/trap8.s.
|   - 0xE825E4 is the map's `D E825E4 VFMT_$FORMATN size = 10' trampoline,
|     which has six names at that one address (VFMT_$FORMAT10, _ENCODE10,
|     _FORMAT5, _ENCODE5, _ENCODE2, _FORMAT2).  Which name the original
|     table used for each entry is not known; these entries use the map's
|     first, VFMT_$FORMAT10 (the word is the same whichever is chosen).
|     0xE825F4 is VFMT_$WRITEN's trampoline, named VFMT_$WRITE10 here.
|   - SVC_$TRAP8_ARGCOUNT holds each TRAP #8 call's argument count minus
|     one; the dispatcher reads it through the `lea' at 0xE7B240.
|
| TRAP #6 is not an SVC trap (its vector is FIM_$UNDEF_TRAP), so there is
| no TRAP6 table.
|
        .include "base/config.inc"

| An entry the image fills only on the SAUs with PART (a driver's call).
        .macro  svc_entry part, name
        .if \part
        .long   \name
        .else
        .long   SVC_$UNIMPLEMENTED
        .endif
        .endm

| The same, an invalid call's entry without PART.
        .macro  svc_entry_invalid part, name
        .if \part
        .long   \name
        .else
        .long   SVC_$TRAP8_INVALID
        .endif
        .endm

| A call of the display driver (or the touch pad's): SVC_$UNIMPLEMENTED
| on the SAUs without `display_driver'.
        .macro  svc_display name
        .if display_driver
        .long   \name
        .else
        .long   SVC_$UNIMPLEMENTED
        .endif
        .endm

| A call of the display controller's driver: also SVC_$UNIMPLEMENTED on
| the SAUs whose driver drives its displays through device descriptors
| (`display_devices').
        .macro  svc_display_ctl name
        .if display_driver && !display_devices
        .long   \name
        .else
        .long   SVC_$UNIMPLEMENTED
        .endif
        .endm

| The same, an invalid call's entry with `display_devices'.
        .macro  svc_display_ctl_invalid name
        .if !display_driver
        .long   SVC_$UNIMPLEMENTED
        .elseif display_devices
        .long   SVC_$TRAP8_INVALID
        .else
        .long   \name
        .endif
        .endm

        .section ".text.svc_tables","ax",@progbits

        .globl  SVC_$TRAP0_TABLE
SVC_$TRAP0_TABLE:            | 0xE7B2DE, 32 entries
        .long   PROC2_$DELETE               | 0x00
        .long   FIM_$GET_FIM_ADDR           | 0x01
        .long   SVC_$TRAP8_INVALID          | 0x02
        svc_display DTTY_$RELOAD_FONT       | 0x03
        .long   FILE_$UNLOCK_ALL            | 0x04
        svc_entry peb_board, PEB_$ASSOC     | 0x05 (SVC_$UNIMPLEMENTED without the part)
        svc_entry peb_board, PEB_$DISSOC    | 0x06 (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$MY_PID               | 0x07
        svc_display SMD_$OP_WAIT_U          | 0x08
        svc_display TPAD_$RE_RANGE          | 0x09
        .long   SVC_$TRAP8_INVALID          | 0x0A
        svc_entry color_board, COLOR_$DISSOC        | 0x0B (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x0C
        .long   ACL_$UP                     | 0x0D
        .long   ACL_$DOWN                   | 0x0E
        svc_entry color_board, COLOR_$INT_INIT      | 0x0F (SVC_$UNIMPLEMENTED without the part)
        svc_display TPAD_$INQ_DTYPE         | 0x10
        .long   SVC_$TRAP8_INVALID          | 0x11
        .long   CACHE_$CLEAR                | 0x12
        .long   RIP_$ANNOUNCE_NS            | 0x13
        svc_entry gpu_driver, COLOR2_$DISSOC        | 0x14 (SVC_$UNIMPLEMENTED without the part)
        svc_entry gpu_driver, GPU_$TERM     | 0x15 (SVC_$UNIMPLEMENTED without the part)
        svc_entry gpu_driver, GPU_$DIAG_RELEASE     | 0x16 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x17
        .long   PROC2_$DELIVER_PENDING      | 0x18
        .long   PROC2_$COMPLETE_FORK        | 0x19
        .long   PACCT_$STOP                 | 0x1A
        .long   PACCT_$ON                   | 0x1B
        .long   ACL_$GET_LOCAL_LOCKSMITH    | 0x1C
        .long   ACL_$IS_SUSER               | 0x1D
        .long   SVC_$TRAP8_INVALID          | 0x1E
        .long   SMD_$N_DEVICES              | 0x1F

        .globl  SVC_$TRAP1_TABLE
SVC_$TRAP1_TABLE:            | 0xE7B35E, 66 entries
        .long   SVC_$TRAP8_INVALID          | 0x00
        .long   SVC_$TRAP8_INVALID          | 0x01
        .long   FIM_$INSTALL                | 0x02
        .long   NETWORK_$READ_SERVICE       | 0x03
        .long   PROC1_$GET_CPUT             | 0x04
        .long   SET_LITES_LOC               | 0x05
        .long   TIME_$CLOCK                 | 0x06
        .long   ASKNODE_$READ_FAILURE_REC   | 0x07
        .long   CAL_$APPLY_LOCAL_OFFSET     | 0x08
        .long   CAL_$GET_INFO               | 0x09
        .long   CAL_$GET_LOCAL_TIME         | 0x0A
        .long   CAL_$REMOVE_LOCAL_OFFSET    | 0x0B
        .long   CAL_$SET_DRIFT              | 0x0C
        .long   DISK_$GET_ERROR_INFO        | 0x0D
        svc_entry lpr_driver, LPR_$ACQUIRE  | 0x0E (SVC_$UNIMPLEMENTED without the part)
        .long   MSG_$CLOSE                  | 0x0F
        .long   PROC2_$WHO_AM_I             | 0x10
        svc_display SMD_$CLEAR_KBD_CURSOR   | 0x11
        .long   SVC_$TRAP8_INVALID          | 0x12
        .long   SVC_$TRAP8_INVALID          | 0x13
        svc_display SMD_$SEND_RESPONSE      | 0x14
        svc_display SMD_$STOP_TP_CURSOR     | 0x15
        .long   SVC_$TRAP8_INVALID          | 0x16
        .long   SVC_$TRAP8_INVALID          | 0x17
        svc_display SMD_$UNMAP_DISPLAY_U    | 0x18
        .long   UID_$GEN                    | 0x19
        .long   TONE_$TIME                  | 0x1A
        .long   SMD_$INQ_DISP_TYPE          | 0x1B
        svc_display_ctl SMD_$INVERT_S       | 0x1C
        svc_display_ctl SMD_$INQ_MM_BLT     | 0x1D
        svc_entry color_board, COLOR_$INQ_DONE_WAIT | 0x1E (SVC_$UNIMPLEMENTED without the part)
        svc_display TPAD_$SET_CURSOR        | 0x1F
        svc_display_ctl SMD_$EOF_WAIT       | 0x20
        .long   SVC_$UNIMPLEMENTED          | 0x21
        .long   NAME_$GET_WDIR_UID          | 0x22
        .long   NAME_$GET_NDIR_UID          | 0x23
        .long   NAME_$GET_ROOT_UID          | 0x24
        .long   NAME_$GET_NODE_UID          | 0x25
        .long   NAME_$GET_NODE_DATA_UID     | 0x26
        .long   NAME_$GET_CANNED_ROOT_UID   | 0x27
        .long   MSG_$GET_MY_NET             | 0x28
        .long   MSG_$GET_MY_NODE            | 0x29
        .long   SVC_$TRAP8_INVALID          | 0x2A
        .long   SVC_$TRAP8_INVALID          | 0x2B
        svc_entry iic_driver, IIC_$EXISTS   | 0x2C (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x2D
        svc_entry gpu_driver, COLOR2_$ASSOC | 0x2E (SVC_$UNIMPLEMENTED without the part)
        svc_entry gpu_driver, COLOR2_$BUSY_WAIT     | 0x2F (SVC_$UNIMPLEMENTED without the part)
        .long   GPU_$INIT                   | 0x30
        svc_entry gpu_driver, GPU_$FLUSH    | 0x31 (SVC_$UNIMPLEMENTED without the part)
        svc_display SMD_$INIT_STATE         | 0x32
        svc_display SMD_$CLR_TRK_RECT       | 0x33
        .long   PROC2_$GET_SIG_MASK         | 0x34
        svc_entry !fp_state_in_cpu, FIM_$FRESTORE | 0x35 (SVC_$UNIMPLEMENTED where the FP registers are the CPU's)
        .long   TIME_$GET_TIME_OF_DAY       | 0x36
        .long   PROC1_$GET_LOADAV           | 0x37
        .long   PROC2_$GET_BOOT_FLAGS       | 0x38
        .long   SVC_$TRAP8_INVALID          | 0x39
        .long   PROC2_$SET_TTY              | 0x3A
        .long   OS_$SHUTDOWN                | 0x3B
        .long   PBU_$FAULTED_UNITS          | 0x3C
        .long   PROC2_$GET_CPU_USAGE        | 0x3D
        .long   SVC_$TRAP8_INVALID          | 0x3E
        .long   SVC_$TRAP8_INVALID          | 0x3F
        .long   SVC_$TRAP8_INVALID          | 0x40
        .long   TIME_$GET_ADJUST            | 0x41

        .globl  SVC_$TRAP2_TABLE
SVC_$TRAP2_TABLE:            | 0xE7B466, 133 entries
        .long   SVC_$TRAP8_INVALID          | 0x00
        .long   SVC_$TRAP8_INVALID          | 0x01
        .long   FILE_$DELETE                | 0x02
        .long   EC2_$WAKEUP                 | 0x03
        .long   SVC_$TRAP8_INVALID          | 0x04
        .long   ACL_$GET_SID                | 0x05
        .long   FILE_$MK_PERMANENT          | 0x06
        .long   FILE_$UNLOCK_VOL            | 0x07
        .long   CAL_$READ_TIMEZONE          | 0x08
        .long   CAL_$SEC_TO_CLOCK           | 0x09
        .long   CAL_$WRITE_TIMEZONE         | 0x0A
        .long   DISK_$UNASSIGN              | 0x0B
        .long   FILE_$FORCE_UNLOCK          | 0x0C
        .long   FILE_$FW_FILE               | 0x0D
        .long   FILE_$MK_IMMUTABLE          | 0x0E
        .long   FILE_$PURIFY                | 0x0F
        .long   GET_BUILD_TIME              | 0x10
        svc_entry lpr_driver, LPR_$RELEASE  | 0x11 (SVC_$UNIMPLEMENTED without the part)
        svc_entry lpr_driver, LPR_$STATE    | 0x12 (SVC_$UNIMPLEMENTED without the part)
        .long   MSG_$ALLOCATE               | 0x13
        .long   MSG_$OPEN                   | 0x14
        .long   MSG_$WAIT                   | 0x15  2 args: (socket, timeout); the * status_$t is local to 0x00E59BA4 * ("link.w A6,-0x8" / "pea (-0x4,A6)") * and the boolean comes back in D0.b
        .long   SVC_$TRAP8_INVALID          | 0x16
        .long   SVC_$TRAP8_INVALID          | 0x17
        svc_entry pbu_driver, PBU_$DEVICE_INTERRUPTING| 0x18 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$DISABLE_DEVICE   | 0x19 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$ENABLE_DEVICE    | 0x1A (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$FREE_MAP | 0x1B (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$QUIT                 | 0x1C
        .long   PROC2_$RESUME               | 0x1D
        .long   PROC2_$SUSPEND              | 0x1E
        svc_display_ctl SMD_$BLT_U          | 0x1F
        svc_display_ctl_invalid SMD_$CLEAR_WINDOW| 0x20
        .long   SVC_$TRAP8_INVALID          | 0x21
        svc_display_ctl SMD_$DRAW_BOX       | 0x22
        .long   SVC_$TRAP8_INVALID          | 0x23
        svc_display_ctl SMD_$LOAD_FONT      | 0x24
        .long   SVC_$TRAP8_INVALID          | 0x25
        svc_display SMD_$MAP_DISPLAY_U      | 0x26
        svc_display SMD_$MOVE_KBD_CURSOR    | 0x27
        .long   SVC_$TRAP8_INVALID          | 0x28
        svc_display SMD_$RETURN_DISPLAY     | 0x29
        .long   SVC_$TRAP8_INVALID          | 0x2A
        .long   SVC_$TRAP8_INVALID          | 0x2B
        svc_display_ctl SMD_$UNLOAD_FONT    | 0x2C
        .long   SVC_$TRAP8_INVALID          | 0x2D
        .long   PEB_$GET_INFO               | 0x2E
        .long   SVC_$TRAP8_INVALID          | 0x2F
        .long   EC2_$GET_VAL                | 0x30
        .long   AST_$ADD_ASTES              | 0x31
        svc_entry pbu_driver, PBU_$DISSOC   | 0x32 (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$MAKE_ORPHAN          | 0x33
        .long   FILE_$DELETE_FORCE          | 0x34
        .long   FILE_$DELETE_WHEN_UNLOCKED  | 0x35
        .long   FILE_$MK_TEMPORARY          | 0x36
        .long   SVC_$TRAP8_INVALID          | 0x37
        .long   SVC_$TRAP8_INVALID          | 0x38
        .long   SVC_$TRAP8_INVALID          | 0x39
        .long   SVC_$TRAP8_INVALID          | 0x3A
        svc_display SMD_$INQ_KBD_CURSOR     | 0x3B
        .long   ACL_$ENTER_SUBS             | 0x3C
        .long   SVC_$TRAP8_INVALID          | 0x3D
        .long   SVC_$UNIMPLEMENTED          | 0x3E
        .long   SVC_$UNIMPLEMENTED          | 0x3F
        .long   SVC_$UNIMPLEMENTED          | 0x40
        svc_entry color_board, COLOR_$ASSOC | 0x41 (SVC_$UNIMPLEMENTED without the part)
        .long   FILE_$DELETE_FORCE_WHEN_UNLOCKED| 0x42
        svc_display_ctl SMD_$SET_CLIP_WINDOW| 0x43
        svc_entry ct_driver, CT_$ACQUIRE    | 0x44 (SVC_$UNIMPLEMENTED without the part)
        .long   HINT_$ADD                   | 0x45
        .long   DIR_$FIX_DIR                | 0x46
        .long   NAME_$SET_WDIRUS            | 0x47
        .long   NAME_$SET_NDIRUS            | 0x48
        .long   SVC_$UNIMPLEMENTED          | 0x49
        .long   SVC_$TRAP8_INVALID          | 0x4A
        .long   MSG_$CLOSEI                 | 0x4B
        .long   NETWORK_$ADD_PAGE_SERVERS   | 0x4C
        .long   NETWORK_$ADD_REQUEST_SERVERS| 0x4D
        .long   ACL_$ADD_PROJ               | 0x4E
        .long   ACL_$DELETE_PROJ            | 0x4F
        .long   XPD_$GET_FP                 | 0x50
        .long   XPD_$PUT_FP                 | 0x51
        svc_display SMD_$SET_TP_REPORTING   | 0x52
        svc_display SMD_$DISABLE_TRACKING   | 0x53
        svc_entry iic_driver, IIC_$ACQUIRE  | 0x54 (SVC_$UNIMPLEMENTED without the part)
        svc_entry iic_driver, IIC_$RELEASE  | 0x55 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x56
        .long   SVC_$TRAP8_INVALID          | 0x57
        .long   HINT_$ADDI                  | 0x58
        svc_entry iic_driver, IIC_$RECEIVE_CHECK| 0x59 (SVC_$UNIMPLEMENTED without the part)
        svc_entry gpu_driver, COLOR2_$GET_EC        | 0x5A (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$ALLOCATE_EC      | 0x5B (SVC_$UNIMPLEMENTED without the part)
        svc_display SMD_$SET_DISP_UNIT      | 0x5C
        svc_display SMD_$VIDEO_CTL          | 0x5D
        svc_display SMD_$SET_CURSOR_POS     | 0x5E
        .long   TERM_$SEND_KBD_STRING       | 0x5F
        .long   AUDIT_$CONTROL              | 0x60
        .long   PROC2_$SIGBLOCK             | 0x61
        .long   PROC2_$SIGSETMASK           | 0x62
        .long   PROC2_$SIGPAUSE             | 0x63
        .long   SVC_$TRAP8_INVALID          | 0x64
        .long   AS_$GET_ADDR                | 0x65
        .long   PROC2_$GET_ASID             | 0x66
        .long   TTY_$K_FLUSH_INPUT          | 0x67
        .long   TTY_$K_FLUSH_OUTPUT         | 0x68
        .long   TTY_$K_DRAIN_OUTPUT         | 0x69
        .long   PROC2_$DEBUG                | 0x6A
        .long   PROC2_$UNDEBUG              | 0x6B
        .long   ACL_$DEF_ACLDATA            | 0x6C
        .long   PROC2_$OVERRIDE_DEBUG       | 0x6D
        .long   TIME_$SET_TIME_OF_DAY       | 0x6E
        .long   CAL_$DECODE_TIME            | 0x6F
        .long   ACL_$INHERIT_SUBSYS         | 0x70
        .long   ACL_$SET_LOCAL_LOCKSMITH    | 0x71
        .long   SVC_$TRAP8_INVALID          | 0x72
        svc_display SMD_$DISSOC             | 0x73
        svc_display SMD_$BUSY_WAIT          | 0x74
        .long   TTY_$K_RESET                | 0x75
        .long   SVC_$TRAP8_INVALID          | 0x76
        .long   SVC_$TRAP8_INVALID          | 0x77
        .long   SVC_$TRAP8_INVALID          | 0x78
        svc_entry scsi_driver, SCSI_$ABORT_OPERATION| 0x79 (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$RELEASE| 0x7A (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$RESET_DEVICE| 0x7B (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x7C
        svc_display TPAD_$RE_RANGE_UNIT     | 0x7D
        .long   DISK_$FORMAT_WHOLE          | 0x7E
        .long   MAC_$CLOSE                  | 0x7F
        .long   MAC_$NET_TO_PORT_NUM        | 0x80
        .long   XNS_IDP_$OPEN               | 0x81
        .long   XNS_IDP_$CLOSE              | 0x82
        .long   XNS_IDP_$GET_STATS          | 0x83
        .long   SVC_$TRAP8_INVALID          | 0x84

        .globl  SVC_$TRAP3_TABLE
SVC_$TRAP3_TABLE:            | 0xE7B67A, 155 entries
        svc_entry pbu_driver, PBU2_$DMA_STOP        | 0x00 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x01
        .long   FILE_$CREATE                | 0x02
        .long   FILE_$UNLOCK                | 0x03
        .long   FILE_$TRUNCATE              | 0x04
        .long   MST_$UNMAPS                 | 0x05
        .long   VFMT_$WRITE10               | 0x06
        .long   FILE_$ATTRIBUTES            | 0x07
        .long   FILE_$SET_LEN               | 0x08
        .long   FILE_$SET_TYPE              | 0x09
        .long   SVC_$TRAP8_INVALID          | 0x0A
        .long   SVC_$TRAP8_INVALID          | 0x0B
        .long   SVC_$TRAP8_INVALID          | 0x0C
        .long   SVC_$TRAP8_INVALID          | 0x0D
        .long   NETWORK_$SET_SERVICE        | 0x0E
        .long   ASKNODE_$WHO                | 0x0F
        .long   FILE_$ACT_ATTRIBUTES        | 0x10
        .long   FILE_$LOCATE                | 0x11
        .long   FILE_$NEIGHBORS             | 0x12
        .long   FILE_$READ_LOCK_ENTRYU      | 0x13
        .long   FILE_$SET_ACL               | 0x14
        .long   FILE_$SET_DIRPTR            | 0x15
        .long   FILE_$SET_TROUBLE           | 0x16
        .long   SVC_$TRAP8_INVALID          | 0x17
        svc_entry lpr_driver, LPR_$WRITE    | 0x18 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$CONTROL    | 0x19 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$RELEASE    | 0x1A (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x1B
        svc_entry pbu_driver, PBU_$DMA_STOP | 0x1C (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$SETDOWN  | 0x1D (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$SETUP    | 0x1E (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$LIST                 | 0x1F
        .long   FIM_$SINGLE_STEP            | 0x20
        svc_display SMD_$ASSOC              | 0x21
        svc_display SMD_$BORROW_DISPLAY     | 0x22
        svc_display_ctl_invalid SMD_$CLEAR_CURSOR| 0x23
        svc_display_ctl SMD_$DISPLAY_CURSOR | 0x24
        svc_display SMD_$SET_TP_CURSOR      | 0x25
        .long   TIME_$WAIT                  | 0x26
        .long   RINGLOG_$CNTL               | 0x27
        svc_display SMD_$ALLOC_HDM          | 0x28
        svc_display SMD_$FREE_HDM           | 0x29
        .long   SVC_$TRAP8_INVALID          | 0x2A
        .long   OS_$GET_EC                  | 0x2B
        .long   TIME_$GET_EC                | 0x2C
        svc_entry color_board, COLOR_$UNMAP | 0x2D (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$UPID_TO_UID          | 0x2E
        .long   MSG_$GET_EC                 | 0x2F
        .long   DISK_$AS_OPTIONS            | 0x30
        svc_display SMD_$GET_EC             | 0x31
        .long   NAME_$SET_ACL               | 0x32
        .long   FILE_$SET_REFCNT            | 0x33
        .long   SVC_$TRAP8_INVALID          | 0x34
        .long   PROC1_$GET_INFO             | 0x35
        .long   SVC_$TRAP8_INVALID          | 0x36
        .long   SVC_$TRAP8_INVALID          | 0x37
        .long   SVC_$TRAP8_INVALID          | 0x38
        .long   SVC_$TRAP8_INVALID          | 0x39
        .long   SVC_$TRAP8_INVALID          | 0x3A
        svc_entry pbu_get_status, PBU_$GET_STATUS| 0x3B (SVC_$UNIMPLEMENTED without the part)
        .long   AS_$GET_INFO                | 0x3C
        .long   FILE_$SET_DTM               | 0x3D
        .long   FILE_$SET_DTU               | 0x3E
        .long   SVC_$TRAP8_INVALID          | 0x3F
        .long   LOG_$READ                   | 0x40
        .long   PROC2_$SET_PGROUP           | 0x41
        svc_display SMD_$SET_BLANK_TIMEOUT  | 0x42
        svc_display SMD_$INQ_BLANK_TIMEOUT  | 0x43
        .long   FILE_$REMOVE_WHEN_UNLOCKED  | 0x44
        svc_entry ct_driver, CT_$RELEASE    | 0x45 (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$UPGID_TO_UID         | 0x46
        .long   TIME_$GET_ITIMER            | 0x47
        .long   DIR_$SET_DAD                | 0x48
        .long   XPD_$GET_EC                 | 0x49
        .long   XPD_$SET_DEBUGGER           | 0x4A
        .long   XPD_$POST_EVENT             | 0x4B
        .long   XPD_$SET_ENABLE             | 0x4C
        .long   SVC_$TRAP8_INVALID          | 0x4D
        .long   XPD_$CONTINUE_PROC          | 0x4E
        .long   RIP_$TABLE                  | 0x4F
        .long   FILE_$LOCATEI               | 0x50
        .long   MSG_$OPENI                  | 0x51
        .long   MSG_$ALLOCATEI              | 0x52
        .long   MSG_$WAITI                  | 0x53
        .long   ACL_$SET_PROJ_LIST          | 0x54
        .long   ACL_$GET_RE_SIDS            | 0x55
        .long   SVC_$TRAP8_INVALID          | 0x56
        .long   MSG_$SET_HPIPC              | 0x57
        .long   DIR_$VALIDATE_ROOT_ENTRY    | 0x58
        svc_display SMD_$ENABLE_TRACKING    | 0x59
        .long   FILE_$READ_LOCK_ENTRYUI     | 0x5A
        svc_entry iic_driver, IIC_$STATISTICS| 0x5B (SVC_$UNIMPLEMENTED without the part)
        .long   ROUTE_$SERVICE              | 0x5C
        .long   SVC_$TRAP8_INVALID          | 0x5D
        svc_entry iic_driver, IIC_$SELF_TEST| 0x5E (SVC_$UNIMPLEMENTED without the part)
        svc_entry gpu_driver, GPU_$SET_PAGE_LIMITS  | 0x5F (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$ADVANCE_EC       | 0x60 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$RELEASE_EC       | 0x61 (SVC_$UNIMPLEMENTED without the part)
        .long   XPD_$GET_EVENT_AND_DATA     | 0x62
        svc_display SMD_$GET_IDM_EVENT      | 0x63
        .long   MSG_$TEST_FOR_MESSAGE       | 0x64
        svc_display SMD_$ADD_TRK_RECT       | 0x65
        svc_display SMD_$DEL_TRK_RECT       | 0x66
        svc_display SMD_$SET_KBD_TYPE       | 0x67
        svc_entry win6_ct6_board, WIN6_$GET_ERROR_INFO | 0x68 (SVC_$UNIMPLEMENTED without the part)
        .long   FILE_$SET_AUDITED           | 0x69
        .long   PROC2_$ACKNOWLEDGE          | 0x6A
        .long   PROC2_$GET_MY_UPIDS         | 0x6B
        .long   TTY_$K_INQ_INPUT_FLAGS      | 0x6C
        .long   TTY_$K_INQ_OUTPUT_FLAGS     | 0x6D
        .long   TTY_$K_INQ_ECHO_FLAGS       | 0x6E
        .long   TTY_$K_SET_INPUT_BREAK_MODE | 0x6F
        .long   TTY_$K_INQ_INPUT_BREAK_MODE | 0x70
        .long   TTY_$K_SET_PGROUP           | 0x71
        .long   TTY_$K_INQ_PGROUP           | 0x72
        .long   TTY_$K_SIMULATE_TERMINAL_INPUT| 0x73
        .long   TTY_$K_INQ_FUNC_ENABLED     | 0x74
        .long   SIO_$K_TIMED_BREAK          | 0x75
        .long   FILE_$SET_DEVNO             | 0x76
        .long   XPD_$SET_PTRACE_OPTS        | 0x77
        .long   XPD_$INQ_PTRACE_OPTS        | 0x78
        .long   FILE_$SET_MAND_LOCK         | 0x79
        .long   TIME_$SET_CPU_LIMIT         | 0x7A
        .long   CAL_$WEEKDAY                | 0x7B
        .long   SIO_$K_SIGNAL_WAIT          | 0x7C
        .long   TERM_$SET_DISCIPLINE        | 0x7D
        .long   PROC2_$SET_SERVER           | 0x7E
        .long   PACCT_$START                | 0x7F
        .long   FILE_$SET_DTU_F             | 0x80
        .long   PROC2_$PGUID_TO_UPGID       | 0x81
        .long   TERM_$INQ_DISCIPLINE        | 0x82
        svc_entry pbu_driver, PBU_$DMA_STATUS       | 0x83 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x84
        .long   MST_$UNMAPS_AND_FREE_AREA   | 0x85
        svc_display SMD_$ASSOC_CSRS         | 0x86
        .long   SMD_$INQ_DISP_INFO          | 0x87
        .long   SMD_$INQ_DISP_UID           | 0x88
        svc_display SMD_$DISPLAY_LOGO       | 0x89
        .long   TERM_$SET_REAL_LINE_DISCIPLINE| 0x8A
        .long   TIME_$ADJUST_TIME_OF_DAY    | 0x8B
        .long   PROC2_$UID_TO_UPID          | 0x8C
        .long   PROC2_$SET_SESSION_ID       | 0x8D
        svc_display SMD_$GET_UNIT_EVENT     | 0x8E
        svc_display TPAD_$SET_UNIT_CURSOR   | 0x8F
        svc_display TPAD_$SET_PUNCH_IMPACT  | 0x90
        svc_display TPAD_$INQ_PUNCH_IMPACT  | 0x91
        .long   TTY_$K_INQ_SESSION_ID       | 0x92
        .long   TTY_$K_SET_SESSION_ID       | 0x93
        .long   MAC_$OPEN                   | 0x94
        .long   MAC_$RECEIVE                | 0x95
        .long   XNS_IDP_$RECEIVE            | 0x96
        .long   XNS_IDP_$GET_PORT_INFO      | 0x97
        svc_entry display_devices, SMD_$SHARE_DEVICE| 0x98 (SVC_$UNIMPLEMENTED without the part)
        svc_display SMD_$SET_UNIT_CURSOR_POS| 0x99
        svc_display SMD_$CLR_AND_LOAD_TRK_RECT| 0x9A

        .globl  SVC_$TRAP4_TABLE
SVC_$TRAP4_TABLE:            | 0xE7B8E6, 131 entries
        .long   SVC_$TRAP8_INVALID          | 0x00
        .long   MST_$SET_GUARD              | 0x01
        .long   MST_$UNMAP_GLOBAL           | 0x02
        .long   MST_$GET_UID                | 0x03
        .long   EC2_$WAIT                   | 0x04
        .long   FILE_$READ_LOCK_ENTRY       | 0x05
        .long   MST_$UNMAP                  | 0x06
        .long   MST_$GROW_AREA              | 0x07
        .long   SVC_$TRAP8_INVALID          | 0x08
        .long   SVC_$TRAP8_INVALID          | 0x09
        .long   SVC_$TRAP8_INVALID          | 0x0A
        .long   SVC_$TRAP8_INVALID          | 0x0B
        .long   TERM_$CONTROL               | 0x0C
        .long   TERM_$READ                  | 0x0D
        .long   TERM_$WRITE                 | 0x0E
        .long   DISK_$FORMAT                | 0x0F
        .long   DISK_$LV_ASSIGN             | 0x10
        .long   FILE_$FW_PARTIAL            | 0x11
        svc_entry mt_driver, MT_$ACQUIRE    | 0x12 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$ERASE      | 0x13 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$READ       | 0x14 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$SET_MODE   | 0x15 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$SPACE      | 0x16 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x17
        svc_entry mt_driver, MT_$WRITE      | 0x18 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x19
        .long   SVC_$TRAP8_INVALID          | 0x1A
        .long   SVC_$TRAP8_INVALID          | 0x1B
        .long   SVC_$TRAP8_INVALID          | 0x1C
        .long   SVC_$TRAP8_INVALID          | 0x1D
        .long   SVC_$TRAP8_INVALID          | 0x1E
        .long   SVC_$TRAP8_INVALID          | 0x1F
        .long   SVC_$TRAP8_INVALID          | 0x20
        .long   SVC_$TRAP8_INVALID          | 0x21
        .long   SVC_$TRAP8_INVALID          | 0x22
        svc_entry pbu_driver, PBU_$WAIT     | 0x23 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$GET_PTR  | 0x24 (SVC_$UNIMPLEMENTED without the part)
        .long   PCHIST_$CNTL                | 0x25
        .long   PROC2_$GET_INFO             | 0x26
        svc_display_ctl SMD_$BLT            | 0x27
        .long   SVC_$TRAP8_INVALID          | 0x28
        .long   SVC_$TRAP8_INVALID          | 0x29
        svc_display SMD_$SIGNAL             | 0x2A
        svc_display_ctl_invalid SMD_$SOFT_SCROLL| 0x2B
        .long   SVC_$TRAP8_INVALID          | 0x2C
        .long   TERM_$INQUIRE               | 0x2D
        .long   SVC_$TRAP8_INVALID          | 0x2E
        .long   SVC_$TRAP8_INVALID          | 0x2F
        .long   SVC_$TRAP8_INVALID          | 0x30
        .long   TERM_$GET_EC                | 0x31
        svc_entry color_board, COLOR_$MAP   | 0x32 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$GET_EC   | 0x33 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$WIRE       | 0x34 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$UNWIRE     | 0x35 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x36
        .long   SVC_$TRAP8_INVALID          | 0x37
        .long   TERM_$READ_COND             | 0x38
        .long   SVC_$TRAP8_INVALID          | 0x39
        .long   SVC_$TRAP8_INVALID          | 0x3A
        svc_entry pbu_driver, PBU2_$WIRE    | 0x3B (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$SET_NAME             | 0x3C
        .long   PROC2_$SET_PRIORITY         | 0x3D
        .long   PROC2_$GET_EC               | 0x3E
        .long   PROC2_$LIST_PGROUP          | 0x3F
        .long   SVC_$TRAP8_INVALID          | 0x40
        .long   SVC_$TRAP8_INVALID          | 0x41
        .long   SVC_$TRAP8_INVALID          | 0x42
        svc_entry ct_driver, CT_$CONTROL    | 0x43 (SVC_$UNIMPLEMENTED without the part)
        svc_entry ct_driver, CT_$WAIT       | 0x44 (SVC_$UNIMPLEMENTED without the part)
        .long   DIR_$DROP_DIRU              | 0x45
        .long   DIR_$SET_DEFAULT_ACL        | 0x46
        .long   DIR_$GET_DEFAULT_ACL        | 0x47
        .long   NAME_$READ_DIRS_PS          | 0x48
        .long   SVC_$TRAP8_INVALID          | 0x49
        .long   ACL_$GET_PROJ_LIST          | 0x4A
        .long   MST_$CHANGE_RIGHTS          | 0x4B
        .long   XPD_$GET_TARGET_INFO        | 0x4C
        .long   FILE_$READ_LOCK_ENTRYI      | 0x4D
        .long   ROUTE_$INCOMING             | 0x4E
        svc_entry gpu_driver, GPU_$DIAG_WIRE        | 0x4F (SVC_$UNIMPLEMENTED without the part)
        svc_display SMD_$INQ_KBD_TYPE       | 0x50
        .long   ROUTE_$GET_EC               | 0x51
        .long   SVC_$TRAP8_INVALID          | 0x52
        svc_display SMD_$DM_COND_EVENT_WAIT | 0x53
        .long   DISK_$READ_MFG_BADSPOTS     | 0x54
        .long   DISK_$GET_MNT_INFO          | 0x55
        .long   PROC2_$SET_SIG_MASK         | 0x56
        .long   PROC2_$SIGRETURN            | 0x57
        .long   PROC2_$WAIT                 | 0x58
        .long   PROC2_$SIGNAL               | 0x59
        .long   PROC2_$SIGNAL_PGROUP        | 0x5A
        .long   PROC2_$GET_CR_REC           | 0x5B
        .long   TTY_$K_SET_FUNC_CHAR        | 0x5C
        .long   TTY_$K_INQ_FUNC_CHAR        | 0x5D
        .long   TTY_$K_SET_INPUT_FLAG       | 0x5E
        .long   TTY_$K_SET_OUTPUT_FLAG      | 0x5F
        .long   TTY_$K_SET_ECHO_FLAG        | 0x60
        .long   TTY_$K_ENABLE_FUNC          | 0x61
        .long   SIO_$K_SET_PARAM            | 0x62
        .long   SIO_$K_INQ_PARAM            | 0x63
        .long   FILE_$SET_MGR_ATTR          | 0x64
        .long   XPD_$GET_REGISTERS          | 0x65
        .long   XPD_$PUT_REGISTERS          | 0x66
        .long   FILE_$RESERVE               | 0x67
        .long   SVC_$TRAP8_INVALID          | 0x68
        .long   ACL_$GET_RES_SIDS           | 0x69
        .long   FILE_$FW_PAGES              | 0x6A
        .long   PROC2_$SET_ACCT_INFO        | 0x6B
        .long   FILE_$IMPORT_LK             | 0x6C
        .long   FILE_$UNLOCK_D              | 0x6D
        .long   FILE_$SET_LEN_D             | 0x6E
        .long   FILE_$TRUNCATE_D            | 0x6F
        .long   FILE_$SET_DTM_F             | 0x70
        .long   TTY_$K_SET_FLAG             | 0x71
        .long   SVC_$TRAP8_INVALID          | 0x72
        .long   MST_$UNMAP_AND_FREE_AREA    | 0x73
        .long   SVC_$TRAP8_INVALID          | 0x74
        .long   PROC2_$NAME_TO_UID          | 0x75
        .long   SVC_$TRAP8_INVALID          | 0x76
        .long   SVC_$TRAP8_INVALID          | 0x77
        .long   SVC_$TRAP8_INVALID          | 0x78
        svc_entry scsi_driver, SCSI_$GET_EC | 0x79 (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$GET_INFO| 0x7A (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$SETUP  | 0x7B (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$WIRE   | 0x7C (SVC_$UNIMPLEMENTED without the part)
        .long   MSG_$SHARE_SOCKET           | 0x7D
        .long   TTY_$K_INQ_DELAY            | 0x7E
        .long   TTY_$K_SET_DELAY            | 0x7F
        .long   MAC_$SEND                   | 0x80
        .long   XNS_IDP_$SEND               | 0x81
        .long   PROC2_$PGROUP_INFO          | 0x82

        .globl  SVC_$TRAP5_TABLE
SVC_$TRAP5_TABLE:            | 0xE7BAF2, 99 entries
        .long   SVC_$TRAP8_INVALID          | 0x00  Reserved
        .long   MST_$MAP_AREA               | 0x01
        .long   SVC_$TRAP8_INVALID          | 0x02
        .long   SVC_$TRAP8_INVALID          | 0x03
        .long   SVC_$TRAP8_INVALID          | 0x04
        .long   ACL_$RIGHTS                 | 0x05
        .long   SVC_$TRAP8_INVALID          | 0x06
        .long   ASKNODE_$INFO               | 0x07
        .long   DISK_$AS_READ               | 0x08
        .long   DISK_$AS_WRITE              | 0x09
        .long   SVC_$TRAP8_INVALID          | 0x0A
        .long   SVC_$TRAP8_INVALID          | 0x0B
        .long   SVC_$TRAP8_INVALID          | 0x0C
        .long   SVC_$TRAP8_INVALID          | 0x0D
        .long   SVC_$TRAP8_INVALID          | 0x0E
        .long   SVC_$TRAP8_INVALID          | 0x0F
        .long   SVC_$TRAP8_INVALID          | 0x10
        svc_entry pbu_driver, PBU_$GET_DCTE | 0x11 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$READ_CSR | 0x12 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$CONTROL  | 0x13 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU2_$WIRE_MAP        | 0x14 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$WRITE_CSR        | 0x15 (SVC_$UNIMPLEMENTED without the part)
        svc_display TPAD_$INQUIRE           | 0x16
        svc_display TPAD_$SET_MODE          | 0x17
        .long   VFMT_$MAIN                  | 0x18
        .long   VOLX_$GET_INFO              | 0x19
        .long   VTOC_$GET_UID               | 0x1A
        .long   NETLOG_$CNTL                | 0x1B
        .long   PROC2_$GET_UPIDS            | 0x1C
        .long   SVC_$TRAP8_INVALID          | 0x1D
        .long   SVC_$TRAP8_INVALID          | 0x1E
        svc_entry pbu_driver, PBU2_$ALLOCATE_MAP    | 0x1F (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU2_$MAP     | 0x20 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU2_$UNMAP   | 0x21 (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU2_$UNWIRE  | 0x22 (SVC_$UNIMPLEMENTED without the part)
        .long   MST_$GET_UID_ASID           | 0x23
        .long   MST_$INVALIDATE             | 0x24
        .long   FILE_$INVALIDATE            | 0x25
        .long   SVC_$TRAP8_INVALID          | 0x26
        .long   SVC_$TRAP8_INVALID          | 0x27
        .long   SVC_$TRAP8_INVALID          | 0x28
        .long   MST_$SET_TOUCH_AHEAD_CNT    | 0x29
        .long   OS_$CHKSUM                  | 0x2A
        .long   FILE_$GET_SEG_MAP           | 0x2B
        .long   SVC_$TRAP8_INVALID          | 0x2C
        svc_entry pbu_driver, PBU2_$ASSOC   | 0x2D (SVC_$UNIMPLEMENTED without the part)
        .long   FILE_$UNLOCK_PROC           | 0x2E
        svc_entry ct_driver, CT_$READ       | 0x2F (SVC_$UNIMPLEMENTED without the part)
        svc_entry ct_driver, CT_$WRITE      | 0x30 (SVC_$UNIMPLEMENTED without the part)
        .long   DIR_$ADDU                   | 0x31
        .long   DIR_$DROPU                  | 0x32
        .long   DIR_$CREATE_DIRU            | 0x33
        .long   DIR_$ADD_BAKU               | 0x34
        .long   SVC_$TRAP8_INVALID          | 0x35
        .long   SVC_$TRAP8_INVALID          | 0x36
        .long   SVC_$TRAP8_INVALID          | 0x37
        .long   DIR_$ADD_HARD_LINKU         | 0x38
        .long   SVC_$TRAP8_INVALID          | 0x39
        .long   RIP_$UPDATE                 | 0x3A
        .long   DIR_$DROP_LINKU             | 0x3B
        .long   ACL_$CHECK_RIGHTS           | 0x3C
        .long   DIR_$DROP_HARD_LINKU        | 0x3D
        .long   ROUTE_$OUTGOING             | 0x3E
        .long   SVC_$TRAP8_INVALID          | 0x3F
        svc_entry gpu_driver, GPU_$CMND     | 0x40 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x41
        .long   NET_$GET_INFO               | 0x42
        .long   DIR_$GET_ENTRYU             | 0x43
        .long   AUDIT_$LOG_EVENT            | 0x44
        .long   FILE_$SET_PROT              | 0x45
        .long   TTY_$K_GET                  | 0x46
        .long   TTY_$K_PUT                  | 0x47
        .long   PROC2_$ALIGN_CTL            | 0x48
        .long   SVC_$TRAP8_INVALID          | 0x49
        .long   XPD_$READ_PROC              | 0x4A
        .long   XPD_$WRITE_PROC             | 0x4B
        .long   DIR_$SET_DEF_PROTECTION     | 0x4C
        .long   DIR_$GET_DEF_PROTECTION     | 0x4D
        .long   ACL_$COPY                   | 0x4E
        .long   ACL_$CONVERT_FUNKY_ACL      | 0x4F
        .long   DIR_$SET_PROTECTION         | 0x50
        .long   FILE_$OLD_AP                | 0x51
        .long   ACL_$SET_RE_ALL_SIDS        | 0x52
        .long   ACL_$GET_RE_ALL_SIDS        | 0x53
        .long   FILE_$EXPORT_LK             | 0x54
        .long   FILE_$CHANGE_LOCK_D         | 0x55
        .long   XPD_$READ_PROC_ASYNC        | 0x56
        .long   SVC_$TRAP8_INVALID          | 0x57
        svc_display SMD_$MAP_DISPLAY_MEMORY | 0x58
        .long   SVC_$TRAP8_INVALID          | 0x59
        .long   SVC_$TRAP8_INVALID          | 0x5A
        .long   SVC_$TRAP8_INVALID          | 0x5B
        .long   SVC_$TRAP8_INVALID          | 0x5C
        svc_entry scsi_driver, SCSI_$UNWIRE | 0x5D (SVC_$UNIMPLEMENTED without the part)
        svc_display SMD_$UNMAP_DISPLAY_MEMORY| 0x5E
        svc_entry display_devices, SMD_$SET_COLOR_TABLE| 0x5F (SVC_$UNIMPLEMENTED without the part)
        .long   RIP_$TABLE_D                | 0x60
        .long   XNS_ERROR_$SEND             | 0x61
        svc_entry display_devices, SMD_$DEVICE_INFO| 0x62 (SVC_$UNIMPLEMENTED without the part)

        .globl  SVC_$TRAP7_TABLE
SVC_$TRAP7_TABLE:            | 0xE7BC7E, 59 entries
        .long   FILE_$LOCK                  | 0x00
        .long   VFMT_$WRITE10               | 0x01
        .long   MST_$MAP_AREA_AT            | 0x02
        .long   SVC_$TRAP8_INVALID          | 0x03
        .long   SVC_$TRAP8_INVALID          | 0x04
        .long   SVC_$TRAP8_INVALID          | 0x05
        svc_entry mt_driver, MT_$CHAIN_READ | 0x06 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$CHAIN_WRITE        | 0x07 (SVC_$UNIMPLEMENTED without the part)
        svc_entry mt_driver, MT_$WAIT       | 0x08 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x09
        .long   SVC_$TRAP8_INVALID          | 0x0A
        svc_display_ctl_invalid SMD_$WRITE_STRING| 0x0B
        .long   SVC_$TRAP8_INVALID          | 0x0C
        .long   VFMT_$FORMAT10              | 0x0D
        .long   VFMT_$FORMAT10              | 0x0E  Same handler as 0x0D
        .long   STOP_$WATCH                 | 0x0F
        .long   SVC_$TRAP8_INVALID          | 0x10
        .long   SVC_$TRAP8_INVALID          | 0x11
        .long   ASKNODE_$GET_INFO           | 0x12
        .long   DISK_$DIAG_IO               | 0x13
        .long   SVC_$TRAP8_INVALID          | 0x14
        .long   SVC_$TRAP8_INVALID          | 0x15
        svc_display_ctl SMD_$WRITE_STR_CLIP | 0x16
        svc_entry ct_driver, CT_$DIAG       | 0x17 (SVC_$UNIMPLEMENTED without the part)
        .long   TIME_$SET_ITIMER            | 0x18
        .long   OSINFO_$GET_SEG_TABLE       | 0x19
        .long   DIR_$CNAMEU                 | 0x1A
        .long   DIR_$DELETE_FILEU           | 0x1B
        .long   DIR_$ADD_LINKU              | 0x1C
        .long   SVC_$TRAP8_INVALID          | 0x1D
        .long   SVC_$TRAP8_INVALID          | 0x1E
        .long   SVC_$TRAP8_INVALID          | 0x1F
        .long   SVC_$TRAP8_INVALID          | 0x20
        .long   ASKNODE_$WHO_REMOTE         | 0x21
        .long   MST_$REMAP                  | 0x22
        .long   DIR_$ROOT_ADDU              | 0x23
        svc_entry iic_driver, IIC_$SEND     | 0x24 (SVC_$UNIMPLEMENTED without the part)
        svc_entry iic_driver, IIC_$RECEIVE  | 0x25 (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x26
        svc_entry gpu_driver, GPU_$DIAG_ACQUIRE     | 0x27 (SVC_$UNIMPLEMENTED without the part)
        .long   ASKNODE_$WHO_NOTOPO         | 0x28
        .long   NET_$OPEN                   | 0x29
        .long   NET_$CLOSE                  | 0x2A
        .long   NET_$IOCTL                  | 0x2B
        .long   DIR_$FIND_UID               | 0x2C
        .long   FILE_$GET_ATTRIBUTES        | 0x2D
        .long   SVC_$TRAP8_INVALID          | 0x2E
        .long   PCHIST_$UNIX_PROFIL_CNTL    | 0x2F
        .long   XPD_$RESTART                | 0x30
        .long   FILE_$GET_ATTR_INFO         | 0x31
        .long   ACL_$PRIM_CREATE            | 0x32
        .long   PROC2_$GET_REGS             | 0x33
        .long   ACL_$CONVERT_TO_9ACL        | 0x34
        .long   ACL_$SET_RES_ALL_SIDS       | 0x35
        .long   ACL_$GET_RES_ALL_SIDS       | 0x36
        .long   FILE_$LOCK_D                | 0x37
        .long   FILE_$CREATE_IT             | 0x38
        .long   ACL_$RIGHTS_CHECK           | 0x39
        .long   RIP_$UPDATE_D               | 0x3A

        .globl  SVC_$TRAP8_TABLE
SVC_$TRAP8_TABLE:            | 0xE7BD6A, 56 entries
        .long   MST_$MAP                    | 0x00  8 args
        .long   MST_$MAP_AT                 | 0x01  9 args
        .long   MST_$MAP_GLOBAL             | 0x02  8 args
        .long   VFMT_$WRITE10               | 0x03  11 args, 0xE825F4 (the VFMT_$WRITEN trampoline)
        .long   VOLX_$DISMOUNT              | 0x04  7 args
        .long   VOLX_$GET_UIDS              | 0x05  7 args
        .long   SVC_$TRAP8_INVALID          | 0x06  8 args (invalid)
        .long   DISK_$PV_ASSIGN             | 0x07  8 args
        .long   MSG_$RCV                    | 0x08  12 args
        .long   MSG_$SAR                    | 0x09  17 args
        .long   MSG_$SEND                   | 0x0A  11 args
        .long   SVC_$TRAP8_INVALID          | 0x0B  7 args (invalid)
        svc_display SMD_$LOAD_CRSR_BITMAP   | 0x0C  8 args
        svc_display SMD_$READ_CRSR_BITMAP   | 0x0D  8 args
        .long   VFMT_$FORMAT10              | 0x0E  14 args, 0xE825E4 (the VFMT_$FORMAT10/ENCODE10 trampoline)
        .long   VFMT_$FORMAT10              | 0x0F  9 args, 0xE825E4 (VFMT_$FORMAT5/ENCODE5)
        .long   VFMT_$FORMAT10              | 0x10  14 args, 0xE825E4
        .long   VFMT_$FORMAT10              | 0x11  9 args, 0xE825E4 (VFMT_$FORMAT2/ENCODE2)
        .long   CAL_$WRITE_CALENDAR         | 0x12  7 args
        .long   MSG_$RCV_CONTIG             | 0x13  9 args
        .long   OSINFO_$GET_MMAP            | 0x14  7 args
        .long   ASKNODE_$INTERNET_INFO      | 0x15  7 args
        .long   MST_$GET_VA_INFO            | 0x16  8 args
        .long   MSG_$SENDI                  | 0x17  14 args
        .long   MSG_$RCVI                   | 0x18  16 args
        .long   MSG_$RCV_CONTIGI            | 0x19  13 args
        .long   MSG_$SARI                   | 0x1A  18 args
        .long   SVC_$TRAP8_INVALID          | 0x1B  7 args (invalid)
        .long   MSG_$SEND_HW                | 0x1C  15 args
        svc_entry pbu_driver, PBU_$WIRE_SPECIAL     | 0x1D  8 args (SVC_$UNIMPLEMENTED without the part)
        svc_entry pbu_driver, PBU_$DMA_START        | 0x1E  7 args (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x1F  9 args (invalid)
        .long   MST_$MAP_TOP                | 0x20  8 args
        .long   NET_$SEND                   | 0x21  9 args
        .long   NET_$RCV                    | 0x22  9 args
        .long   DIR_$DIR_READU              | 0x23  9 args
        .long   DIR_$READ_LINKU             | 0x24  8 args
        svc_entry pbu_driver, PBU2_$DMA_START       | 0x25  8 args (SVC_$UNIMPLEMENTED without the part)
        .long   SVC_$TRAP8_INVALID          | 0x26  10 args (invalid)
        .long   SVC_$TRAP8_INVALID          | 0x27  10 args (invalid)
        .long   PROC2_$COMPLETE_VFORK       | 0x28  8 args
        .long   SVC_$TRAP8_INVALID          | 0x29  8 args (invalid)
        .long   SVC_$TRAP8_INVALID          | 0x2A  7 args (invalid)
        .long   DIR_$RESOLVE                | 0x2B  11 args
        .long   VOLX_$MOUNT                 | 0x2C  9 args
        .long   ACL_$IMAGE                  | 0x2D  7 args
        .long   DISK_$PV_ASSIGN_N           | 0x2E  10 args
        .long   DISK_$AS_XFER_MULTI         | 0x2F  8 args
        .long   PROC2_$FORK                 | 0x30  8 args
        svc_entry scsi_driver, SCSI_$DO_COMMAND| 0x31 (SVC_$UNIMPLEMENTED without the part)
        svc_entry scsi_driver, SCSI_$WAIT   | 0x32 (SVC_$UNIMPLEMENTED without the part)
        .long   PROC2_$CREATE               | 0x33  11 args
        svc_display TPAD_$SET_UNIT_MODE     | 0x34  7 args
        svc_display TPAD_$INQUIRE_UNIT      | 0x35  7 args
        svc_entry scsi_driver, SCSI_$DO_SYS_DEVICE_CMD| 0x36 (SVC_$UNIMPLEMENTED without the part)
        .long   MSG_$RCV_HW                 | 0x37  14 args

        .globl  SVC_$TRAP8_ARGCOUNT
SVC_$TRAP8_ARGCOUNT:         | 0xE7BE4A, 56 entries
        .byte   0x07                        | 0x00  MST_$MAP: 8 args
        .byte   0x08                        | 0x01  MST_$MAP_AT: 9 args
        .byte   0x07                        | 0x02  MST_$MAP_GLOBAL: 8 args
        .byte   0x0a                        | 0x03  VFMT_$WRITEN trampoline: 11 args
        .byte   0x06                        | 0x04  VOLX_$DISMOUNT: 7 args
        .byte   0x06                        | 0x05  VOLX_$GET_UIDS: 7 args
        .byte   0x07                        | 0x06  Invalid: 8 args
        .byte   0x07                        | 0x07  DISK_$PV_ASSIGN: 8 args
        .byte   0x0b                        | 0x08  MSG_$RCV: 12 args
        .byte   0x10                        | 0x09  MSG_$SAR: 17 args
        .byte   0x0a                        | 0x0A  MSG_$SEND: 11 args
        .byte   0x06                        | 0x0B  Invalid: 7 args
        .byte   0x07                        | 0x0C  SMD_$LOAD_CRSR_BITMAP: 8 args
        .byte   0x07                        | 0x0D  SMD_$READ_CRSR_BITMAP: 8 args
        .byte   0x0d                        | 0x0E  VFMT_$FORMATN trampoline: 14 args
        .byte   0x08                        | 0x0F  VFMT_$FORMATN trampoline: 9 args
        .byte   0x0d                        | 0x10  VFMT_$FORMATN trampoline: 14 args
        .byte   0x08                        | 0x11  VFMT_$FORMATN trampoline: 9 args
        .byte   0x06                        | 0x12  CAL_$WRITE_CALENDAR: 7 args
        .byte   0x08                        | 0x13  MSG_$RCV_CONTIG: 9 args
        .byte   0x06                        | 0x14  OSINFO_$GET_MMAP: 7 args
        .byte   0x06                        | 0x15  ASKNODE_$INTERNET_INFO: 7 args
        .byte   0x07                        | 0x16  MST_$GET_VA_INFO: 8 args
        .byte   0x0d                        | 0x17  MSG_$SENDI: 14 args
        .byte   0x0f                        | 0x18  MSG_$RCVI: 16 args
        .byte   0x0c                        | 0x19  MSG_$RCV_CONTIGI: 13 args
        .byte   0x11                        | 0x1A  MSG_$SARI: 18 args
        .byte   0x06                        | 0x1B  Invalid: 7 args
        .byte   0x0e                        | 0x1C  MSG_$SEND_HW: 15 args
        .byte   0x07                        | 0x1D  Unimplemented: 8 args
        .byte   0x06                        | 0x1E  Unimplemented: 7 args
        .byte   0x08                        | 0x1F  Invalid: 9 args
        .byte   0x07                        | 0x20  MST_$MAP_TOP: 8 args
        .byte   0x08                        | 0x21  NET_$SEND: 9 args
        .byte   0x08                        | 0x22  NET_$RCV: 9 args
        .byte   0x08                        | 0x23  DIR_$DIR_READU: 9 args
        .byte   0x07                        | 0x24  DIR_$READ_LINKU: 8 args
        .byte   0x07                        | 0x25  Unimplemented: 8 args
        .byte   0x09                        | 0x26  Invalid: 10 args
        .byte   0x09                        | 0x27  Invalid: 10 args
        .byte   0x07                        | 0x28  PROC2_$COMPLETE_VFORK: 8 args
        .byte   0x07                        | 0x29  Invalid: 8 args
        .byte   0x06                        | 0x2A  Invalid: 7 args
        .byte   0x0a                        | 0x2B  DIR_$RESOLVE: 11 args
        .byte   0x08                        | 0x2C  VOLX_$MOUNT: 9 args
        .byte   0x06                        | 0x2D  ACL_$IMAGE: 7 args
        .byte   0x09                        | 0x2E  DISK_$PV_ASSIGN_N: 10 args
        .byte   0x07                        | 0x2F  DISK_$AS_XFER_MULTI: 8 args
        .byte   0x07                        | 0x30  PROC2_$FORK: 8 args
        .byte   0x06                        | 0x31  Unimplemented: 7 args
        .byte   0x07                        | 0x32  Unimplemented: 8 args
        .byte   0x0a                        | 0x33  PROC2_$CREATE: 11 args
        .byte   0x06                        | 0x34  TPAD_$SET_UNIT_MODE: 7 args
        .byte   0x06                        | 0x35  TPAD_$INQUIRE_UNIT: 7 args
        .byte   0x0b                        | 0x36  Unimplemented: 12 args
        .byte   0x0d                        | 0x37  MSG_$RCV_HW: 14 args

        .word   0x0000                      | 0xE7BE82: to the segment end, the image's bytes
