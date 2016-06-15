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

#![allow(dead_code)]
#![allow(unused_variables)]

mod aspp;

use std::io::{self, Read};
use aspp::processor;

fn main() {
    let mut input = String::with_capacity(4096);

    match io::stdin().read_to_string(&mut input) {
        Ok  (_) => (),
        Err (e) => panic!("error reading stdin: {}", e)
    }

//    processor::process(input.chars());
}

