/** Contains the bloom filter class hierachy
*
* Authors: Alexander Leisser, (alex.leisser@gmail.com)
* Version: 1.0alpha
* History:
*  1.0alpha initial version
* Copyright: Alexander Leisser
* License: <a href="https://www.gnu.org/licenses/gpl-3.0.html">GPL-3.0</a>
**/
module bloom.classes;

import std.range: InputRange;
import bloom.libbloom;
debug { import std.stdio; }

/** **/
enum engine {
  singleHash,   /// Use only given hash functions
  doubleHash    /// Combine hash functions (aka double hashing)
}

/** Interface for bloom filter (the base class) **/
interface bloomFilter {

  /** Adding items to the filter **/
  void add (T) (T value);
  /** Query for items in the filter **/
  bool query (T) (T value);
  /** Clear the filter **/
  void clear ();
  /** Get the size of the filter **/
  size_t size ();
}

/** Standard bloom filter (SBF) **/
final class basicFilter (size_t cells, size_t k, engine e = engine.doubleHash) : bloomFilter {
  bitStorage!(cells) storage;
  const size_t _cells = cells;
  size_t size () const { return _cells; }
  alias hash = ubyte[] function (ubyte[]...);
  hash[] hashes;
  this(hash[] f...) { hashes ~= f; }
  static if (e == engine.singleHash) {
    mixin singleHash;
  }
  else static if (e == engine.doubleHash) {
    mixin doubleHash!k;
  }
  else { static assert (0); }

  /** **/
  void add (T) (T value) {
    import std.range: tee, array;
    hashEngine(value.toUbyte).tee!(a => storage.set(a, true)).array;
  }

  /** **/
  bool query (T) (T value) {
    import std.algorithm: map, all;
    return hashEngine(value.toUbyte).map!(a => (storage.get(a))).all!"a == true";
  }

  /** **/
  override void clear () { storage.clear; }

