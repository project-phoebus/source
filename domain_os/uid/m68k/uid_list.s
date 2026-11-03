/*
 * uid/m68k/uid_list.s - UID_LIST, the well-known UIDs
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the bytes are the
 * image's (no cell is relocated: none is in the image's RELOC fixup
 * table).
 *
 * SAU2 map: "I E1737C UID_LIST size = 210" (WIRED_PROC), 0x00E1737C..
 * 0x00E1758B, between UID_$HASH (uid/m68k/hash.s, 0xE17360) and LOG_
 * (0xE1758C), with no filler on either side.  66 UIDs of 8 bytes (a
 * high and a low longword, base/base.ins.pas uid_$t), under the map's 80
 * names: 13 cells carry two or three names (RGYC_$P_SYS_USER_UID and
 * ACL_$SYS_USER_UID, ...; RGYC_$G_LOCKSMITH_UID, ACL_$LOCKSMITH_UID and
 * RGYC_$P_ROOT_UID).  Each name is a global label here, in the map's
 * order; the values are the image's (`gsk read 0xe1737c 0x210').  The
 * Pascal tree declares the ones it uses `extern uid_$t' in the insert
 * files (base, acl, uid, rgyc, vtoc, bat, name, ring, smd, anon).
 *
 * Why assembly and not a Pascal module (a dpc probe, a scratch module
 * with the 66 cells):
 *   - a Pascal variable has one name, and 13 of the cells have two or
 *     three map names, all of which the Pascal tree or the map needs
 *     (both ACL_$LOGIN_UID and RGYC_$G_LOGIN_UID are referenced, and
 *     ACL_$LOCKSMITH_UID and RGYC_$G_LOCKSMITH_UID); no construct of the
 *     language (ref 7.2: `define', `extern', overlay sections) gives one
 *     object a second global name;
 *   - the segment is an `I' segment of WIRED_PROC.  `module uid_list, ,
 *     wired_proc;' with the 66 cells `define'd lays them out with the
 *     image's bytes (dpc -o: `.moddata.UID_LIST.WIRED_PROC', 0x210 bytes,
 *     identical), but tools/gen_layout_ld.py keys a dpc block only by a
 *     `D' segment: "the map has no single data segment of module UID_LIST
 *     in section WIRED_PROC (candidates: none)".
 * The map's segment kind and the aliases are what an assembler module
 * gives: data in a code section and several labels at one address.
 */

        .section ".text.UID_$NIL","ax",@progbits
        .even

        .globl  UID_$NIL
        .globl  ACL_$NIL
        .globl  PV_LABEL_$UID
        .globl  LV_LABEL_$UID
        .globl  VTOC_$UID
        .globl  BAT_$UID
        .globl  VTOC_BKT_$UID
        .globl  SYSBOOT_$UID
        .globl  SLINK_$UID
        .globl  UNSTRUCT_$UID
        .globl  OS_PG_FILE_$UID
        .globl  DISPLAY1_$UID
        .globl  DISPLAY2_$UID
        .globl  NAME_$CANNED_ROOT_UID
        .globl  SPECIAL_SEG_$UID
        .globl  DISKLESS_$UID
        .globl  NAME_$CANNED_REP_ROOT_UID
        .globl  DISPLAY3_$UID
        .globl  OS_WIRED_$UID
        .globl  ANON_$UID
        .globl  RGYC_$P_SYS_USER_UID
        .globl  ACL_$SYS_USER_UID
        .globl  RGYC_$G_SYS_PROJ_UID
        .globl  ACL_$SYS_PROJ_UID
        .globl  RGYC_$G_LOGIN_UID
        .globl  ACL_$LOGIN_UID
        .globl  RGYC_$G_LOCKSMITH_UID
        .globl  ACL_$LOCKSMITH_UID
        .globl  RGYC_$P_ROOT_UID
        .globl  RGYC_$O_SYS_ORG_UID
        .globl  ACL_$SYS_ORG_UID
        .globl  ACL_$FILE_ACL
        .globl  ACL_$DIR_ACL
        .globl  ACL_$FILEIN_ACL
        .globl  ACL_$DIRIN_ACL
        .globl  ACL_$DIR_MERGE_ACL
        .globl  ACL_$FILE_MERGE_ACL
        .globl  ACL_$FILE_SUBS_ACL
        .globl  RING_$NETWORK_UID
        .globl  IIC_$NETWORK_UID
        .globl  NIL_$NETWORK_UID
        .globl  ETHERNET_$NETWORK_UID
        .globl  USER_$NETWORK_UID
        .globl  UNKNOWN_$NETWORK_UID
        .globl  RING_8025_$NETWORK_UID
        .globl  ETHERNET_VME_$NETWORK_UID
        .globl  ACL_$FNIL
        .globl  ACL_$FNDWRX
        .globl  ACL_$FILE_NWRX
        .globl  ACL_$DNIL
        .globl  ACL_$DNDCAL
        .globl  ACL_$DIR_NCAL
        .globl  PPO_$NIL_USER_UID
        .globl  RGYC_$P_NIL_UID
        .globl  RGYC_$P_USER_UID
        .globl  PPO_$USER_UID
        .globl  RGYC_$P_ADMIN_UID
        .globl  RGYC_$P_BIN_UID
        .globl  RGYC_$P_DAEMON_UID
        .globl  RGYC_$P_LP_UID
        .globl  RGYC_$P_UUCP_UID
        .globl  PPO_$NIL_PROJ_UID
        .globl  RGYC_$G_NIL_UID
        .globl  RGYC_$G_SYS_ADMIN_UID
        .globl  PPO_$SYS_ADMIN_UID
        .globl  RGYC_$G_BACKUP_UID
        .globl  PPO_$BACKUP_UID
        .globl  RGYC_$G_SERVER_UID
        .globl  PPO_$SERVER_UID
        .globl  RGYC_$G_BIN_UID
        .globl  RGYC_$G_DAEMON_UID
        .globl  RGYC_$G_MAIL_UID
        .globl  RGYC_$G_SYS_UID
        .globl  RGYC_$G_STAFF_UID
        .globl  RGYC_$G_WHEEL_UID
        .globl  PPO_$NIL_ORG_UID
        .globl  RGYC_$O_NIL_UID
        .globl  RGYC_$O_APOLLO_UID
        .globl  PPO_$APOLLO_UID
        .globl  RGYC_$O_WHEEL_UID

