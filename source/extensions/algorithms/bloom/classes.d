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
  void add (T) (T value);
  bool query (T) (T value);
  void clear ();
}

/** Basic bloom filter **/
final class basicFilter (size_t size, engine e = engine.doubleHash) : bloomFilter {
  Storage!(bool,size) storage;
  override void add (T) (T value) { hashEngine(value); }
  override bool query (T) (T value) { return true; }
  override void clear () { storage.clear; }
  static if (e == engine.singleHash) { mixin singleHashEngine; }
  else { mixin doubleHashEngine; }
  size_t m (double fp, size_t capacity) { return size_t.init; }
  size_t k (size_t cells, size_t capacity) { return size_t.init; }
}
unittest {
  //auto bf = new basicFilter!(string, 10);
  //bf.add("cat");
  //bf.query("dog");
}

//final class bitwiseFilter : bloomFilter {}

/** A2 bloom filter
 *
 * A fifo-like, active-active buffering bloom filter.
 **/
final class a2Filter (size_t capacity, size_t cells, size_t k, engine e = engine.doubleHash) : bloomFilter {
  size_t _capacity = capacity;
  size_t _cells = cells;
  alias hash = ubyte[] function (ubyte[]);
  Storage!(bool,cells)[2] storage;
  @property size () { return _cells; }
  static if (e == engine.singleHash) {
    hash[] hashes;  // dynamic array
    this (hash[] f...) { hashes ~= f; }
    mixin singleHashEngine;
  }
  else {
    hash[2] hashes; // static array
    this (hash f1, hash f2) { hashes = [f1,f2]; }
    mixin doubleHashEngine;
  }
  void test (U) (U data) {
    writefln("data: %s", data);
  }
  void add (T) (T value) {
    import std.range: tee, array;
    // in a2 we always set in storage[0]
    hashEngine(cast(ubyte[])value).tee!(a => storage[0].set(a, true)).array;
  }
  override bool query (T) (T value) pure nothrow @safe @nogc { return true; }
  override void clear () { foreach (s; storage) { s.clear; } }
}
unittest {
  // static hashes
  auto a2 = new a2Filter!(10, 15, 6)(&md5, &murmur);
  assert (a2.storage.length == 2 && a2.storage[0].array.length == 15);
  a2.add("cat");
  a2.test!int(5);
}
unittest {
  // dynamic hashes
  auto a2 = new a2Filter!(10, 15, 6, engine.singleHash)(&md5, &murmur);
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
  T[length] array;  // static array of type T
  @property size () { return length; }
  void set (size_t cell, T value) { array[cell] = value; }
  T get (size_t cell) { return array[cell]; }
  // clear array to init value
  void clear () pure @safe nothrow @nogc { array[] = T.init; }
  // increment and decrement only if T supports it (bool doesn't support this!)
  static if (__traits(compiles, { T i; i++; } )) {
    void increment (size_t cell, size_t value) { array[cell] += value; }
    void decrement (size_t cell, size_t value) { array[cell] -= value; }
  }
}
unittest {
  import std.traits;
  auto s = Storage!(bool,10)();
  assert(s.array.length == 10);
  s.set(0, true);
  assert(s.get(0));
}
/** **/
mixin template singleHashEngine () {
  /** **/
  private InputRange!size_t hashEngine (ubyte[] value) {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    return hashes.map!(a => (a(value).bitsToNumber) % size).inputRangeObject;
  }
}

/** **/
mixin template doubleHashEngine () {
  /** **/
  private InputRange!size_t hashEngine (ubyte[] value) {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    auto h1 = hashes[0](value).bitsToNumber;
    auto h2 = hashes[1](value).bitsToNumber;
    return iota(0,10).map!(a => (h1 + a * h2) % size).inputRangeObject;
  }
}
