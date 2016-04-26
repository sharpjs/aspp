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
# - Scopes with local labels
#
#     foo:          #define scope foo
#     {             .fn scope
#
#     bar:          L$bar:      (bar is local to scope foo)
#       jmp bar     jmp L$bar
#
#     }             .endfn
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
# - Square brackets for indirect addressing
#
#     [a0, 42]      (a0, 42)
#     [-a0]         -(a0)
#     [a0+]         (a0)+
#
# - Automatic immediate-mode prefix
#
#     foo  4, d0     foo  #4, d0
#     foo$ 4, d0     foo$ 4, d0   ($ for custom macros; no # added)
#     .foo 4, d0     .foo 4, d0   (. for pseudo-ops;    no # added)
#
# FUTURE FEATURES
#
# - Nested scopes
#
# - Transform character literals
#
#     'a'           'a
#
# - Allow function declaration at BOF.
#     Right now, seems like a Ruby regex bug?
#     (?:\A|\n) doesn't work
#

module Raspp
  class Processor
    def initialize
      @handlers = collect_handlers
    end

    def process(input, file = "(stdin)", line = 1)
      @input    = input
      @file     = file
      @line     = line
      @scope    = Scope.new(nil)
      @delims   = []

      input.scan(TOKENS) do
        #p $~
        @handlers[$&[0]].call($~)
      end
    end

    private

    # Identifiers
    ID = %r{ (?!\d) [\w.$]++ }x

    # Tokens - chunks of text to transform or ignore
    TOKENS = %r{ \G
      (?: \n                                    # end of line
          (?: (?<scope>#{ID}): \n\{ (?=\n)      # ...scope begin
            | (?<scope>     )  \}\n (?=\n)      # ...scope end
          )?+
        | (?<id>#{ID}) (?: @ (?<def>#{ID}) )?+  # identifier or alias def
        | [@$] (?<id>#{ID})                     # argument or variable
        | \d \w*+                               # number
        | \[ (?<inc>[-+])?+                     # effective address begin
        |    (?<inc>[-+])?  \]                  # effective address end
        | [(){}]                                # delimiter begin/end
        | ,                                     # comma
        | (?: [ \t] | \\\n )++                  # whitespace
        | // [^\n]*+                            # ignored: comment
        | (?: [^ \t\w\n@$.\[\]\-+/\\"]          # ignored: misc
            | [@$] (?=\d|[^\w.$]|\z)            # ignored: bare sigils
            | [-+] (?!\])                       # ignored: bare -/+
            | /  (?!/)                          # ignored: bare slashes
            | \\ (?!\n)                         # ignored: bare backslashes
            | " (?: [^\\"] | \\.?+ )*+ "?+      # ignored: string literal (")
          )++
      )
    }mx

    LABELS = %r{ ^(#{ID}): | ^\}\n }x

    # Identify mnemonics that are pseudo-ops, not instructions.
    PSEUDO = %r{ ^\. | \$ }x

    # Registers and other recognized identifiers
    SPECIAL_IDS = %w[
      a0 a1 a2 a3 a4 a5 a6 a7 fp sp
      d0 d1 d2 d3 d4 d5 d6 d7
      pc sr ccr bc
      vbr cacr acr0 acr1 mbar rambar
    ]
    .reduce({}) { |h, id| h[id] = true; h }

    def collect_handlers
      handlers = Hash.new(method(:on_other))
      {
        #Name   Starting Characters
        on_ws:  [ ?\s, ?\t, ?\\ ],
        on_id:  [ *?a..?z, *?A..?Z, ?_, ?., ?$ ],
        on_num: [ *?0..?9 ],
        on_arg: [ ?@  ],
        on_var: [ ?$  ],
        on_boa: [ ?[  ],
        on_eoa: [ ?], ?+, ?- ],
        on_bop: [ ?(  ],
        on_eop: [ ?)  ],
        on_bob: [ ?{  ],
        on_eob: [ ?}  ],
        on_sep: [ ?,  ],
        on_eol: [ ?\n ],
      }
      .each do |name, chars|
        chars.each { |c| handlers[c] = method(name) }
      end
      handlers
    end

    def on_ws(match)
      print match[0]
    end

    def on_id(match)
      id   = match[:id]
      deƒ  = match[:def]
      used = nil

      unless @state
        # Instruction/directive mnemonic
        @state = PSEUDO =~ id ? :other : :at_operand
        print match[0]
        return
      end

      if deƒ
        @scope.aliases[id] = "_(#{id})#{deƒ}"
        id = deƒ
        used = { id => true }
      end

      while (deƒ = @scope.aliases[id])
        id = deƒ
        (used ||= {})[id] = true
      end

      if (deƒ = @scope.labels[id])
        id = deƒ
        (used ||= {})[id] = true
      end

      in_operand !SPECIAL_IDS[id]
      print id
    end

    def on_num(match)
      in_operand true
      print match[0]
    end

    def on_arg(match)
      in_operand
      print "ARG(#{match[:id]})"
    end

    def on_var(match)
      in_operand
      print "VAR(#{match[:id]})"
    end

    def on_sep(match)
      next_operand
      print match[0]
    end

    def on_eol(match)
      @state = nil
      @delims.clear
      puts
      scope = match[:scope] or return
      if scope.empty?
        pop_scope
      else
        push_scope scope
        scan_labels match.post_match
      end
    end

    def on_boa(match)
      in_operand
      push_delim '['
      print "#{match[:inc]}("
    end

    def on_eoa(match)
      unless match[0].end_with?(']')
        return on_other(match)
      end
      in_operand
      pop_delim '['
      print ")#{match[:inc]}"
    end

    def on_bop(match)
      in_operand true
      push_delim '('
      print '('
    end

    def on_eop(match)
      in_operand
      pop_delim '('
      print ')'
    end

    def on_bob(match)
      in_operand true
      push_delim '{'
      print '{'
    end

    def on_eob(match)
      in_operand
      pop_delim '{'
      print '}'
    end

    def on_other(match)
      in_operand
      print match[0]
    end

    def push_scope(name)
      @scope = @scope.subscope(name)
      print "#define scope #{name}\n.fn scope;"
    end

    def pop_scope
      print "#undef scope\n.endfn\n"
      @scope = @scope.parent unless @scope.root?
    end

    def scan_labels(text)
      text.scan(LABELS) do
        id = $1 or break
        @scope.labels[id] = "L$#{id}"
      end
    end

    # Delimiter Tracking

    def push_delim(s)
      @delims.push s if s
    end

    def pop_delim(s)
      @delims.pop if @delims.first == s
    end

    def in_delim?
      !@delims.empty?
    end

    # Immediate Prefix Insertion

    def in_operand(immediate = false)
      if (@state ||= :other) == :at_operand
        print '#' if immediate
        @state = :in_operand
      end
    end

    def next_operand
      if (@state ||= :other) == :in_operand && !in_delim?
        @state = :at_operand
      end
    end
  end # Processor

  class Scope
    attr_reader :name, :parent, :labels, :aliases

    def initialize(name, parent = nil)
      @name    = name
      @parent  = parent
      @labels  = ManyToOneLookup.new(parent&.labels )
      @aliases =  OneToOneLookup.new(parent&.aliases)
    end

    def subscope(name)
      Scope.new(name, self)
    end

    def root?
      parent.nil?
    end
  end

  class ManyToOneLookup
    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @k2v    = {}
    end

    def [](key)
      @k2v[key] or @parent&.[](key)
    end

    def []=(key, val)
      @k2v[key] = val
    end
  end

  class OneToOneLookup
    attr_reader :parent

    def initialize(name, parent = nil)
      @parent = parent
      @k2v    = {}
      @v2k    = {}
    end

    def [](key)
      @k2v[key] or @parent&.[](key)
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end
end # Raspp

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

