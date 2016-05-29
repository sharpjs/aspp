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
      @state = :asm

      each_logical_line(input) do |index, text|
        $stderr.puts "#{index}: |#{text}|"
      end
    end

    private

    # Whitespace
    WS    = /[ \t]/

    # Quotes
    RUBY  = / ` (?: [^`]   | ``    )*+ `?+ /x
    CHAR  = / ' (?: [^'\\] | \\.?+ )*+ '?+ /x
    STR   = / " (?: [^"\\] | \\.?+ )*+ "?+ /x
    QUOTE = / #{RUBY} | #{CHAR} | #{STR}   /x

    # Line for pass 1
    LINE = %r{
      \A
      (?<indent> (?: #{WS}*+ (?!\#) )?+ )
      (?<text>   (?: [^`'"# \t\r\n\\]
                   | #{WS}++ (?!\#)
                   | #{QUOTE}
                   | \\ (?!\z)
                 )*+
      )
      (?: (?<con> \\ )
        | (?<com> #{WS}*+ \# .*+ )
      )?+
      \z
    }x

    def each_logical_line(input)
      index  = 1    # line number
      height = 1    # count of raw lines in this logical line
      prior  = nil  # continued prior logical line, if any

      input.each_line do |text|
        # Remove trailing EOL
        text.chomp!

        $stderr.puts text.inspect

        # Find 
        m = LINE.match(text)

        # Apply prior line continuation
        text = prior ? prior << m[:text] : m[:indent] + m[:text]

        # Check for line continuation
        if m[:con]
          height += 1
          prior   = text
          next
        end

        # Pass to next stage
        yield index, text

        # Advance position
        index += height
        height = 1
        prior  = nil
      end
    end

    #def process_directive(id, args)
    #  case id
    #  when :''
    #    @out.puts '<>'
    #  when :def
    #    @out.puts '<def>'
    #  else
    #    raise "unrecognized preprocessor directive: '#{id}'"
    #  end
    #end

    #def process_text(*line)
    #   case @state
    #   when :asm
    #     @out.print line.inspect
    #   end
    #end
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

