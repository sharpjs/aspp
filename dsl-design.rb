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

  public                  # output, export
  protected               # output, ------
  private                 # ------, ------

  at :foo                 # label

  at :foo do              # label with local subscope
    #...
  end

  eq :foo, 42             # equate

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

# Data

  # aspects:
  # - alignment
  # - field width
  # - value width
  # - value fill behavior
  # - value encoding

  # directive specifies field only

  arch        :pdp10, 'DEC PDP-10'
  unit_size   36
  unit_order  :be
  unaligned
  aligned

  data_sizes  word: 1

  def word *vs; raw 1, *vs; end

  arch        :m68k, 'Motorola 680X0 / ColdFire'
  unit_size   8
  unit_order  :be
  unaligned
  aligned

  data 2,     0xFFFF

  data_sizes  byte: 1, word: 2, long: 4

  # directive specifies everything

  i8        1, 2            #  8-bit integer (signed or unsigned)
  i16       1, 2            # 16-bit integer (signed or unsigned)
  i32       1, 2            # 32-bit integer (signed or unsigned)
  i64       1, 2            # 64-bit integer (signed or unsigned)
  f16       1.0, 2.0        # 16-bit float
  f32       1.0, 2.0        # 32-bit float
  f64       1.0, 2.0        # 64-bit float
  utf8      "a"             # UTF-8 characters
  utf8z     "a"             # UTF-8 characters + null terminator
  foo       a: 42, b: "hi"  # struct

