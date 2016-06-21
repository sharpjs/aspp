#### `EXPERIMENTAL`

I've been trying various ideas for an assembly language preprocessor.

The current iteration, **aspp**, targets a
[C preprocessor](https://gcc.gnu.org/onlinedocs/cpp/) +
[GNU assembler](https://www.gnu.org/software/binutils/)
toolchain and provides a few extra capabilities:

#### Per-label macro invocation

Redefine the `.label` macro to enable custom behavior (alignment, for example) for each non-local label.

```
foo:   =>   .label foo;
```

#### Global labels

These have an extra `:` suffix.

```
foo::   =>   .label foo; .global foo;
```

#### Local scopes

These exist between `{` `}` pairs and can be nested.
A scope has a name: either that of its preceding label or a unique generated name.
Redefine the `.scope` and `.endscope` macros to enable custom behavior (frame setup, for example) for each scope.

```
foo:
{       =>   #define SCOPE foo
  ...   =>   .scope foo
  ...
  ...   =>   .endscope foo
}       =>   #undef SCOPE
```

#### Local symbols

These begin with `.` and are valid within the containing scope.

```
.foo   =>   L(foo)
```

#### Local identifier aliases

In operands, `a = b` means that subsequent `a` will be replaced with `b`,
until either `a` or `b` is re-aliased or the containing scope ends.
This enables registers to be renamed according to their usage.

A `@` prefix escapes alias replacement.

```
op foo = a0   =>   op _(foo)a0  // foo aliased to a0
op foo        =>   op _(foo)a0
op bar = a0   =>   op _(bar)a0  // bar aliased to a0, foo unaliased
op @bar       =>   op bar       // escaped
```

#### Brackets replaced with parentheses

In operands, `[` `]` brackets are replaced with parentheses.
This helps to distinguish indirect addressing from CPP macro invocations.

```
[8, fp]   =>   (8, fp)
```

#### Immediate-mode prefix removal

In operands, `#` are removed if the directive name begins with `.` or contains `$`.
This enables macros to take immediate-mode arguments but treat them as numbers.

```
foo$.l #42, d0   =>   foo$.l _(#)42, d0
```

#### Predefined macros

These macros support the above features.

```
#define _(x)                          // inline comment
#define L(name)        .L$SCOPE$name  // local symbol in current scope
#define S(scope, name) .L$scope$name  // local symbol in given scope

.macro .label name:req                // default label behavior
    \name\():
.endm

.macro .scope name:req, depth:req     // default begin-scope behavior
.endm

.macro .endscope name:req, depth:req  // default end-scope behavior
.endm
```
