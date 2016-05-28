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

      input.scan(LINES) do |indent, id, line, eol|
        if id
          process_directive(id.to_sym, line)
        else
          process_text(indent, line)
        end
      end
    end

    private

    # Whitespace
    WS   = %r{ [ \t]       }mx
    EOL  = %r{ \n | \r\n?+ }mx
    REST = %r{ [^\r\n]*+   }mx

    # Quotes
    RUBY  = %r{ ` (?: [^`]   | ``    )*+ `?+ }mx
    CHAR  = %r{ ' (?: [^'\\] | \\.?+ )*+ '?+ }mx
    STR   = %r{ " (?: [^"\\] | \\.?+ )*+ "?+ }mx
    QUOTE = %r{ #{RUBY} | #{CHAR} | #{STR} }mx

    # Identifiers
    ID = %r{ (?> \b (?!\d) [\w.$]++ ) }mx

    # Logical lines
    LINES = %r{
      \G (?!\z)
      (?<indent> #{WS}*+(?!\#) )
      (?:        @ (?<id>#{ID}?+) #{WS}++ )?+
      (?<line>   (?: [^ \t\r\n`'"#\\] | #{WS}++(?!\#) | #{QUOTE} | \\.?+ )*+ )
      (?:        #{WS}*+ \# #{REST} )?+
      (?<eol>    #{EOL} | \z )
    }mx

    def process_directive(id, args)
      case id
      when :''
        @out.puts '<>'
      when :def
        @out.puts '<def>'
      else
        raise "unrecognized preprocessor directive: '#{id}'"
      end
    end

    def process_text(*line)
       case @state
       when :asm
         @out.print line.inspect
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

