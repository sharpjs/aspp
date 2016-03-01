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
# - ; comments
# - line continuation
# - Inline macros
# - Inline macro definitions
# - Statement macros
# - Scoped macros
#
# FUTURE FEATURES
#
# - Replace [ ] with ()
# - Replace ++/-- with +/-
#
# - Scoped identifiers  (not needed for vasm)
# - Replace 'a' with 'a (not needed for vasm)
# - Add # to numbers    (unsure if a good idea)
# - Inline ruby code    (unsure if a good idea)
#

module Raspp
  def self.process(input, file = "(stdin)")
    Preprocessor.new(file).process(input)
  end

  private

  WS = '[ \t]'
  ID = '(?> \b (?!\d) [\w.$]++ )'

  EOL    = / \n | \r\n?+ /mx
  INDENT = / \A #{WS}*+  /mx

  # Quotes
  BQ    = %r{ ` (?: [^`]           )*+ `?+ }mx
  SQ    = %r{ ' (?: [^'\\] | \\.?+ )*+ '?+ }mx
  DQ    = %r{ " (?: [^"\\] | \\.?+ )*+ "?+ }mx
  QUOTE = %r{ #{SQ} | #{DQ} | #{BQ} }mx

  # Logical lines (after contiunation and comment removal)
  LINES = %r{
    \G (?!\z)
    (?<text> (?: [^ \t\r\n`'";] | #{WS}++(?!;) | #{QUOTE} )*+ )
    (?:      #{WS}*+ ; [^\r\n]*+ )?+
    (?<eol>  #{EOL} | \z )
  }mx

  # Code with balanced punctuators
  CODE = %r{
    (?<code>
      [^\[\]\(\)\{\}`'",]    |
      #{QUOTE}               |
      \[ (?:,|\g<code>)*+ \] |
      \( (?:,|\g<code>)*+ \) |
      \{ (?:,|\g<code>)*+ \}
    )
  }mx

  # Macro arguments
  ARGS = %r{
    (?<=\A|,) #{CODE}*+
  }mx

  IDS = %r{
    (?<id>#{ID})
  | 
    #{QUOTE} (?# excluded #)
  }mx

  # Function-like macro invocation
  INLINE = %r{
    (?<name>#{ID})
    (?:
      \( (?<args>(?:,|#{CODE})*+) \)
    |
      (?>#{WS}*=>#{WS}*) (?<body>#{ID})
    )?+
  | 
    #{QUOTE} (?# excluded #)
  }mx

  # Statement-like macro invocation
  STMT = %r{
    (?<indent> #{INDENT} )
    (?<labels> (?: #{ID}: #{WS}*+ )*+ )
    (?<name>   #{ID} )
    (?:
      #{WS}++
      (?<args> (?:,|#{CODE})++ )
    )?+
    \z (?# eol #)
  }mx

  # Statement labels
  LABEL_SEP = /:#{WS}*+/

  SCOPE_BEGIN = %r{ #{INDENT} (?!\.) (?<name>#{ID}) : }x

  # Effective address brackets
  BRACKETS = %r{
    (?<tok>\[) (?: (?<auto>[-+]) \k<auto> )?+
  |
    (?: (?<auto>[-+]) \k<auto> )?+ (?<tok>\])
  }x

  class Preprocessor
    def initialize(file)
      @file, @scope = file, Scope.new_root
    end

    def process(input)
      each_line(input) do |n, line|
        puts "#{n}: |#{expand!(line)}|"
      end
    end

    # Scan logical lines & handle errors
    def each_line(input)
      index  = 1    # line number
      height = 1    # count of raw lines in this logical line
      prior  = nil  # continued prior line, if any

      input.scan(LINES) do |text, eol|
        # Count raw lines
        text.scan(EOL) { height += 1 }

        # Apply prior line continuation
        if prior
          text.sub!(INDENT, '')
          text = prior << text
        end

        # Check for line continuation
        if text.chomp!('\\')
          prior = text
          next
        end

        # Pass to next stage
        yield index, text

        # Advance position
        index += height
        height = 1
        prior  = nil
      end

      # Handle continued line at EOF: pass to next stage
      yield index, prior if prior

    rescue PreprocessorError
      $stderr.puts "#{@file}:#{index}: error: #{$!}"
      exit 1
    end

    # Expand macros in a line 
    def expand!(text)
      if text =~ SCOPE_BEGIN
        leave_scope
        enter_scope $~[:name]
      end
      expand_inline! text
      expand_stmt!   text
      expand_other!  text
    end

    def leave_scope
      @scope = @scope.parent unless @scope.root?
    end

    def enter_scope(name)
      @scope = @scope.subscope(name)
    end

    # Expand inline macros
    def expand_inline!(text)
      text.gsub!(INLINE) do |chunk|
        if (body = $~[:body])
          # Inline definition
          name = $~[:name]
          @scope.i_macros[name] = Macro.new(name, [], body)
          body
        else
          # Resolve macro
          macro = @scope.i_macros[$~[:name]] or next chunk

          # Expand and split arguments
          args = []
          if (_args = $~[:args])
            expand_inline!(_args).scan(ARGS) { args << $&.strip }
          end

          # Expand macro with arguments
          macro.expand(args)
        end
      end
      text
    end

    # Expand statement macros
    def expand_stmt!(text)
      text.sub!(STMT) do |chunk|
        # Resolve macro
        macro = @scope.s_macros[$~[:name]] or next chunk

        # Prepare for arguments
        args    = []
        _labels = $~[:labels]
        _args   = $~[:args]

        # Recombine labels for first argument
        if macro.arity
          args << (_labels&.gsub(LABEL_SEP, " ") || "")
        end

        # Split further arguments
        _args&.scan(ARGS) { args << $&.strip }

        # Expand macro with arguments
        macro.expand(args)
      end
      text
    end

    # Perform miscellaneous expansions
    def expand_other!(text)
      text.gsub!(BRACKETS) do
        case $~[:tok]
        when '[' then  "#{$~[:auto]}("
        when ']' then ")#{$~[:auto]}"
        end
      end
      text
    end
  end

  class Macro
    attr_reader :name, :params, :body

    def initialize(name, params, body)
      @name   = name
      @params = params.each_with_index.to_h
      @body   = body
    end

    def arity
      @params.length
    end

    def expand(args)
      # Arity check
      args.length == arity or err_arity(args)

      # Substitute args into body
      @body.gsub(IDS) do |id|
        n = @params[$~[:id]] and args[n] or id
      end
    end

    def err_arity(args)
      raise PreprocessorError,
        "macro '#{name}' requires #{arity} arguments, " +
        "but #{args.length} were given."
    end
  end

  class Scope
    attr_reader :name, :parent, :i_macros, :s_macros

    def self.new_root
      Scope.new(nil)
    end

    def subscope(name)
      Scope.new(name, self)
    end

    def root?
      parent.nil?
    end

    private

    def initialize(name, parent = nil)
      @name     = name
      @parent   = parent
      @i_macros = Lookup.new(parent&.i_macros)
      @s_macros = Lookup.new(parent&.s_macros)

      i_macros['q'] = Macro.new('q', ['x', 'y'], '<This is Q with x and y ... yo.>')
      i_macros['z'] = Macro.new('z', ['o', 'p'], '<This is Z with o and p ... yo.>')

      s_macros['and$.l'] = Macro.new(
        'and$.l', ['s', 'd'], 'foobar s, d'
      )
    end
  end

  # A lookup table following these rules:
  #   * An identifier has exactly one value.
  #   * A value can have many identifiers.
  #
  class Lookup
    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @k2v    = {}
    end

    def [](key)
      @k2v[key] or @parent &.[] key
    end

    def []=(key, val)
      @k2v[key] = val
    end
  end

  # A lookup table following these rules:
  #   * An identifier has exactly one value.
  #   * A value has exactly one identifier.
  #   * On a conflicting insert, the older mapping is deleted.
  #
  class BidirectionalLookup
    attr_reader :parent

    def initialize(name, parent = nil)
      @parent = parent
      @k2v    = {}
      @v2k    = {}
    end

    def [](key)
      @k2v[key] or @parent ? @parent[key] : key
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end

  class PreprocessorError < StandardError; end
end

if __FILE__ == $0
  # Running as script
  loop do
    Raspp::process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

