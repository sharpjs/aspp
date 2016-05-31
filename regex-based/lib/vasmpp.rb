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
# - Comment removal
#
#     # comment
#
# - Line continuation
#
#     this is  \        => this is all one line
#       all one line    
#
# - Inline Ruby code
#
#     `code`
#
# FUTURE FEATURES
#
# - 
#


module Vasmpp
  class Processor
    def process(input, output, name = "(stdin)", line = 1)
      pass2 = Pass2.new(output)
      pass1 = Pass1.new(pass2)
      pass1.process(input)
    end
  end

  private

  class Pass1
    def initialize(pass2)
      @pass2 = pass2
    end

    # Whitespace
    WS    = / [ \t]       /x
    EOL   = / \n | \r\n?+ /x

    # Quotes
    RUBY  = / ` (?: [^`]   | ``    )*+ `?+ /x
    CHAR  = / ' (?: [^'\\] | \\.?+ )*+ '?+ /x
    STR   = / " (?: [^"\\] | \\.?+ )*+ "?+ /x
    QUOTE = / #{RUBY} | #{CHAR} | #{STR}   /x

    # Tokens for pass 1
    TOKENS = %r{
      \G (?!\z)
      (?<ws>  #{WS}*+ )
      (?<tok> [^`'"# \t\r\n\\]++
            | #{QUOTE}
            | \\ (?: #{EOL} #{WS}*+ )?+
            | (?: \# [^\r\n]*+ )?+ (?: #{EOL} | \z )
      )
    }x

    HANDLERS = {
      nil => :on_eol,
      ?\r => :on_eol,
      ?\n => :on_eol,
      ?\# => :on_eol,
      ?\` => :on_ruby,
      ?\' => :on_string,
      ?\" => :on_string,
      ?\\ => :on_backslash,
    }

    def process(input)
      @line   = ''.dup   # line text
      @index  = 1        # line number
      @height = 1        # count of raw lines in this logical line

      input.scan(TOKENS) do |ws, tok|
        send(HANDLERS[tok[0]] || :on_other, ws, tok)
      end
    end

    def on_eol(ws, tok)
      @pass2.process(@index, @line)
      @line   = ''.dup
      @index += @height
      @height = 1
    end

    def on_backslash(ws, tok)
        if tok.length == 1
          @line << tok
        else
          @line << " "
          @height += 1
        end
    end

    def on_ruby(ws, tok)
      ruby = tok[1..-2].gsub('``', '`')
      @line << ws << eval(ruby).to_s
    end

    def on_string(ws, tok)
      @line << ws << tok.gsub(EOL) do |n|
        @height += 1
        n.inspect[1..-2]
      end
    end

    def on_other(ws, tok)
      @line << ws << tok
    end
  end

  class Pass2
    def initialize(output)
      @output = output
    end

    def process(index, line)
      $stderr.puts "#{index}: |#{line}|"
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

