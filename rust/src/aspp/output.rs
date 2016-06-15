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

use std::fmt::{self, Write};

pub struct Output {
    text: String,
    name: String,
    line: usize,
    bol:  bool,
}

impl Output {
    pub fn with_capacity(name: String, cap: usize) -> Self {
        Output {
            text: String::with_capacity(cap),
            name: name,
            line: 1,
            bol:  true,
        }
    }

    #[inline]
    pub fn as_str(&self) -> &str {
        self.text.as_str()
    }

    #[inline]
    pub fn advance_line(&mut self) {
        self.line += 1
    }

    #[inline]
    pub fn write_raw_char(&mut self, c: char) {
        self.text.push(c)
    }

    #[inline]
    pub fn write_raw_str(&mut self, s: &str) {
        self.text.push_str(s)
    }

    pub fn write_local_symbol(&mut self, name: &str) {
        write!(self.text, "L({})", name).unwrap()
    }

    pub fn write_local_label(&mut self, name: &str) {
        write!(self.text, "L({}):", name).unwrap()
    }

    pub fn label(&mut self, name: &str) {
        write!(self.text,
               "\n\
                ; SCOPE: {2}\n\
                #ifdef scope\n\
                #undef scope\n\
                #endif\n\
                #define scope {0}\n\
                \n\
                # {0} \"{1}\"\n\
                .label scope;",
               self.line, self.name, name
              ).unwrap()
    }

    pub fn global(&mut self) {
        write!(self.text,
               "\n\
                # {0} \"{1}\"\n\
                .global scope;",
               self.line, self.name
              ).unwrap()
    }
}

impl Write for Output {
    #[inline(always)]
    fn write_str(&mut self, s: &str) -> Result<(), fmt::Error> {
        self.text.write_str(s)
    }

    #[inline(always)]
    fn write_char(&mut self, c: char) -> Result<(), fmt::Error> {
        self.text.write_char(c)
    }

    #[inline(always)]
    fn write_fmt(&mut self, args: fmt::Arguments) -> Result<(), fmt::Error> {
        self.text.write_fmt(args)
    }
}

