/** The high-level API
*
* Authors: Alexander Leisser, (alex.leisser@gmail.com)
* Version: 1.0alpha
* History:
*  1.0alpha initial version
* Copyright: Alexander Leisser
* License: <a href="https://www.gnu.org/licenses/gpl-3.0.html">GPL-3.0</a>
**/
module extensions.algorithms.bloom.common;

import extensions.algorithms.bloom.libbloom;
import extensions.algorithms.bloom.classes;

debug { import std.stdio; }

/** **/
auto basicBloomFilter (size_t capacity, double fp) () {}

/** **/
auto a2BloomFilter (size_t capacity, double fp) () {
  enum size_t requiredCells = numberOfBits(capacity, fp);
  enum size_t  optimalK = numberOfHashFunctions(capacity, requiredCells);
  writefln ("required cells %s optimal k %s", requiredCells, optimalK);
  return new a2Filter!(capacity, requiredCells,optimalK)(&md5, &murmur);
}
/** **/
unittest {
  auto a2 = a2BloomFilter!(1000, 0.01);
}

/** **/
auto countingBloomFilter (size_t capacity, double fp) () {

}

version(old) {
/** **/
class baseBloom (T) {
  import std.range: InputRange;
  alias hashFunc = ubyte[] function(T);
  private bool[] bitArray;
  private hashFunc[] hashArray;

  this (size_t bits) {
    bitArray.length = bits;
  }
  import std.traits;

  /** **/
  final void add (T) (T[] value...) if (isSomeString!T) {
    import std.range: array, tee;
    value.tee!(a => add(a)).array;
  }
  /** **/
  final void add (T) (T[] value...) if (isSomeChar!T) {
    import std.range: tee, array;
    hashEngine(value).tee!(a => bitArray[a] = true).array;
  }

  /** **/
  final bool check (T) (T[] value...) if (isSomeChar!T) {
    import std.range;
    import std.algorithm;
    return hashEngine(value).map!(a => bitArray[a]).all!"a == true";
  }
  /** **/
  final bool check (T) (T[] value...) if (isSomeString!T) {
    import std.range;
    import std.algorithm;
    return value.map!(a => check(a)).all!"a == true"; // all values must be found to return true
  }

  abstract InputRange!size_t hashEngine (T value);

  // helper functions
  private void addHash (hashFunc[] fun ...) { hashArray ~= fun; }
  /** **/
  private void setFilterArray (InputRange!bool filter) { import std.array: array; this.bitArray = filter.array; }
  /** **/
  InputRange!bool getFilterArray () {
    import std.range: inputRangeObject;
    return bitArray.inputRangeObject;
  }
}

/** **/
class DoubleBloom (T) : baseBloom!T {
  private size_t numberOfHashes;
  /** **/
  this (size_t bits, size_t hash, hashFunc func1, hashFunc func2) {
    super(bits);
    numberOfHashes = hash;
    addHash(func1,func2);
  }
  override InputRange!size_t hashEngine (T value) @system {
    import std.range;
    import std.algorithm;
    auto h1 = hashArray[0](value).bitsToNumber;
    auto h2 = hashArray[1](value).bitsToNumber;
    return iota(0,numberOfHashes).map!(a => (h1 + a * h2) % bitArray.length).inputRangeObject;
  }
}
/** **/
unittest {
  size_t elements = 1000;
  size_t hashes = 7;
  auto hashFuncs = [&md5,&murmur];
  auto bf = new DoubleBloom!string(elements,hashes, &md5,&murmur);
  bf.add("cat");
  writefln ("check cat: %s", bf.check("cat"));
  writefln ("check dog: %s", bf.check("dog"));
}
} // end version(old)

//* reduce ubyte[] to decimal (ulong)
private ulong bitsToNumber (ubyte[] u) {
  ulong a;
  auto i = 0;
  while (i<u.length) {
    a |= (u[i] & 0xff) << 8*(u.length-i-1);
    i++;
  }
  return a;
}

/** Returns number of bits needed for the bloom filter
 *
 * Params:
 *  elements = Number of elements the filter should handle
 *  probability = Allowed probability for false positive
 * Returns:
 *  Number of bits needed (aka length of bitArray)
 **/
ulong numberOfBits (T) (T elements, double probability) pure nothrow @safe @nogc {
  import std.math: ceil;
  return cast(size_t)( ceil( _m(elements,probability)) );
}

/** Returns number of hash functions needed **/
ulong numberOfHashFunctions (T,U) (T elements, U bits) pure nothrow @safe @nogc {
  import std.math: round;
  return cast(size_t)round( _k(elements, bits));
}
/** Number of elements, that can be inserted **/
ulong numberOfElements (T,U) (T bits, U hashes, double probability) pure nothrow @safe @nogc {
  import std.math: ceil;
  return cast(ulong)( ceil( _n(bits, hashes, probability)) );
}
