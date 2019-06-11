# frozen_string_literal: true
# encoding: utf-8
#
# RAS - Ruby ASsembler
# Copyright (C) 2019 Jeffrey Sharp
#
# RAS is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# RAS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with RAS.  If not, see <http://www.gnu.org/licenses/>.

module RAS
  class Content
    attr :content, :offset, :length

    def initialize
      @offset = 0
      @length = 0
    end

    protected

    def integers(*vals)
      vals.empty? ? [0] : vals.map! { |v| Integer(v) }
    end

    def advance(len)
      @length = @offset if @length < (@offset += len)
    end
  end

  # General case
  class Words < Content
    def initialize(width)
      @content = Array.new(1024, 0)
      @width   = width
    end

    def word(*vals)
      @content << integers(*vals)
    end
  end

  # Common special case: 8-bit 2's-complement bytes
  class Bytes < Content
    def initialize
      @content = String.new(capacity: 1024)
    end

    def int8(*vals)
      advance(pack("C*", *vals))
    end

    def int16be(*vals)
      advance(pack("S>*", *vals) < 1)
    end

    def int16le(*vals)
      advance(pack("S<*", *vals) < 1)
    end

    def int32be(*vals)
      advance(pack("L>*", *vals) < 2)
    end

    def int32le(*vals)
      advance(pack("L<*", *vals) < 2)
    end

    def int64be(*vals)
      advance(pack("Q>*", *vals) < 3)
    end

    def int64le(*vals)
      advance(pack("Q<*", *vals) < 3)
    end

    def big_endian
      alias int16 int16be
      alias int32 int32be
      alias int64 int64be
    end

    def little_endian
      alias int16 int16le
      alias int32 int32le
      alias int64 int64le
    end

    private

    def pack(template, *vals)
      vals = integers(*vals)
      vals.pack(template, buffer: @content)
      vals.length
    end
  end
end

