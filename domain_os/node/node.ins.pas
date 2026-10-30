{ node/node.ins.pas - NODE_ (this node's identity), for the Domain Pascal
  tree.

  Include base/base.ins.pas before it.
}

var
  { NODE_$ME (map symbol, MARKED, in the hand-written NET_ASM data
    segment of WIRED_DATA, 0xC bytes): this node's ID, a linteger (it is
    merged unmasked into a 20-bit packed field). }
  node_$me: extern linteger;
