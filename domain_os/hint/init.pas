{ HINT_$INIT - open, map and lock the hint file.

  Image addresses:
    sau2  0x00E3122C  HINT_$INIT

  - `node_data/hint_file is resolved (or created), mapped and locked; a
    file still uninitialized (version 1) is left unpublished.
  - Otherwise the file and its UID are published, a file of another
    version reinitialized, and the network taken from a file written
    for port 0's type and socket (else 0).
  - A failure drops the name, deletes the object and tries once more; a
    second failure leaves HINT_$HINTFILE_PTR clear.
  - FILE_$DELETE gets the UID NAME_$DROP has set to UID_$NIL;
    FILE_$LOCK's status is not tested.

  Status stored: none.
}

{ TODO(pascal) 8 unaddressed frame bytes (stand-in unused_10)

  The SAU2 frame has 8 bytes above MST_$MAPS' map_info that nothing
  addresses.  map_info is a longword (MST_$MAPS passes it on unread;
  its other callers have a longword); what the 8 bytes held is not
  known. }

[section(os_init_proc, os_init_data)]
procedure hint_$init;
label
  failed;
var
  hintfile_uid: uid_$t;
  unused_10: array[1..2] of integer32;    { the stand-in (TODO) }
  map_info: integer32;
  status: status_$t;
  lock_info: integer32;
  retry: boolean;
begin
  retry := false;
  hint_$hintfile_ptr := nil;
  hint_$hintfile_uid := uid_$nil;

  repeat
    name_$resolve('`node_data/hint_file', 20, hintfile_uid, status);
    if status.all <> status_$ok then begin
      name_$cr_file('`node_data/hint_file', 20, hintfile_uid, status);
      if status.all <> status_$ok then goto failed;
    end;

    hint_$data_hintfile_ptr := mst_$maps(0, true, hintfile_uid, 0, 32767,
                                         16#16, 0, true, map_info, status);
    if status.all <> status_$ok then goto failed;

    file_$lock(hintfile_uid, 0, 4, false, lock_info, status);

    if hint_$data_hintfile_ptr^.version = 1 then return;
    hint_$hintfile_ptr := hint_$data_hintfile_ptr;
    hint_$hintfile_uid := hintfile_uid;
    if hint_$data_hintfile_ptr^.version <> 7 then hint_$clear_hintfile;

    if (hint_$data_hintfile_ptr^.port_type = route_$portp[0]^.port_type)
       and then
       (hint_$data_hintfile_ptr^.socket = route_$portp[0]^.socket) then
      route_$port[0].network := hint_$data_hintfile_ptr^.net_port
    else
      route_$port[0].network := 0;
    return;

failed:
    if retry then exit;
    name_$drop('`node_data/hint_file', 20, hintfile_uid, status);
    if status.all = status_$ok then
      discard(file_$delete(hintfile_uid, status));
    retry := true;
  until false;

  { the second failure }
  hint_$hintfile_ptr := nil;
end;