  //size_t m (double fp, size_t capacity) { return size_t.init; }
  //size_t k (size_t cells, size_t capacity) { return size_t.init; }
}
/** **/
unittest {
  auto bf = new basicFilter!(25, 2)(&md5, &murmur);
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
final class a2Filter (size_t capacity, size_t cells, size_t k, engine e = engine.doubleHash) : bloomFilter {
  const size_t _capacity = capacity;   // maximum number of items in the active bloom filter
  size_t _items = 0;                   // number of items in the active bloom filter
  const size_t _cells = cells;         // the number of cells for the Bloom filter
  alias hash = ubyte[] function (ubyte[]...);
  bitStorage!(cells)[2] storage;  // the underlying storage as static array
  /** Get the size of the Bloom filter **/
  size_t size () const { return _cells; }
  hash[] hashes;
  this(hash[] f...) { hashes ~= f; }
  static if (e == engine.singleHash) {
    mixin singleHash;
  }
  else static if (e == engine.doubleHash) {
    mixin doubleHash!k;
  }
  else { static assert (0); }
  invariant {
    assert (storage.length == 2);
    assert (storage[0].size == storage[1].size);
    //static assert (typeof(storage[0][0]) is typeof(bool));
  }
  /** Add a value to the filter
   *
   * Params:
   *  value = List of values
   **/
  void add (T) (T[] value...) {
    writefln ("add as T[] value... %s", value);
    foreach (v; value) { add(v); }
  }
  /** ditto **/
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
  /** Check if value is in the filter
   *
   * If not found in the filter, the term has never been added for sure. If found
   * there is a chance for a false-positive.
   * If more than one term is queried for, all of them must match to return true.
   * Params:
   *  value = term to search for
   * Returns: Returns false if value is for sure not in the filter, otherwise false.
   **/
  bool query (T) (T[] value...) @system {
    import std.algorithm: map, all;
    return value.map!(a => query(a)).all!"a == true"; // all values must be found to return true
  }
  /** ditto **/
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
  auto a2 = new a2Filter!(10, 15, 6)(&md5, &murmur);
  assert (a2.size == 15);
  assert (a2.functions == 6);
  a2.add("cat");
  assert(a2.query("cat"));
  assert(!a2.query("dog"));
}
/** **/
unittest {
  // dynamic hashes
  auto a2 = new a2Filter!(10, 15, 0, engine.singleHash)(&md5, &murmur);
  assert (a2.storage.length == 2 && a2.storage[0].array.length == 15);
  a2.add("lion");
  assert(a2.query("lion"));
  assert(!a2.query("tiger"));
}
/** **/
unittest {
  auto a2 = new a2Filter!(10, 15, 6)(&md5, &murmur);
  a2.add("string");
  a2.add(42);
}
unittest {
  auto a2 = new a2Filter!(10, 15, 6)(&md5, &murmur);
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
  auto a2 = new a2Filter!(10, 50, 6)(&md5, &murmur);
  iota(0,11).tee!(a => a2.add(a)).array;
  writefln ("storage 0: %s", a2.storage[0]);
  writefln ("storage 1: %s", a2.storage[1]);
}

//final class spectralRMFilter : bloomFilter {}

/** Counting bloom filter (CBF)
 *
 * The math is the same as with standard bloom filters. For a given amount of elements,
 * we want to include, and a allowed false-positive-rate, we get the required number of cells
 * we need and the optimal number of hash functions.
 * The difference is in the width of each cell.
 * SBF use just one bit to store the information. The CBF uses a fixed-width
 * of bits (the bucket). This allows us to increment and decrement the bucket under certain conditions.
 * Params:
 *  cells = number of cells
 *  width = size of the buckets
 *  e = hashing method (default to double hashing)
 ***/
class countingFilter (size_t cells, size_t width, size_t k, engine e = engine.doubleHash): bloomFilter {
  private enum size_t _cells = cells;           // the number of cells for the Bloom filter
  private enum size_t _width = width;           // the size of the buckets
  private enum size_t _length = _cells*_width;  // the total size of the filter
  private bool _dirty = false;                  // the filter is dirty if over- or underflows occured
  private bitStorage!(_length) storage;         // the underlying storage
  alias hash = ubyte[] function (ubyte[]...);
  /** Return size of filter **/
  @property size_t size () const { return _cells; }
  /** Check if filter got compromised **/
  @property bool dirty () const { return _dirty; }
  hash[] hashes;
  this (hash[] f...) {
    hashes ~= f;
  }

  static if (e == engine.singleHash) { mixin singleHash; }
  else static if (e == engine.doubleHash) { mixin doubleHash!k; }
  else { static assert (0); }

  invariant {
    assert(_width < _cells, "Does it make sense if cells < width?");
    assert(0 < _length && _length < size_t.max, "Storage without length or storage bigger than the maximum of size_t!");  // we use size_t as index of the bitArray
    assert(hashes.length > 0, "No hash functions given!");
  }

  /** Adding items to the filter
   *
   * If a bucket value reaches
   * <math display="inline"><msup><mn>2</mn><mi>w</mi></msup><mn>-1</mn></math>
   * it cannot be incremented further.
   * This introduces undercounts with the probability of <em>false negative errors</em>
   * Params:
   *  value = List of values
   **/
  void add (T) (T[] value...) { foreach (v; value) { add(v); } }
  /** ditto **/
  void add (T) (T value) @system {
    import std.range;
    import std.algorithm;
    hashEngine(value.toUbyte).map!(a => increment(a)).array;
  }

  /** Remove item from the filter
   *
   * As long as the filter is not <em>dirty</em> (no overflow occured yet) removing items is safe.
   * If the filter is dirty, removings introduce the possibility of <em>false negative errors</em>.
   **/
  void remove (T) (T[] value...) @system {
    import std.algorithm: each;
    value.each!(a => remove(a));
  }
  /** ditto **/
  void remove (T) (T value) @system {
    import std.range;
    import std.algorithm;
    auto h = hashEngine(value.toUbyte).save;
    // check if value can be found in filter
    // we can't remove, what we didn't insert beforehand
    //if (h.map!(a => getBucket(a).any!"a == true").all!"a == true") {
    if (h.map!(a => count(a)).minElement) { h.each!(a => decrement(a)); }
  }

  /** Query the item
   *
   * Check if the term is within the filter.
   * If more than one term is searched for returns the minimum of all terms.
   * Returns the minimum value as frequency estimate (known as minimum selection)
   **/
  size_t query (T) (T[] value...) {
    import std.algorithm: minElement, map;
    return value.map!(a => query(a)).minElement;
   }
  /** ditto **/
  size_t query (T) (T value) @system {
    import std.algorithm: minElement, map;
    return hashEngine(value.toUbyte)
            .map!(a => count(a))
            .minElement;
  }
  /** Clear the filter **/
  void clear() pure nothrow @safe @nogc {
    storage.clear;
    _dirty = false;
  }
  /** Gives the index of the first bit in the bucket **/
  private size_t index (size_t cell) const pure nothrow @safe @nogc
  in { assert (cell <= _cells); }
  out (result) { assert(result <= _length-(_width - 1), "Index violation!"); }
  body { return cell * _width; }

  /** Sums up the bits in the bucket **/
  private size_t count (size_t cell) pure nothrow @safe
  in { assert (cell <= _cells); }
  out (result) { assert(0 <= result && result <= (2^_width) - 1, "Bucket out of bounds!"); }
  body { return sumBits(getBucket(cell)); }

  /** Increment the bucket **/
  private bool increment (size_t cell) @safe pure nothrow
  in { assert (cell <= _cells); }
  out { assert(0 < count(cell) && count(cell) <= (2^_width) - 1, "Bucket out of bounds!"); }
  body {
    enum bool[_width] alignedOne = [(_width-1):1];  // e.g. 0001
    enum bool[_width] alignedFull = true;           // e.g. 1111
    if (getBucket(cell) == alignedFull) {
      // just a shortcut if bucket is already full
      _dirty = true;
      return false;
    }
    else {
      bool[] result;
      addition(getBucket(cell), alignedOne, result);
      setBucket(cell,result);
      return true;
    }
  }

  /** Decrement the bucket **/
  private bool decrement (size_t cell) @safe pure nothrow
  in { assert (cell <= _cells); }
  out { assert(0 <= count(cell) && count(cell) < (2^_width) - 1, "Bucket out of bounds!"); }
  body {
    import std.range;
    enum bool[_width] alignedComplement = true;   // e.g. 1111 (the complement of 0001)
    enum bool[_width] alignedEmpty = false;       // e.g. 0000
    // shortcut if bucket is already empty
    if (getBucket(cell) == alignedEmpty) {
      _dirty = true;
      return false;
    }
    bool[] result;
    // Decrementing is subtraction by -1 but we use the two complements way of
    // subtracting bits.
    // Inverting the subtrahend and adding 1 we get the two-complement. Adding
    // this to the minuend gives us the difference of the subtraction.
    addition(getBucket(cell), alignedComplement, result);
    setBucket(cell, result);
    // we don't care about overflows
    return true;
  }

  /** Get bucket **/
  private auto getBucket (size_t cell) const pure nothrow @safe
  in { assert (cell <= _cells); }
  out (result) { assert(result.length == _width); }
  body {
    auto i = index(cell);
    import std.range: iota, array;
    import std.algorithm: map;
    return iota(i, i+_width).map!(a => storage.get(a)).array;
  }

  /** Set bucket **/
  private void setBucket (size_t cell, bool value) pure nothrow @safe @nogc
  in { assert (cell <= _cells); }
  body {
    import std.range: iota;
    import std.algorithm: each;
    iota(0,_width).each!(a => storage.set(index(cell)+a,value));
  }
  /** ditto **/
  private void setBucket (size_t cell, bool[] value) pure nothrow @safe @nogc
  in {
    assert (value.length == _width);
    assert (cell <= _cells);
  }
  body {
    import std.range: iota;
    import std.algorithm: each;
    iota(0,_width).each!(a => storage.set(index(cell)+a,value[+a]));
  }
} // end class countingFilter

/** **/
unittest {
  auto cf = new countingFilter!(10,4, 5)(&md5, &murmur);
  cf.add("butterfly");
  assert(cf.query("butterfly"));
  assert(!cf.query("dog"));
  cf.remove("butterfly");
  assert(!cf.dirty);
  assert(!cf.query("butterfly"));
  cf.clear;
  cf.add("eagle");
  cf.add("eagle");
  assert(cf.query("eagle") == 2);
  cf.remove("eagle");
  assert(cf.query("eagle") == 1);
}

//final class spectralMIFilter : countingFilter {}

//final class stableFilter : countingFilter {}

/** Stores the underlying array
 *
 * Static initialized with size.
 **/
struct bitStorage (size_t cells) {
  private bool[cells] array;  // static array of type T
  //alias array this;
  @property size () const pure nothrow @safe @nogc { return cells; }
  void set (size_t cell, bool value) pure @safe nothrow @nogc { array[cell] = value; }
  bool get (const size_t cell) const pure @safe nothrow @nogc { return array[cell]; }
  // clear array to init value
  void clear () pure @safe nothrow @nogc { array[] = bool.init; }
  void swap (ref bitStorage y) pure nothrow @nogc { import std.algorithm: swap; swap(this.array,y.array); }
  invariant {
    assert(array.length > 0);
  }
} // end struct Storage
/** **/
unittest {
  import std.traits;
  auto s = bitStorage!(10)();
  assert(s.array.length == 10);
  s.set(0, true);
  assert(s.get(0));
  auto t = bitStorage!(10)();
  s.swap(t);
  assert(t.get(0));
}
unittest {
  import std.range;
  import std.algorithm;
  auto a = bitStorage!(10)();
  auto b = bitStorage!(10)();
  iota(0,10).filter!(i => i % 2).tee!(i => a.set(i,true)).array;
  iota(0,10).filter!(i => !(i % 2)).tee!(i => b.set(i,true)).array;
  a.swap(b);
  assert(a.get(0) == true && b.get(0) == false);
}

/** Conerts to ubyte array **/
private auto toUbyte (T) (T[] value...) pure nothrow {
  import std.array;
  import std.algorithm;
  return value.map!(a => a.toUbyte).array;
}
/** ditto **/
private auto toUbyte (T) (T value) pure nothrow  {
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

/** Simple hashing
 *
 * Just feeds all given hash functions with the value and returns them as array
 * of decimal numbers.
 **/
mixin template singleHash () {
  /** Hash engine
   *
   * Params:
   *  value = List of values as ubyte arrays
   * Returns: Array of decimal numbers
   **/
  private size_t[] hashEngine (ubyte[] value...) @system
  body {
    import std.range: iota, array;
    import std.algorithm: map;
    return hashes.map!(a => (a(value).bitsToNumber) % size).array;
  }
}

/** Double-hashing algorithm
 *
 * Bloom filters require multiple hash functions (hash values), which for practical purposes we don't have.
 * Double hashing just needs two hash functions and combine them to get the required number of hash values.
 *
 * Given two hash functions (<em>h<sub>1</sub>, h<sub>2</sub></em>) and the value
 * (<em>v</em>) we combine them <em>i</em>-times to get the required number
 * of hash values. To stay within the bounds of our storage we take the modulo with the storage size.
 * <math display="block" href="https://en.wikipedia.org/wiki/Double_hashing">
 *  <mrow>
 *   <mi>h</mi><mfenced><mi>i</mi><mi>v</mi></mfenced><mo>=</mo>
 *   <mo>(</mo><msub><mi>h</mi><mn>1</mn></msub><mo>(</mo><mi>v</mi><mo>)</mo><mo>+</mo>
 *   <mi>i</mi><mo>&sdot;</mo><msub><mi>h</mi><mn>2</mn></msub><mo>(</mo><mi>v</mi><mo>)</mo>
 *   <mo>)</mo><mspace width="0.6em" /><mo>mod</mo><mspace width="0.3em" /><mo>|T|</mo>
 *  </mrow>
 * </math>
 * We convert each hash value from the hash functions, h(v), to a decimal number to get an index.
 * It is possible for the hash functions to return zero. That doesn't matter for the first hash function, <em>h<sub>1</sub>(v)</em>, as we will still get different values.
 * But if the second hash function, <em>h<sub>2</sub>(v)</em>, evaluates to zero, the resulting sequence will always remain at the value of <em>h<sub>1</sub>(v)</em>.
 * One possible solution is to change the second function to
 * <math display="inline"><mi>i</mi><mo>&sdot;</mo><msub><mi>h</mi><mn>2</mn></msub><mo>(</mo><mi>v</mi><mo>)</mo><mo>+</mo><mn>1</mn></math>.
 * <h3>Example</h3>
 * <math display="block">
 *   <msub><mi>h</mi><mn>1</mn></msub><mo>(</mo><mi>v</mi><mo>)</mo><mo>=</mo><mn>24</mn><mspace width="1em" />
 *   <msub><mi>h</mi><mn>2</mn></msub><mo>(</mo><mi>v</mi><mo>)</mo><mo>=</mo><mn>16</mn><mspace width="1em" />
 *   <mi>i</mi><mo>=</mo><mn>4</mn><mspace width="1em" />
 *   <mi>T</mi><mo>=</mo><mn>55</mn>
 * </math>
 * <math display="block"><mi>i</mi><mo>:</mo><mn>0</mn><mspace width="1em" /><mn>24</mn><mo>+</mo><mo>(</mo><mn>0</mn><mo>&sdot;</mo><mn>16</mn><mo>+</mo><mn>1</mn><mo>)</mo><mo>=</mo><mn>25</mn><mspace width="1em" /><mo>mod</mo><mspace width="0.3em" /><mn>55</mn><mo>=</mo><mn>25</mn></math>
 * <math display="block"><mi>i</mi><mo>:</mo><mn>1</mn><mspace width="1em" /><mn>24</mn><mo>+</mo><mo>(</mo><mn>1</mn><mo>&sdot;</mo><mn>16</mn><mo>+</mo><mn>1</mn><mo>)</mo><mo>=</mo><mn>41</mn><mspace width="1em" /><mo>mod</mo><mspace width="0.3em" /><mn>55</mn><mo>=</mo><mn>41</mn></math>
 * <math display="block"><mi>i</mi><mo>:</mo><mn>2</mn><mspace width="1em" /><mn>24</mn><mo>+</mo><mo>(</mo><mn>2</mn><mo>&sdot;</mo><mn>16</mn><mo>+</mo><mn>1</mn><mo>)</mo><mo>=</mo><mn>57</mn><mspace width="1em" /><mo>mod</mo><mspace width="0.3em" /><mn>55</mn><mo>=</mo><mn>2</mn></math>
 * <math display="block"><mi>i</mi><mo>:</mo><mn>3</mn><mspace width="1em" /><mn>24</mn><mo>+</mo><mo>(</mo><mn>3</mn><mo>&sdot;</mo><mn>16</mn><mo>+</mo><mn>1</mn><mo>)</mo><mo>=</mo><mn>73</mn><mspace width="1em" /><mo>mod</mo><mspace width="0.3em" /><mn>55</mn><mo>=</mo><mn>18</mn></math>
 * </math>
 * Params:
 *  k = Number of hashes
 **/
mixin template doubleHash (alias size_t k) {
  /** Return number of hash functions **/
  @property functions () const { return k; }
  /** Hash engine
   *
   * Params:
   *  value = List of values as ubyte arrays
   * Returns: Array of decimal numbers
   **/
  private size_t[] hashEngine (ubyte[] value...) @system {
    import std.range: iota, array;
    import std.algorithm: map;
    //const auto h1 = hashes[0](value).bitsToNumber;
    const auto h1 = hashes[0](value).bytesToDec!(ubyte, ulong);
    //const auto h2 = hashes[1](value).bitsToNumber;
    const auto h2 = hashes[1](value).bytesToDec!(ubyte, ulong);
    return iota(0,k).map!(a => (h1 + (a * h2 + 1)) % size).array;
  }
}
