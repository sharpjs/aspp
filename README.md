#### `EXPERIMENTAL`

I've been trying various ideas for an assembly language preprocessor.

The current iteration targets **[the GNU assembler](https://www.gnu.org/software/binutils/)** and provides a few extra capabilities:

* Global labels.  These have an extra `:` suffix.

  ```
  foo::  =>  .global foo
  ```

* Local symbols.  These begin with `.` and are valid within the scopes described below.

  ```
  .foo  =>  L(foo)
  ```

* Per-label macro invocation.  Redefine the `.label` macro to enable custom behavior (alignment, for example) for each non-local label.

  ```
  foo:  =>  .label foo
  ```

* Local symbol scopes.  These exist between  `{` / `}` pairs and can be nested.

  ```
   foo: {   =>   .label foo
    ...          #define scope foo
    ...
  }         =>   #undef scope
  ```

* Local identifier aliases.  `a = b` means that future occurrences of `a` will be replaced with `b`, until either identifier is redefined or a non-local label is encountered.  This enables registers to be renamed according to their usage.

  ```
  op  foo = a0   =>   _(foo)a0  // foo aliased to a0
  op  foo        =>   _(foo)a0
  op  bar = a0   =>   _(bar)a0  // bar aliased to a0, foo undefined
  ```

* Brackets replaced with parentheses.  I prefer brackets for indirect addressing, as they appear distinct from CPP macro invocations.

  ```
  [8, fp]   =>   (8, fp)
  ```

* Immediate-mode prefix removal for macros.  If the macro name begins with `.` or contains `$`, any `#` are removed from operands.

  ```
  cmp$.l #42, d0     cmp$.l _(#)42, d0
  ```

* Predefined macros.  These are required to support the above features.

  ```
  .macro .label name:req          // default .macro label
    \name\():
  .endm
  #define _(x)                    // inline comment
  #define L(name) .L$scope$name   // reference to local symbol
  ```
