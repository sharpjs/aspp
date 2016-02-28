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
    (?<text> (?: [^ \t\r\n`'";] | [ \t]++(?!;) | #{QUOTE} )*+ )
    (?:      [ \t]*+ ; [^\r\n]*+ )?+
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
    )?+
  | 
    #{QUOTE} (?# excluded #)
  }mx

  # Statement-like macro invocation
  STMT = %r{
    \A
    (?<indent> #{INDENT} )
    (?<labels> (?: #{ID}: #{WS}*+ )*+ )
    (?<name>   #{ID} )
    (?:
      #{WS}++
      (?<args> (?:,|#{CODE})*+ )
    )?
    \z
  }mx

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

    # Expand macros in a string
    def expand!(text)

      # Expand inline macros
      text.gsub!(INLINE) do |text|
        # Resolve macro
        macro = @scope[$~[:name]] or next text

        # Expand and split arguments
        args = []
        if (text = $~[:args])
          expand!(text).scan(ARGS) { args << $&.strip }
        end

        # Expand macro with arguments
        macro.expand(args)
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
      .tap { |s| $stderr.puts "EXPANDING:\n  #{inspect}\n  |#{s}|" }
    end

    def err_arity(args)
      raise PreprocessorError,
        "macro '#{name}' requires #{arity} arguments, " +
        "but #{args.length} were given."
    end
  end

  # A scope following these rules:
  #   * An identifier has exactly one value.
  #   * A value can have many identifiers.
  #
  class Scope
    attr_reader :name, :parent

    def initialize(name, parent = nil)
      @name, @parent, @k2v = name, parent, {}
      self['q'] = Macro.new('q', ['x', 'y'], '<This is Q with x and y ... yo.>')
      self['z'] = Macro.new('z', ['o', 'p'], '<This is Z with o and p ... yo.>')
    end

    def self.new_root
      Scope.new(nil)
    end

    def subscope(name)
      Scope.new(name, self)
    end

    def [](key)
      @k2v[key] or @parent &.[] key
    end

    def []=(key, val)
      @k2v[key] = val
    end
  end

  # A scope following these rules:
  #   * An identifier has exactly one value.
  #   * A value has exactly one identifier.
  #   * On a conflicting insert, the older mapping is deleted.
  #
  class BidirectionalScope
    attr_reader :name, :parent

    def initialize(name, parent = nil)
      @name, @parent, @k2v, @v2k = name, parent, {}, {}
    end

    def self.new_root
      Scope.new(nil)
    end

    def subscope(name)
      Scope.new(name, self)
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

#
# FEATURES
#
# * ; comments
# * line continuation
#
# - Directive-like macros
# - Function-like macros
# - Token-like macros
# - Inline token-like macro def
# - Inline code
#
# - scoped macros
# - scoped labels
#
# - Replace [ ] with ()
# - Add # to numbers
# - Replace ++ and --
# - Replace 'a' with 'a
#

if __FILE__ == $0
  # Running as script
  loop do
    Raspp::process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

