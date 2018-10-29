/** **/
module extensions.algorithms.bloom.classes;

import std.range: InputRange;
import extensions.algorithms.bloom.libbloom;
debug { import std.stdio; }
/** **/
enum engine {
  singleHash,   /// Use only given hash functions
  doubleHash    /// Combine hash functions (aka double hashing)
}

/** Interface for bloom filter (the base class) **/
interface bloomFilter {
  /** **/
  void add (T) (T value);
  /** **/
  bool query (T) (T value);
  /** **/
  void clear ();
}

/** Basic bloom filter **/
final class basicFilter (size_t cells, engine e = engine.doubleHash) : bloomFilter {
  Storage!(bool,cells) storage;
  const size_t _cells = cells;
  @property size () const { return _cells; }
  alias hash = ubyte[] function (ubyte[]...);

  static if (e == engine.singleHash) {
    hash[] hashes;  // dynamic array
    /** **/
    this (hash[] f...) { hashes ~= f; }
    mixin singleHashEngine;
  }
  else static if (e == engine.doubleHash) {
    hash[2] hashes; // static array
    size_t _k;
    /** **/
    this (size_t k, hash f1, hash f2) { this._k = k; hashes = [f1,f2]; }
    mixin doubleHashEngine!_k;
  }
  void add (T) (T value) {
    import std.range: tee, array;
    hashEngine(value.toUbyte).tee!(a => storage.set(a, true)).array;
  }
  bool query (T) (T value) {
    import std.algorithm: map, all;
    return hashEngine(value.toUbyte).map!(a => (storage.get(a))).all!"a == true";
  }
  override void clear () { storage.clear; }
  size_t m (double fp, size_t capacity) { return size_t.init; }
  size_t k (size_t cells, size_t capacity) { return size_t.init; }
}
unittest {
  auto bf = new basicFilter!(50)(2, &md5, &murmur);
  bf.add("cat");
  assert(bf.query("cat"));
  assert(!bf.query("dog"));
}

//final class bitwiseFilter : bloomFilter {}

/** A2 bloom filter
 *
 * A fifo-like, active-active buffering bloom filter.
 *
 * Params:
 *  capacity = Maximum number of items in the active Bloom filter
 *  cells = The number of cells to use for Bloom filter
 *  e = The hash engine to use (default to double hashing)
 **/
final class a2Filter (size_t capacity, size_t cells, engine e = engine.doubleHash) : bloomFilter {
  const size_t _capacity = capacity;   // maximum number of items in the active bloom filter
  size_t _items = 0;             // number of items in the active bloom filter
  const size_t _cells = cells;         // the number of cells for the Bloom filter
  alias hash = ubyte[] function (ubyte[]...);
  Storage!(bool,cells)[2] storage;  // the underlying storage as static array
  /** Get the size of the Bloom filter **/
  @property size () const { return _cells; }
  static if (e == engine.singleHash) {
    hash[] hashes;  // dynamic array
    /** **/
    this (hash[] f...) { hashes ~= f; }
    mixin singleHashEngine;
  }
  else static if (e == engine.doubleHash) {
    hash[2] hashes; // static array
    size_t _k;
    @property functions () const { return _k; }
    /** **/
    this (size_t k, hash f1, hash f2) { this._k = k; hashes = [f1,f2]; }
    mixin doubleHashEngine!_k;
  }
  else { static assert (0); }
  invariant {
    assert (storage.length == 2);
    assert (storage[0].size == storage[1].size);
    //static assert (typeof(storage[0][0]) is typeof(bool));
  }
  /** **/
  void add (T) (T[] value...) {
    writefln ("add as T[] value... %s", value);
    foreach (v; value) { add(v); }
  }
  /** **/
  void add (T) (T value) {
    import std.traits;
    import std.range: tee, array;
    // the hash functions take ubyte and ubyte[]
    // in a2 we always set in storage[0]
    hashEngine(value.toUbyte).tee!(a => storage[0].set(a, true)).array;
    // if capacity is not reached yet
    if (++_items <= _capacity) return;
    // otherwise swap and clear the filters
    _items = 1;
    storage[1].clear;
    storage[0].swap(storage[1]);
  }
  /** **/
  bool query (T) (T[] value...) @system {
    import std.algorithm: map, all;
    return value.map!(a => query(a)).all!"a == true"; // all values must be found to return true
  }
  /** **/
  bool query (T) (T value) @system {
    import std.traits: isArray;
    import std.algorithm: map, all;
    return hashEngine(value.toUbyte).map!(a => (storage[0].get(a) || storage[1].get(a))).all!"a == true";
  }
  override void clear () { foreach (s; storage) { s.clear; } }
} // end class a2filter

