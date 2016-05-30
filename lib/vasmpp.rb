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
    WS    = / [ \t]       /x
    EOL   = / \n | \r\n?+ /x

    # Quotes
    RUBY  = / ` (?: [^`]   | ``    )*+ `?+ /x
    CHAR  = / ' (?: [^'\\] | \\.?+ )*+ '?+ /x
    STR   = / " (?: [^"\\] | \\.?+ )*+ "?+ /x
    QUOTE = / #{RUBY} | #{CHAR} | #{STR}   /x

    # Tokens for pass 1
    PASS1 = %r{
      \G (?!\z)
      (?<ws>  #{WS}*+ )
      (?<tok> [^`'"# \t\r\n\\]++
            | #{QUOTE}
            | \\ (?: #{EOL} #{WS}*+ )?+
            | (?: \# [^\r\n]*+ )?+ (?: #{EOL} | \z )
      )
    }x

    PASS1_HANDLERS = {
      nil => :pass1_eol,
      ?\r => :pass1_eol,
      ?\n => :pass1_eol,
      ?\\ => :pass1_backslash,
    }

    def each_logical_line(input)
      @line   = ''.dup   # line text
      @index  = 1        # line number
      @height = 1        # count of raw lines in this logical line

      input.scan(PASS1) do |ws, tok|
        send(PASS1_HANDLERS[tok[0]] || :pass1_other, ws, tok)
      end
    end

    def pass1_eol(ws, tok)
      pass2
      @line   = ''.dup
      @index += @height
      @height = 1
    end

    def pass1_backslash(ws, tok)
        if tok.length == 1
          @line << tok
        else
          @line << " "
          @height += 1
        end
    end

    def pass1_other(ws, tok)
      @line << ws << tok
    end

    def pass2
      $stderr.puts "#{@index}: |#{@line}|"
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

