{ ast_$set_attribute_internal - set one attribute of an object, with
  its nested dispatch ast_$set_attr_dispatch.

  Image addresses:
    sau2  0x00E05214  ast_$set_attribute_internal (module-local)
    sau9  0x3C4064C0  ast_$set_attribute_internal (module-local)
    sau2  0x00E04B00  ast_$set_attr_dispatch (nested)
    sau9  0x3C405DD4  ast_$set_attr_dispatch (nested)

  - A nil UID is validated instead.  Under the AST lock the object's
    AOTE is looked up (marked busy) or activated (forced for a process
    of type 8 or 9, "special").
  - A remote object's change is made in the AOTE and, with wait, sent
    to its node (REM_FILE_$SET_ATTRIBUTE).
  - The nested dispatch sets the attribute in the AOTE under the PMAP
    lock, one `case' arm each; an ACL change raises the new ACL's
    reference count and truncates the old ACL object.

  Status stored:
    status_$ok: the attribute was set
    ast_$validate_uid's result: the UID is nil
    file_$object_is_remote: attribute 6, 7 or 11 of a remote object
    status_$ast_only_local_access_allowed: an OS-only object, for a
      special process
    status_$ast_incompatible_request: an attribute the object's type
      does not take, or above 27
    status_$file_volume_has_been_mounted_read_only: a special object's
      attribute other than 5 and 11
    status_$ast_refcount_says_unused: a reference count step that would
      leave it unused
    the callees' statuses: the activation, a purify, the recursion, the
      truncation or the remote call failed
}

procedure ast_$set_attribute_internal(in uid: uid_$t; attr_id: integer;
                                      value: ast_$value_view_ptr_t;
                                      wait_flag: boolean;
                                      subject: ast_$exsid_ptr_t;
                                      in clock_in: time_$clock_t;
                                      out status_ret: status_$t);
  internal;
label
  10;
var
  local_value: file_$attr_value_t;
  addr_info: ast_$net_info_t;
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
  clock: time_$clock_t;
  is_special: boolean;
  len_adjust: boolean;
  p: ast_$value_view_ptr_t;

  { ast_$set_attr_dispatch: nested, the parent's frame through its static
    link. }
  procedure ast_$set_attr_dispatch;
  label
    20, 40, 50;
  var
    tmp: file_$attr_value_t;
    new_acl_uid: ast_$uid_byte_view_t;
    old_acl_uid: ast_$uid_byte_view_t;
    truncate_out: boolean;
    needs_purify: boolean;
    av: ast_$aote_view_ptr_t;
    obj_type: integer;
    rc: pinteger;
    keep_6: boolean;
    keep_5: boolean;
    keep_4: boolean;
    i: integer;
  begin
    status_ret.all := status_$ok;
    needs_purify := false;
    ml_$lock(ml_$pmap_lock);

    av := ast_$aote_view_ptr_t(aote);
    obj_type := av^.attrs.sa.obj_type;
    if (obj_type = 0) and then not (attr_id in [0..13]) then begin
      status_ret.all := status_$ast_incompatible_request;
      goto 40;
    end;

    if av^.attrs.sa.aflags.special then begin
      if attr_id = ast_attr_dirptr then
        av^.attrs.sa.dirptr := value^.val.uid
      else if attr_id = ast_attr_blocks then
        av^.attrs.sa.blocks := value^.val.long_val
      else
        status_ret.all := status_$file_volume_has_been_mounted_read_only;
      goto 40;
    end;

    case attr_id of
      ast_attr_readonly: begin
        av^.attrs.sa.aflags.readonly := value^.val.flag;
      end;
      ast_attr_copy_on_write: begin
        av^.attrs.sa.aflags.copy_on_write := value^.val.flag;
      end;
      ast_attr_dirty: begin
        av^.attrs.sa.aflags.dirty := value^.val.flag;
      end;
      ast_attr_os_only: begin
        av^.attrs.sa.pv.tail.os_only := value^.val.flag;
      end;
      ast_attr_access_mode: begin
        av^.attrs.sa.pv.tail.mode_5 := 0 in value^.val.audit;
        av^.attrs.sa.pv.tail.mode_4 := 1 in value^.val.audit;
      end;
      ast_attr_special_flag: begin
        av^.attrs.sa.aflags.special_flag := value^.val.flag;
      end;
      ast_attr_acl_uid: begin
        if av^.attrs.sa.acl_uid = value^.val.uid then
          goto 40;
        old_acl_uid.uid := av^.attrs.sa.acl_uid;
        new_acl_uid.uid := value^.val.uid;
        needs_purify := true;
        av^.attrs.sa.acl_uid := value^.val.uid;
        av^.attrs.sa.pv.r1 := [4];
        av^.attrs.sa.pv.r2 := [4];
        av^.attrs.sa.pv.r3 := [4];
        av^.attrs.sa.pv.r4 := [];
        av^.attrs.sa.pv.tail.r5 := [];
      end;
      ast_attr_creation_time: begin
        av^.attrs.sa.dtc := value^.val.uid;
      end;
      ast_attr_dirptr: begin
        av^.attrs.sa.dirptr := value^.val.uid;
      end;
      ast_attr_add_refcount: begin
        if av^.attrs.sa.refcount >= 65525 then
          goto 40;
        av^.attrs.sa.refcount := av^.attrs.sa.refcount + 1;
        av^.attrs.sa.aflags.readonly := true;
      end;
      ast_attr_set_refcount: begin
        av^.attrs.sa.refcount := value^.val.word_val;
        av^.attrs.sa.aflags.readonly := value^.val.word_val <> 0;
      end;
      ast_attr_sub_refcount: begin
        rc := av^.attrs.sa.refcount;
        if rc >= 65525 then
          goto 40;
        if (rc = 0) or else
           ((rc = 1) and then
            ((av^.attrs.sa.sub_type = 1) or else
             (av^.attrs.sa.sub_type = 2))) then begin
          status_ret.all := status_$ast_refcount_says_unused;
          goto 40;
        end;
        av^.attrs.sa.refcount := av^.attrs.sa.refcount - 1;
        if av^.attrs.sa.refcount = 0 then begin
          av^.attrs.sa.aflags.readonly := false;
          status_ret.all := status_$ast_refcount_says_unused;
        end;
      end;
      ast_attr_blocks: begin
        if av^.attrs.sa.blocks = value^.val.long_val then
          goto 40;
        av^.attrs.sa.blocks := value^.val.long_val;
        goto 20;
      end;
      ast_attr_dtm: begin
        av^.attrs.sa.dtm.high := value^.val.long_val;
        av^.attrs.sa.dtm.low := 0;
      end;
      ast_attr_dtu: begin
        av^.attrs.sa.dtu.high := value^.val.long_val;
        av^.attrs.sa.dtu.low := 0;
        aote^.flags := aote^.flags - [4];
      end;
      ast_attr_dtm_rounded, ast_attr_dtu_rounded: begin
        if (obj_type = 0) and then (value^.val.clock.low <> 0) then begin
          tmp.clock.high := value^.val.clock.high + 1;
          tmp.clock.low := 0;
        end
        else
          tmp.clock := value^.val.clock;
        if attr_id = ast_attr_dtm_rounded then
          av^.attrs.sa.dtm := tmp.clock
        else begin
          av^.attrs.sa.dtu := tmp.clock;
          aote^.flags := aote^.flags - [4];
        end;
      end;
      ast_attr_dtm_from_clock, ast_attr_dtu_from_clock: begin
        av^.attrs.sa.dtu := clock;
        if (obj_type = 0) and then (clock.low <> 0) then begin
          av^.attrs.sa.dtu.high := av^.attrs.sa.dtu.high + 1;
          av^.attrs.sa.dtu.low := 0;
          aote^.flags := aote^.flags - [4];
        end;
        if attr_id = ast_attr_dtm_from_clock then
          av^.attrs.sa.dtm := av^.attrs.sa.dtu;
      end;
      ast_attr_uid_84: begin
        av^.attrs.sa.uid_84 := value^.val.uid;
      end;
      ast_attr_uid_8c: begin
        av^.attrs.sa.uid_8c := value^.val.uid;
      end;
      ast_attr_owner1: begin
        av^.attrs.sa.pv.owner1 := value^.pv.owner1;
        av^.attrs.sa.pv.owner_ext[1] := value^.pv.owner_ext[1];
      end;
      ast_attr_owner2: begin
        av^.attrs.sa.pv.owner2 := value^.pv.owner2;
        av^.attrs.sa.pv.owner_ext[2] := value^.pv.owner_ext[2];
      end;
      ast_attr_owner3: begin
        av^.attrs.sa.pv.owner3 := value^.pv.owner3;
        av^.attrs.sa.pv.owner_ext[3] := value^.pv.owner_ext[3];
      end;
      ast_attr_linkcount: begin
        av^.attrs.sa.linkcount := value^.val.word_val;
      end;
      ast_attr_set_rights: begin
        av^.attrs.sa.pv.rights_w := value^.pv.rights_w;
        av^.attrs.sa.pv.tail.r5 := av^.attrs.sa.pv.r4;
      end;
      ast_attr_set_acl_image: begin
        needs_purify := true;
        old_acl_uid.uid := av^.attrs.sa.acl_uid;
        new_acl_uid.uid := value^.acl_uid;
        keep_6 := av^.attrs.sa.pv.tail.mode_6;
        keep_5 := av^.attrs.sa.pv.tail.mode_5;
        keep_4 := av^.attrs.sa.pv.tail.mode_4;
        av^.attrs.sa.pv := value^.pv;
        av^.attrs.sa.acl_uid := value^.acl_uid;
        av^.attrs.sa.pv.tail.mode_6 := keep_6;
        av^.attrs.sa.pv.tail.mode_5 := keep_5;
        av^.attrs.sa.pv.tail.mode_4 := keep_4;
      end;
      ast_attr_merge_acl: begin
        needs_purify := true;
        old_acl_uid.uid := av^.attrs.sa.acl_uid;
        new_acl_uid.uid := value^.acl_uid;

        { the owner }
        if value^.pv.owner1 <> uid_$nil then begin
          av^.attrs.sa.pv.owner1 := value^.pv.owner1;
          av^.attrs.sa.pv.owner_ext[1] := value^.pv.owner_ext[1];
        end;
        if not (5 in value^.pv.r1) then
          av^.attrs.sa.pv.r1 := value^.pv.r1;
        if av^.attrs.sa.pv.owner1 <> subject^.sids.user_sid then
          av^.attrs.sa.pv.r1 := av^.attrs.sa.pv.r1 - [5];

        { the group, and the subject's projects }
        if value^.pv.owner2 <> uid_$nil then begin
          av^.attrs.sa.pv.owner2 := value^.pv.owner2;
          av^.attrs.sa.pv.owner_ext[2] := value^.pv.owner_ext[2];
        end;
        if not (5 in value^.pv.r2) then
          av^.attrs.sa.pv.r2 := value^.pv.r2;
        if av^.attrs.sa.pv.owner2 <> subject^.sids.group_sid then begin
          for i := 1 to 8 do begin
            if subject^.proj_uids[i] = uid_$nil then
              exit;
            if av^.attrs.sa.pv.owner2 = subject^.proj_uids[i] then
              goto 50;
          end;
          av^.attrs.sa.pv.r2 := av^.attrs.sa.pv.r2 - [5];
        end;

        { the organization }
50:
        if value^.pv.owner3 <> uid_$nil then begin
          av^.attrs.sa.pv.owner3 := value^.pv.owner3;
          av^.attrs.sa.pv.owner_ext[3] := value^.pv.owner_ext[3];
        end;
        if not (5 in value^.pv.r3) then
          av^.attrs.sa.pv.r3 := value^.pv.r3;
        if av^.attrs.sa.pv.owner3 <> subject^.sids.org_sid then
          av^.attrs.sa.pv.r3 := av^.attrs.sa.pv.r3 - [5];

        if not (5 in value^.pv.r4) then
          av^.attrs.sa.pv.r4 := value^.pv.r4;
        av^.attrs.sa.pv.tail.r5 := value^.pv.tail.r5 - [4, 5];
        av^.attrs.sa.pv.tail.os_only := value^.pv.tail.os_only;
        av^.attrs.sa.acl_uid := value^.acl_uid;
      end;
      otherwise begin
        status_ret.all := status_$ast_incompatible_request;
        goto 40;
      end;
    end;

    av^.attrs.sa.dta := clock;

20:
    aote^.flags := aote^.flags + [5];
    if (attr_id in ast_$attr_timestamp_mask) and then
       not aote^.loc.remote then
      time_$abs_clock(av^.attrs.sa.dtv);

40:
    ml_$unlock(ml_$pmap_lock);

    if needs_purify and then not aote^.loc.remote then begin
      ast_$purify_aote(aote^, true, status_ret);
      ml_$unlock(ml_$ast_lock);
      if status_ret.all <> status_$ok then
        return;
      if new_acl_uid.b0 <> 0 then begin
        tmp.word_val := 1;
        ast_$set_attribute_internal(new_acl_uid.uid, ast_attr_add_refcount,
                                    addr(tmp), wait_flag, nil, clock,
                                    status_ret);
        if status_ret.all <> status_$ok then
          return;
      end;
      if old_acl_uid.b0 <> 0 then begin
        ast_$truncate(old_acl_uid.uid, 0, 3, truncate_out, status_ret);
        if status_ret.all = file_$object_not_found then
          status_ret.all := status_$ok;
      end;
    end
    else
      ml_$unlock(ml_$ast_lock);
  end;

begin
  clock := clock_in;

  if uid = uid_$nil then begin
    status_ret.all := ast_$validate_uid(uid, 16#30F01);
    return;
  end;

  is_special := (proc1_$type[proc1_$current] = 8) or
                (proc1_$type[proc1_$current] = 9);

  ml_$lock(ml_$ast_lock);
  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, status_ret,
                                        is_special);
    if aote = nil then
      goto 10;
  end
  else
    aote^.flags := aote^.flags + [6];

  if aote^.loc.remote then begin
    { a remote object }
    if attr_id in [6, 7, 11] then begin
      status_ret.all := file_$object_is_remote;
      goto 10;
    end;

    addr_info.uid := aote^.obj_loc_addr;
    len_adjust := odd(aote^.attr_flags);
    ast_$set_attr_dispatch;
    if status_ret.all <> status_$ok then
      return;
    if not wait_flag then
      return;

    if len_adjust and then (attr_id = ast_attr_set_refcount) then begin
      local_value.word_val := value^.val.word_val - 1;
      p := addr(local_value);
    end
    else
      p := value;
    rem_file_$set_attribute(addr_info.addr, uid, attr_id, p^.val,
                            status_ret);
    return;
  end;

  { a local object }
  if ast_$aote_view_ptr_t(aote)^.attrs.sa.pv.tail.os_only and then
     is_special then begin
    status_ret.all := status_$ast_only_local_access_allowed;
10:
    ml_$unlock(ml_$ast_lock);
  end
  else
    ast_$set_attr_dispatch;
end;
