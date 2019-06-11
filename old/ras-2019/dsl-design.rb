# Assembly DSL (ColdFire ISA as example)

# Addressing Modes

  d0
  a0
  [a0]
  [-a0]
  +[a0]
  [a0, 42]
  [a0, d0*2, 42]
  [42].w
  [42].l # or just [42]
  [pc, 42]
  [pc, d0*2, 42]

# Symbols

  :foo                    # a symbol

  at :foo                 # label
  at! :foo                # label, exported

  at :foo do              # label with local subscope
    #...
  end

  set :foo, 42            # set symbol value
  set! :foo, 42           # set symbol value, disallow changes

# Sample

  at :load do
    nop
  
    move.w      SR_INIT, my.init = d0
    move.w      my.init, sr
  
    at :another
    moveq       0, d0
    move.w      d0, [:dcr]
    move.l      d0, [:dacr0]
    move.l      d0, [:dmr0]
    move.l      d0, [:dacr1]
    move.l      d0, [:dmr1]
  end

# Architecture

  arch        :pdp10, 'DEC PDP-10'
  unit_size   36
  unit_order  :be
  data_sizes  word: 1

  arch        :m68k, 'Motorola 680X0 / ColdFire'
  unit_size   8
  unit_order  :be
  data_sizes  byte: 1, word: 2, long: 4

# Data

  # aspects:
  # - byte order
  # - alignment
  # - field width
  # - value width
  # - value justification
  # - value encoding

  # - byte order
  unit_order  :be
  unit_order  :le

  # - alignment
  unaligned
  aligned

  # value width/justification/encoding + field width
  int8      42
  int16     42
  int32     42
  int64     42
  float16   3.14
  float32   3.14
  float64   3.14
  float96   3.14
  char8     "hello"
  char16    "hello"
  char32    "hello"
  string8   "hello"
  string16  "hello"
  string32  "hello"
  mystruct  a: 42, b: "hello"

  # underlying call for string32
  RAS::String.write(@out, 4, "hello")


