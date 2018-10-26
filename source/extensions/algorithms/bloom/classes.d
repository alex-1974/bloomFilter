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
interface bloomFilter (T, engine e = engine.doubleHash) {
  void add (T value);
  bool query (T value);
  void clear ();
}

/** Basic bloom filter **/
final class basicFilter (T, size_t size, engine e = engine.doubleHash) : bloomFilter!T {
  Storage!(bool,size) storage;
  override void add (T value) { hashEngine(value); }
  override bool query (T value) { return true; }
  override void clear () { storage.clear; }
  static if (e == engine.singleHash) { mixin singleHashEngine!T; }
  else { mixin doubleHashEngine!T; }
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
final class a2Filter (T, size_t length, engine e = engine.doubleHash) : bloomFilter!T {
  alias hash = ubyte[] function(T);
  Storage!(bool,length)[2] storage;
  @property size () { return length; }
  static if (e == engine.singleHash) {
    hash[] hashes;  // dynamic array
    this (hash[] f...) { hashes ~= f; }
    mixin singleHashEngine!T;
  }
  else {
    hash[2] hashes; // static array
    this (hash f1, hash f2) { hashes = [f1,f2]; }
    mixin doubleHashEngine!T;
  }

  override void add (T value) {
    import std.range: tee, array;
    // in a2 we always set in storage[0]
    hashEngine(value).tee!(a => storage[0].set(a, true)).array;
  }
  override bool query (T value) { return true; }
  override void clear () { foreach (s; storage) { s.clear; } }
}
unittest {
  // static hashes
  auto a2 = new a2Filter!(string, 10)(&md5!string, &murmur!string);
  assert (a2.storage.length == 2 && a2.storage[0].array.length == 10);
}
unittest {
  // dynamic hashes
  auto a2 = new a2Filter!(string, 10, engine.singleHash)(&md5!string, &murmur!string);
}
//final class spectralRMFilter : bloomFilter {}

//class countingFilter : bloomFilter {}

//final class spectralMIFilter : countingFilter {}

//final class stableFilter : countingFilter {}

/** Stores the underlying array **/
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
}
/** **/
mixin template singleHashEngine (T) {
  private InputRange!size_t hashEngine (T value) {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    return hashes.map!(a => (a(value).bitsToNumber) % size).inputRangeObject;
  }
}

/** **/
mixin template doubleHashEngine (T) {
  private InputRange!size_t hashEngine (T value) {
    import std.range: iota, inputRangeObject;
    import std.algorithm: map;
    auto h1 = hashes[0](value).bitsToNumber;
    auto h2 = hashes[1](value).bitsToNumber;
    return iota(0,10).map!(a => (h1 + a * h2) % size).inputRangeObject;
    //return [];
  }
}