UID_$NIL:                       /* e1737c */
        .long   0x00000000, 0x00000000

ACL_$NIL:                       /* e17384 */
        .long   0x00000100, 0x00000000

PV_LABEL_$UID:                  /* e1738c */
        .long   0x00000200, 0x00000000

LV_LABEL_$UID:                  /* e17394 */
        .long   0x00000201, 0x00000000

VTOC_$UID:                      /* e1739c */
        .long   0x00000202, 0x00000000

BAT_$UID:                       /* e173a4 */
        .long   0x00000203, 0x00000000

VTOC_BKT_$UID:                  /* e173ac */
        .long   0x00000204, 0x00000000

SYSBOOT_$UID:                   /* e173b4 */
        .long   0x00000315, 0x00000000

SLINK_$UID:                     /* e173bc */
        .long   0x0000031E, 0x00000000

UNSTRUCT_$UID:                  /* e173c4 */
        .long   0x00000321, 0x00000000

OS_PG_FILE_$UID:                /* e173cc */
        .long   0x00000323, 0x00000000

DISPLAY1_$UID:                  /* e173d4 */
        .long   0x00000400, 0x00000000

DISPLAY2_$UID:                  /* e173dc */
        .long   0x00000401, 0x00000000

NAME_$CANNED_ROOT_UID:          /* e173e4 */
        .long   0x00000308, 0x00000000

SPECIAL_SEG_$UID:               /* e173ec */
        .long   0x00000402, 0x00000000

DISKLESS_$UID:                  /* e173f4 */
        .long   0x00000403, 0x00000000

NAME_$CANNED_REP_ROOT_UID:      /* e173fc */
        .long   0x00000404, 0x00000000

DISPLAY3_$UID:                  /* e17404 */
        .long   0x00000405, 0x00000000

OS_WIRED_$UID:                  /* e1740c */
        .long   0x00000406, 0x00000000

ANON_$UID:                      /* e17414 */
        .long   0x00000407, 0x00000000

RGYC_$P_SYS_USER_UID:           /* e1741c */
ACL_$SYS_USER_UID:              /* e1741c */
        .long   0x00000500, 0x00000000

RGYC_$G_SYS_PROJ_UID:           /* e17424 */
ACL_$SYS_PROJ_UID:              /* e17424 */
        .long   0x00000540, 0x00000000

RGYC_$G_LOGIN_UID:              /* e1742c */
ACL_$LOGIN_UID:                 /* e1742c */
        .long   0x00000541, 0x00000000

RGYC_$G_LOCKSMITH_UID:          /* e17434 */
ACL_$LOCKSMITH_UID:             /* e17434 */
RGYC_$P_ROOT_UID:               /* e17434 */
        .long   0x00000542, 0x00000000

RGYC_$O_SYS_ORG_UID:            /* e1743c */
ACL_$SYS_ORG_UID:               /* e1743c */
        .long   0x00000580, 0x00000000

ACL_$FILE_ACL:                  /* e17444 */
        .long   0x00000600, 0x00000000

