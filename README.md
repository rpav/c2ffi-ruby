# c2ffi-ruby

This is a bridge between [c2ffi](https://github.com/rpav/c2ffi) and
[ruby-ffi](https://github.com/ffi/ffi).  It reads the JSON output
produced by `c2ffi` and produces very readable Ruby.  Example:

```c
#define FOO (1 << 2)

#define QUUX "abc"

const int BAR = FOO + 10;
const char *Quux = QUUX;

extern int SomeExtern;

void blah(char *x[]);

extern char *foo;

typedef struct my_point {
  int x;
  int y;
  int odd_value[BAR + 1];
} my_point_t;

typedef struct {
  int a, b;
} anonymous_t;

typedef struct some_struct {
  struct _some_internal_struct {
    struct {
      double x;
    } a;
    int x;
    char c;

    enum {
      X, Y, Z
    } m;
  } s;

  int blah;
} some_struct_t;

union my_union {
  char c;
  int i;
  double d;
};

enum some_values {
  a_value,
  another_value,
  yet_another_value
};

void do_something(my_point_t *p, int x, int y);
```

```ruby
require 'ffi'

module Example
  extend FFI::Library
  ffi_lib "ex1", "ex2"

  BAR = 14

  QUUX = "abc"

  attach_variable :SomeExtern, :SomeExtern, :int

  attach_function 'blah', [
    :pointer,
  ], :void

  attach_variable :foo, :foo, :string

  class My_Point < FFI::Union
    layout \
      :x, :int,
      :y, :int,
      :odd_value, [:int, 15]
  end

  My_Point_T = My_Point

  class Anon_Type_0 < FFI::Union
    layout \
      :a, :int,
      :b, :int
  end

  Anonymous_T = Anon_Type_0

  class Anon_Type_1 < FFI::Union
    layout \
      :x, :double
  end

  enum :anon_type_2, [
    :X, 0,
    :Y, 1,
    :Z, 2,
  ]

  class C_Some_Internal_Struct < FFI::Union
    layout \
      :a, Anon_Type_1,
      :x, :int,
      :c, :char,
      :m, :anon_type_2
  end

  class Some_Struct < FFI::Union
    layout \
      :s, C_Some_Internal_Struct,
      :blah, :int
  end

  Some_Struct_T = Some_Struct

  class My_Union < FFI::Union
    layout \
      :c, :char,
      :i, :int,
      :d, :double
  end

  enum :some_values, [
    :a_value, 0,
    :another_value, 1,
    :yet_another_value, 2,
  ]

  attach_function 'do_something', [
    :pointer,
    :int,
    :int,
  ], :void

  QUUX = "abc"

  FOO = 4
end
```

## Usage

First, produce a `spec` file using `c2ffi`:

```console
$ cd example/simple/
$ c2ffi -M macros.h -o example.spec example.h
$ c2ffi -o macros.spec macros.h
```

Now you can generate a file manually with the included tool,
`bin/c2ffi-ruby`, as follows:

```console
$ c2ffi-ruby -M Example -l ex1,ex2 -o simple.rb *.spec
```

This produces the `simple.rb` file, as included.  Realistically, you
should integrate this into your build process; you can either use this
tool, or call C2FFI::Parser.parse directly.

```ruby
C2FFI::Parser.parse(module_name, lib_or_libs, spec_array, io = $stdout)
```

Note that C2FFI::Parser doesn't actually parse JSON, but rather takes
an array of hashes.  In theory, you could use this to produce output
for any input format that is parsed in a similar manner.

