#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# raspp - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with raspp.  If not, see <http://www.gnu.org/licenses/>.
#
# IMPLEMENTED FEATURES
#
# - none
#
# FUTURE FEATURES
#
# - Scopes with local labels
#
#     foo:          #define SCOPE foo
#     {             .push_scope SCOPE; foo:
#
#     bar:          L(bar):     (bar is local to scope foo)
#       jmp bar     jmp L(bar)
#
#     }             .pop_scope
#
# - Inline unique aliases
#
#     foo@a0        _(foo)a0
#     foo           _(foo)a0
#     bar@a0        _(bar)a0  (this undefines foo)
#     foo           *ERROR*
#
# - Sigils for arguments and local variables
#
#     @foo          ARG(foo)
#     $bar          VAR(bar)
#
# - Transform character literals
#
#     'a'           'a
#

module Raspp
  class Processor
    def process(input, file = "(stdin)", line = 1)
      @file     = file
      @line     = line
      @handlers = handlers

      input.scan(TOKENS) do
        @handlers[$&[0]].call($~)
        #$stderr.puts "#{$&.inspect} -> #{$'[0].inspect}"
      end
    end

    private

    ID = %r{ (?> (?!\d) [\w.$]++ ) }mx

    TOKENS = %r{ \G
      (?: [@$] (?<id>#{ID})                           # argument or variable
      |   (?<id>#{ID}) (?: @(?<def>#{ID}) )?+         # aliasable identifier
      |   (?:\n|\A)                                   # newline, then:
          (?<indent>[ \t]*+)
          (?<bol>
            (?<id>#{ID}) (?<lbl>: (?<bos>\n\{(?=\n))?+ )?+          # - label, start of scope
          | \}\n                                    # - end of scope
          | \# .*+                                  # - CPP directive
          )?+
      |   (?: [^\w\n@$./]                             # ignored, including:
          |   \d \w*+                                 # - numbers
          |   [@$] (?=\d|[^\w.$]|\z)                  # - bare sigils
          |   / (?!/)                                 # - bare slashes
          |   \\\n                                    # - escaped newlines
          )++
      |   // .*+                                      # comment
      )
    }x

    def handlers
      handlers = Hash.new(method(:on_other))
      {
        #Name   Starting Characters
        on_id:  [*?a..?z, *?A..?Z, ?_, ?., ?$],
        on_arg: [?@],
        on_var: [?$],
        on_eol: [?\n],
      }
      .each do |name, chars|
        chars.each { |c| handlers[c] = method(name) }
      end
      handlers
    end

    def on_id(match)
      id   = match[:id]
      def_ = match[:def]

      if def_
        # add to aliases here
        id = def_
      else
        # lookup alias here
      end

      print "L(#{id})"
    end

    def on_arg(match)
      print "ARG(#{match[:id]})"
    end

    def on_var(match)
      print "VAR(#{match[:id]})"
    end

    def on_eol(match)
      puts
      bol = match[:bol] or return
      
      case bol[0]
      when '#'
        print bol
      when '}'
        puts ".pop_scope", "#undef SCOPE"
      else
        print match[:indent]
        id = match[:id]
        if match[:bos]
          print "#define SCOPE #{id}\n.push_scope SCOPE; SCOPE:"
        elsif match[:lbl]
          print "L(#{id}):"
        else
          print id
        end
      end
    end

    def on_other(match)
      print match[0]
    end

  end # class Processor
end # module Raspp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Raspp::Processor.new
  loop do
    processor.process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