/** **/
unittest {
  // static hashes
  auto a2 = new a2Filter!(10, 15)(6, &md5, &murmur);
  assert (a2.size == 15);
  assert (a2.functions == 6);
  a2.add("cat");
  assert(a2.query("cat"));
  assert(!a2.query("dog"));
}
/** **/
unittest {
  // dynamic hashes
  auto a2 = new a2Filter!(10, 15, engine.singleHash)(&md5, &murmur);
  assert (a2.storage.length == 2 && a2.storage[0].array.length == 15);
  a2.add("lion");
  assert(a2.query("lion"));
  assert(!a2.query("tiger"));
}
/** **/
unittest {
  auto a2 = new a2Filter!(10, 15)(6, &md5, &murmur);
  a2.add("string");
  a2.add(42);
}
unittest {
  auto a2 = new a2Filter!(10, 15)(6, &md5, &murmur);
  a2.add(int(-2));
  a2.add(uint(3));
  a2.add(short(6));
  a2.add(long(5600));
  a2.add(double(1.0));
  a2.add([1,2,3]);
  a2.add(4,5,6);
  a2.add('c');
  a2.add(wchar('w'));
  a2.add(dchar('d'));
  a2.add(['c', 'h', 'a', 'r']);
  a2.add("string");
  a2.add("wstring"w);
  a2.add("dstring"d);
  a2.add(["dog", "wolve"]);
  a2.add!string("snail", "mantis");
  struct S {
    int i = 4;
    alias i this;
  }
  S s;
  a2.add(s);
}
unittest {
  import std.range: iota, tee, array;
  //import std.algorithm: tee;
  auto a2 = new a2Filter!(10, 50)(6, &md5, &murmur);
  iota(0,11).tee!(a => a2.add(a)).array;
  writefln ("storage 0: %s", a2.storage[0]);
  writefln ("storage 1: %s", a2.storage[1]);
}
//final class spectralRMFilter : bloomFilter {}

//class countingFilter : bloomFilter {}

//final class spectralMIFilter : countingFilter {}

//final class stableFilter : countingFilter {}

/** Stores the underlying array
 *
 * Static initialized with type and size.
 **/
struct Storage (T, size_t length) {
  private T[length] array;  // static array of type T
  //alias array this;
  @property size () const { return length; }
  void set (size_t cell, T value) { array[cell] = value; }
  T get (const size_t cell) const { return array[cell]; }
  // clear array to init value
  void clear () pure @safe nothrow @nogc { array[] = T.init; }
  // increment and decrement only if T supports it (bool doesn't support this!)
  static if (__traits(compiles, { T i; i++; } )) {
    void increment (size_t cell, size_t value) { array[cell] += value; }
    void decrement (size_t cell, size_t value) { array[cell] -= value; }
  }
  void swap (ref Storage y) pure nothrow @nogc { import std.algorithm: swap; swap(this.array,y.array);

  }
} // end struct Storage
/** **/
unittest {
  import std.traits;
  auto s = Storage!(bool,10)();
  assert(s.array.length == 10);
  s.set(0, true);
  assert(s.get(0));
  auto t = Storage!(bool,10)();
  s.swap(t);
  assert(t.get(0));
}
unittest {
  import std.range;
  import std.algorithm;
  auto a = Storage!(bool, 10)();
  auto b = Storage!(bool, 10)();
  iota(0,10).filter!(i => i % 2).tee!(i => a.set(i,true)).array;
  iota(0,10).filter!(i => !(i % 2)).tee!(i => b.set(i,true)).array;
  a.swap(b);
  assert(a.get(0) == true && b.get(0) == false);
}
import extensions.ranges: rank, flatten;

private auto toUbyte (T) (T[] value...) {
  import std.array;
  import std.algorithm;
  return value.map!(a => a.toUbyte).array;
}
/** **/
private auto toUbyte (T) (T value) {
  import std.traits;
  static if (isArray!T) { return cast(ubyte[])value; }
  else { return cast(ubyte)value; }
}
unittest {
  auto ui = uint(2).toUbyte;
  auto i = int(-2).toUbyte;
  auto s = ("dog").toUbyte;
  auto c = ['c', 'h', 'a', 'r'].toUbyte;
  auto ia = [1,2,3,4].toUbyte;
  auto iv = toUbyte(1,2,3,4);
  auto sa = ["cat", "mouse"].toUbyte;
  auto sv = toUbyte("lion", "zebra");
}
/** **/
mixin template singleHashEngine () {
  /** **/
  private InputRange!size_t hashEngine (ubyte[] value...) pure nothrow @safe
  body {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    return hashes.map!(a => (a(value).bitsToNumber) % size).inputRangeObject;
  }
}

/** **/
mixin template doubleHashEngine (alias size_t k) {
  /** **/
  private InputRange!size_t hashEngine (ubyte[] value...) @system {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    const auto h1 = hashes[0](value).bitsToNumber;
    const auto h2 = hashes[1](value).bitsToNumber;
    return iota(0,k).map!(a => (h1 + a * h2) % size).inputRangeObject;
  }
}
