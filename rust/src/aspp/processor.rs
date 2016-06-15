// This file is part of aspp, a preprocessor for GNU Assembler.
// Copyright (C) 2016 Jeffrey Sharp
//
// aspp is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// aspp is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
// the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with aspp.  If not, see <http://www.gnu.org/licenses/>.

use aspp::output::Output;
use self::State::*;
use self::Action::*;

// -----------------------------------------------------------------------------
// Processor

pub fn process(input: &str, output: &mut Output) {
    let mut chars      = input.chars();
    let mut next_char  = chars.next();
    let mut state      = Initial;
    let mut prev_state = Initial;
    let mut start      = 0; // byte index of current token
    let mut end        = 0; // byte index after current token

    loop  {
        // Look up transition for this state and character
        let table = &STATES[state as usize];
        let (c, (next_state, action)) = lookup(table, next_char);

        // Advance to next state
        state = next_state;
        end  += 1;

        // Action helpers
        macro_rules! consume {
            () => {{ next_char = chars.next() }};
        }
        macro_rules! push {
            ( $s:expr ) => {{ prev_state = state; state = $s }};
        }
        macro_rules! pop {
            () => {{ state = prev_state }};
        }
        macro_rules! start_str {
            () => {{ start = end }};
        }
        macro_rules! yield_str {
            () => {{ let s = &input[start..end]; start = end; s }};
        }

        // Invoke action
        match action {
            Go      => { consume!() },
            EndLine => { consume!(); output.write_raw_str(yield_str!()) },
            Return  => { return },
        }
    }
}

// -----------------------------------------------------------------------------
// States

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u8)]
enum State {
    Initial,
    Other,
    AtEof
}

// -----------------------------------------------------------------------------
// Action Codes

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u8)]
enum Action {
    Go,
    EndLine,
    Return
}

// -----------------------------------------------------------------------------
// Transition Table

type TransitionSet = (
    [u8; 128],          // Map from 7-bit char to transition index
    &'static [(         // Array of transitions:
        State,          //   - next state
        Action          //   - custom action
    )]
);

#[inline]
fn lookup(entry: &TransitionSet, ch: Option<char>) -> (char, (State, Action))
{
    // Lookup A: char -> transition index
    let (n, c) = match ch {
        Some(c) => {
            let n = c as usize;
            if n & 0x7F == n {
                (entry.0[n] as usize, c)    // U+007F and below => table lookup
            } else {
                (1, c)                      // U+0080 and above => 'other'
            }
        },
        None => (0, '\0')                   // EOF
    };

    // Lookup B: transition index -> transition
    (c, entry.1[n])
}


// Alias for 'other'; for readability of tables only.
#[allow(non_upper_case_globals)]
const x: u8 = 1;

const STATES: &'static [TransitionSet] = &[
    // Initial
    ([
        x, x, x, x, x, x, x, x,  x, 2, 3, x, x, 2, x, x, // ........ .tn..r..
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // ........ ........
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, //  !"#$%&' ()*+,-./
        x, x, x, x, x, x, x, x,  x, x, x, 4, x, x, x, x, // 01234567 89:;<=>?
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // @ABCDEFG HIJKLMNO
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // PQRSTUVW XYZ[\]^_
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // `abcdefg hijklmno
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // pqrstuvw xyz{|}~. <- DEL
    ],&[
        //             State     Action
        /* 0: eof */ ( AtEof,    Return  ),
        /* 1: ??? */ ( Other,    Go      ),
        /* 2: \s  */ ( Initial,  Go      ),
        /* 3: \n  */ ( Initial,  EndLine ),
        /* 4:  ;  */ ( Initial,  Go      ),
    ]),

    // Other
    ([
        x, x, x, x, x, x, x, x,  x, x, 2, x, x, x, x, x, // ........ .tn..r..
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // ........ ........
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, //  !"#$%&' ()*+,-./
        x, x, x, x, x, x, x, x,  x, x, x, 3, x, x, x, x, // 01234567 89:;<=>?
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // @ABCDEFG HIJKLMNO
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // PQRSTUVW XYZ[\]^_
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // `abcdefg hijklmno
        x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // pqrstuvw xyz{|}~. <- DEL
    ],&[
        //             State     Action
        /* 0: eof */ ( AtEof,    Return  ),
        /* 1: ??? */ ( Other,    Go      ),
        /* 2: \n  */ ( Initial,  EndLine ),
        /* 3:  ;  */ ( Initial,  Go      ),
    ]),

//  // State: state description
//  ([
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // ........ .tn..r..
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // ........ ........
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, //  !"#$%&' ()*+,-./
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // 01234567 89:;<=>?
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // @ABCDEFG HIJKLMNO
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // PQRSTUVW XYZ[\]^_
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // `abcdefg hijklmno
//      x, x, x, x, x, x, x, x,  x, x, x, x, x, x, x, x, // pqrstuvw xyz{|}~. <- DEL
//  ],&[
//      //             State  Action
//      /* 0: eof */ ( AtEof, Skip ),
//      /* 1: ??? */ ( AtEof, Skip ),
//  ]),

    // AtEof: at end of file
    ([
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // ........ .tn..r..
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // ........ ........
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, //  !"#$%&' ()*+,-./
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // 01234567 89:;<=>?
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // @ABCDEFG HIJKLMNO
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // PQRSTUVW XYZ[\]^_
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // `abcdefg hijklmno
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, // pqrstuvw xyz{|}~. <- DEL
    ],&[
        //             State  Action
        /* 0: eof */ ( AtEof, Return ),
    ]),
];