ACL_$DIR_ACL:                   /* e1744c */
        .long   0x00000601, 0x00000000

ACL_$FILEIN_ACL:                /* e17454 */
        .long   0x00000602, 0x00000000

ACL_$DIRIN_ACL:                 /* e1745c */
        .long   0x00000603, 0x00000000

ACL_$DIR_MERGE_ACL:             /* e17464 */
        .long   0x00000604, 0x00000000

ACL_$FILE_MERGE_ACL:            /* e1746c */
        .long   0x00000605, 0x00000000

ACL_$FILE_SUBS_ACL:             /* e17474 */
        .long   0x00000606, 0x00000000

RING_$NETWORK_UID:              /* e1747c */
        .long   0x00000700, 0x00000000

IIC_$NETWORK_UID:               /* e17484 */
        .long   0x00000701, 0x00000000

NIL_$NETWORK_UID:               /* e1748c */
        .long   0x00000702, 0x00000000

ETHERNET_$NETWORK_UID:          /* e17494 */
        .long   0x00000703, 0x00000000

USER_$NETWORK_UID:              /* e1749c */
        .long   0x00000704, 0x00000000

UNKNOWN_$NETWORK_UID:           /* e174a4 */
        .long   0x00000705, 0x00000000

RING_8025_$NETWORK_UID:         /* e174ac */
        .long   0x00000706, 0x00000000

ETHERNET_VME_$NETWORK_UID:      /* e174b4 */
        .long   0x00000707, 0x00000000

ACL_$FNIL:                      /* e174bc */
        .long   0x00010000, 0x00000000

ACL_$FNDWRX:                    /* e174c4 */
        .long   0x0001800F, 0x00000000

ACL_$FILE_NWRX:                 /* e174cc */
        .long   0x00018007, 0x00000000

ACL_$DNIL:                      /* e174d4 */
        .long   0x00022060, 0x00000000

ACL_$DNDCAL:                    /* e174dc */
        .long   0x0002A07F, 0x00000000

ACL_$DIR_NCAL:                  /* e174e4 */
        .long   0x0002A06F, 0x00000000

PPO_$NIL_USER_UID:              /* e174ec */
RGYC_$P_NIL_UID:                /* e174ec */
        .long   0x00800000, 0x00000000

RGYC_$P_USER_UID:               /* e174f4 */
PPO_$USER_UID:                  /* e174f4 */
        .long   0x00800001, 0x00000000

RGYC_$P_ADMIN_UID:              /* e174fc */
        .long   0x00800002, 0x00000000

RGYC_$P_BIN_UID:                /* e17504 */
        .long   0x00800003, 0x00000000

RGYC_$P_DAEMON_UID:             /* e1750c */
        .long   0x00800004, 0x00000000

RGYC_$P_LP_UID:                 /* e17514 */
        .long   0x00800005, 0x00000000

RGYC_$P_UUCP_UID:               /* e1751c */
        .long   0x00800006, 0x00000000

PPO_$NIL_PROJ_UID:              /* e17524 */
RGYC_$G_NIL_UID:                /* e17524 */
        .long   0x00800040, 0x00000000

RGYC_$G_SYS_ADMIN_UID:          /* e1752c */
PPO_$SYS_ADMIN_UID:             /* e1752c */
        .long   0x00800041, 0x00000000

RGYC_$G_BACKUP_UID:             /* e17534 */
PPO_$BACKUP_UID:                /* e17534 */
        .long   0x00800042, 0x00000000

RGYC_$G_SERVER_UID:             /* e1753c */
PPO_$SERVER_UID:                /* e1753c */
        .long   0x00800043, 0x00000000

RGYC_$G_BIN_UID:                /* e17544 */
        .long   0x00800044, 0x00000000

RGYC_$G_DAEMON_UID:             /* e1754c */
        .long   0x00800045, 0x00000000

RGYC_$G_MAIL_UID:               /* e17554 */
        .long   0x00800046, 0x00000000

RGYC_$G_SYS_UID:                /* e1755c */
        .long   0x00800047, 0x00000000

RGYC_$G_STAFF_UID:              /* e17564 */
        .long   0x00800048, 0x00000000

RGYC_$G_WHEEL_UID:              /* e1756c */
        .long   0x00800049, 0x00000000

PPO_$NIL_ORG_UID:               /* e17574 */
RGYC_$O_NIL_UID:                /* e17574 */
        .long   0x00800080, 0x00000000

RGYC_$O_APOLLO_UID:             /* e1757c */
PPO_$APOLLO_UID:                /* e1757c */
        .long   0x00800081, 0x00000000

RGYC_$O_WHEEL_UID:              /* e17584 */
        .long   0x00800082, 0x00000000
