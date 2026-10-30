{ tape/tape.ins.pas - TAPE_ (tape boot, map module TAPE_BOOT) routine
  headings, for the Domain Pascal tree.

  Configured out of the SAU2..SAU4 kernels, where TAPE_$BOOT reports
  that the system was not booted from tape; with `tape_boot' (the
  SAU5..SAU9) it loads the boot shell from the cartridge tape, whose
  format and CT_ headings are at the end of this file.  Include
  base/base.ins.pas before it.
}

{ TAPE_$BOOT - boot from tape: load the boot shell, return its entry. }
function tape_$boot(out entry_point: integer32;
                    out status_ret: status_$t): boolean; extern;


%if tape_boot %then
{ ---- Booting from the cartridge tape (`tape_boot', base/config.ins.pas:
  the SAU5..SAU9).  The tape's format as the SAU5 TAPE_$BOOT reads it. ----
  }

const
  { The cartridge-tape statuses TAPE_$BOOT tests (16#0028FFFC "warning:
    tape not at load-point", taken as ok after CT_$ACQUIRE, and
    16#0028001A "filemark detected", the end of the file's blocks) are
    ct/ct.ins.pas's. }

  { The tape's record types TAPE_$BOOT knows: 2 a file's directory
    entry (its pathname at the data's byte 13 on), 0 an object header,
    1 object data, 8 the object's end. }
  tape_rec_object_hdr = 0;
  tape_rec_object_data = 1;
  tape_rec_dir_entry = 2;
  tape_rec_object_end = 8;

type
  { A tape block as read, 512 bytes: its sequence number (1 for the
    first), the UID of the save set, the count of bytes used, then the
    records; the first word alone (TAPE_$BOOT clears it in every block
    of the buffer before the first read). }
  tape_$block_t = record
    case integer of
      1: (seq: integer32;                 { 0x00 }
          uid: uid_$t;                    { 0x04 }
          len: pinteger;                  { 0x0C }
          data: array[1..498] of char);   { 0x0E }
      2: (w0: integer);                   { 0x00 }
  end;
  tape_$block_ptr_t = ^tape_$block_t;

  { A record in a block: its type, the length of its data, a word
    nothing reads, the data (padded to an even length). }
  tape_$rec_t = record
    rtype: integer;                       { 0x00 }
    len: pinteger;                        { 0x02 }
    unused_04: integer;                   { 0x04 }
    data: array[1..500] of char;          { 0x06 }
  end;
  tape_$rec_ptr_t = ^tape_$rec_t;

  { The words an object-data record's data is copied as. }
  tape_$words_t = array[1..250] of integer;
  tape_$words_ptr_t = ^tape_$words_t;

  { The pages CT_$READ reads into, one address per 512-byte block. }
  tape_$page_list_t = array[1..256] of integer32;

  { The booted file's first 0x400 bytes: [1] the address to map it at,
    [2] its entry point (flop/flop.ins.pas's header, longer). }
  tape_$header_t = array[1..256] of integer32;
  tape_$header_ptr_t = ^tape_$header_t;

  { The file name TAPE_$BOOT looks for, 16 characters. }
  tape_$name_t = array[1..16] of char;
  tape_$name_ptr_t = ^tape_$name_t;

{ CT_$ACQUIRE, CT_$CONTROL, CT_$READ and CT_$WAIT, which TAPE_$BOOT
  calls: ct/ct.ins.pas. }
%endif
