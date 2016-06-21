// ------------------------------------------------------------------------------
// strlen
//
// Computes the length of a string.
//
// .str      &byte       Address of the string.
// ->        long        Length of the string.

strlen:: {
        .arg.b      str
        .enter

        movea.l     arg(@str), beg = a0      // load args
        movea.l     beg,       end = a1

  .each_c: {
        tst.b       [end]+                  // find zero byte
        bnz.s       .each_c
  }

        move.l      end, len = d0           // return length
        sub.l       beg, len
        sub$.l      #1,  len

        .leave
        rts
}

// vim: ft=asmcf

