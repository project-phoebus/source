{ rgyc/rgyc.ins.pas - RGYC_ (the registry client), for the Domain Pascal
  tree.

  Only what the Pascal files use: four well-known UIDs, each a map
  symbol in the UID_LIST segment (the table of well-known UIDs, another
  unit's data), reached by its absolute address.  Include
  base/base.ins.pas before it.
}

var
  { RGYC_$G_LOCKSMITH_UID (map symbol, at one address with
    ACL_$LOCKSMITH_UID and RGYC_$P_ROOT_UID): a UID.  PACCT_$START and
    PACCT_$STOP compare SIDs with it. }
  rgyc_$g_locksmith_uid: extern uid_$t;

{ }

var
  { RGYC_$G_LOGIN_UID (map symbol, at one address with ACL_$LOGIN_UID):
    a UID.  AUDIT_$CONTROL compares the caller's login SID with it. }
  rgyc_$g_login_uid: extern uid_$t;

{ }

var
  { RGYC_$G_NIL_UID (map symbol, at one address with
    PPO_$NIL_PROJ_UID): a UID.  VTOCE_$OLD_TO_NEW copies it into a new
    VTOCE's group UID. }
  rgyc_$g_nil_uid: extern uid_$t;

{ }

var
  { RGYC_$P_USER_UID (map symbol, at one address with PPO_$USER_UID): a
    UID.  acl_$eval_rights (module-local in ACL) puts it into its local
    SID block's person for a downgraded local locksmith. }
  rgyc_$p_user_uid: extern uid_$t;
