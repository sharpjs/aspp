#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# vasmpp - A Preprocessor for VASM
# Copyright (C) 2016 Jeffrey Sharp
#
# vasmpp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# vasmpp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with vasmpp.  If not, see <http://www.gnu.org/licenses/>.
#
# IMPLEMENTED FEATURES
#
# (none)
#
# FUTURE FEATURES:
#
# - Inline aliases
# ?
#

module Vasmpp
  class Processor
    def process(input, output, name = "(stdin)", line = 1)
      @in    = input
      @out   = output
      @name  = name
      @line  = line
      @state = :asm

      input.each_line { |line| process_line line }
    end

    private

    def process_line(line)
      case @state
      when :asm
        @out.print line
      end
    end
  end
end # Vasmpp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Vasmpp::Processor.new
  loop do
    processor.process(ARGF.file.read, $stdout, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

