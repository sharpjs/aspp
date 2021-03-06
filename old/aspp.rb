#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# aspp - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# aspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# aspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with aspp.  If not, see <http://www.gnu.org/licenses/>.
#
# FEATURES
#
# Label processing
# - Local scopes between non-local labels
# - Global labels indicated by extra : suffix
# - Invoke macro for each label
#
#     foo:              #ifdef scope
#     foo::             #undef scope
#                       #endif
#                       #define scope foo
#                       # 42 "file.s"
#                       .label scope;
#                       .global scope     // if :: was used
#                       # 42 "file.s"
#
# Local symbols
#
#     .foo              L(foo)
#
# Local aliases
#
#     foo@a0            _(foo)a0
#     foo               _(foo)a0
#     bar@a0            _(bar)a0            // undefines foo
#
# Square brackets for indirect addressing
#
#     [a0, 42]          (a0, 42)
#
# Immediate-mode prefix removal for certain macros
#
#     cmp$.l #4, d0     cmp$.l _(#)4, d0
#
# Assembler macros
#
#     .macro .label name:req              // default .macro label
#       \name\():
#     .endm
#
# C preprocessor macros
#
#     #define _(x)                        // inline comment
#     #define SCOPE(name) .L$name         // reference to scope
#     #define L           .L$scope$name   // reference to local symbol
#

require 'strscan'

module Aspp
  class Processor
    def initialize
      @aliases = Aliases.new
    end

    def process(input, name = "(stdin)", line = 1)
      @input  = StringScanner.new(input)
      @name   = name  # input file name 
      @line   = line  # input line number
      @height = 0     # input line height (i.e. count of embedded newlines)
      @aliases.clear  # identifier alias mappings

      print Aspp::preamble(name)

      until @input.eos?
        # Scan one logical line
        if op = scan_labels_and_op
          scan_operands op
        else
          scan_other
        end

        # Advance to next line
        @line  += @height
        @height = 0
      end
    end

    private

    def scan_labels_and_op
      while scan(LABEL_OR_OP)
        # Get captures
        ws  = @input[1] # leading whitespace
        id  = @input[2] # identifier
        lbl = @input[3] # label sigil - ':' or '::'

        # First id without ':' is the op mnemonic
        unless lbl
          print ws, id
          return id
        end

        # Transform label
        if local?(id)
          label localize(id)
        else
          start_scope id
          id = :scope
          @aliases.clear
        end

        # Export label
        export id if global?(lbl)

        sync if @height != 0
      end
    end

    def scan_operands(op)
      pseudo = pseudo?(op)

      while tok = @input.scan(OPERAND_TOKEN)
        case tok[0]
        when "["  then print "("
        when "]"  then print ")"
        when "#"  then print pseudo ? "_(#)" : "#"
        when "\n" then puts; return
        else
          if id = @input[:id]
            # identifier
            print idref(id, @input[:as])
          else
            # ignored
            print tok
          end
        end
      end
    end

    def scan_other
      print scan(REST_OF_LINE)
    end

    def scan(re)
      @input.scan(re).tap do |text|
        @height += text.count("\n") if text
      end
    end

    def local?(id)
      id.start_with?(".")
    end

    def localize(id)
      "L(#{id[1..-1]})"
    end

    def global?(sigil)
      sigil == "::"
    end

    def pseudo?(id)
      id.start_with?(".") || id.include?("$")
    end

    def start_scope(id)
      print <<~EOS
        #ifdef scope
        #undef scope
        #endif
        #define scope #{id}
        # #{@line} "#{@name}"
        .label scope
        # #{@line} "#{@name}"
      EOS
    end

    def label(id)
      print "#{id}:"
    end

    def export(id)
      puts ".global #{id}"
    end

    def idref(id, as)
      if as
        @aliases[id] = as
      else
        as = @aliases[id]
      end

      m = as || id
      m = localize(m) if local?(m)

      as ? "_(#{id})#{m}" : m
    end

    def sync
        puts %{# #{@line} "#{@name}"}
    end

    WS  = %r{ (?: [ \t] | \\\n )*+ }x
    ID  = %r{ (?!\d) [\w.$]++ }x
    STR = %r{ " (?: [^\\"] | \\.?+ )*+ "?+ }x

    REST_OF_LINE = %r{ .*+ \n?+ }x

    LABEL_OR_OP = %r{ (#{WS}) (#{ID}) (::?+)?+ }x

    OPERAND_TOKEN = %r{
        # ignored
        (?: \d (?: [\w.]  | [Ee][+-]    )*+
          | "  (?: [^\\"] | \\ (?m:.?+) )*+ "?+
          | /  (?: /  .*+
                 | \* (?m:.*?) (?:\*/|\z)
               )?+
          | \\ \n?+
          | [^\w.$#\[\]\n]
        )++
      |
        # identifier
        (?<id>#{ID}) (?: #{WS} @ #{WS} (?<as>#{ID}) )?+
      |
        # special char
        .
    }x
  end # Processor

  def self.preamble(name)
    <<~EOS
      # 1 "(asmpp-preamble)"
      .macro .label name:req              // default label behavior
        \\name\\():
      .endm
      #define _(x)                        // inline comment
      #define SCOPE(name) .L$name         // reference to scope
      #define L           .L$scope$name   // reference to local symbol

      # 1 "#{name}"
    EOS
  end

  class Aliases
    def initialize
      @k2v = {}
      @v2k = {}
    end

    def clear
      @k2v.clear
      @v2k.clear
    end

    def [](key)
      @k2v[key]
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end
end # Aspp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Aspp::Processor.new
  loop do
    processor.process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

