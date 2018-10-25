/** **/
module extensions.algorithms.bloom.common;

import extensions.algorithms.bloom.libbloom;

/**
class vs struct
Structs are value-typed therefore faster than the referenced-type classes
for the hash functions:
* collisions don't really matter too timeStatusChanged
* it's more important that they are evenly and randomly distributed
* fast
* To get a single number from the hash we reduce the hash to a single decimal number
* and take the modulo from the bit array length
how many hash functions?
* The more, the slower the bloom filter, and the quicker it fills up. Too few may suffer from too many false positiv.
how many bits in array?
* A larger filter will have less false positives
* See:
* <a href="http://matthias.vallentin.net/blog/2011/06/a-garden-variety-of-bloom-filters/">A garden variety of bloom filters</a>
**/

debug { import std.stdio; }

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
  auto hashFuncs = [&md5!string,&murmur!string];
  auto bf = new DoubleBloom!string(elements,hashes, &md5!string,&murmur!string);
  bf.add("cat");
  writefln ("check cat: %s", bf.check("cat"));
  writefln ("check dog: %s", bf.check("dog"));
}

alias hashFunc(T) = ubyte[] function(T);
/** **/
auto doubleBloom (T) (bool[] bitArray, size_t numberOfHashFunc, hashFunc!T fun, hashFunc!T fun2) {
  auto r = new DoubleBloom!T(bitArray.length, numberOfHashFunc, fun,fun2);
  r.setFilterArray(bitArray);
}
/** **/
auto doubleBloom (T) (size_t elements, double falsePositive, hashFunc!T fun, hashFunc!T fun2) {
  auto b = numberOfBits(elements, falsePositive);
  auto r = new DoubleBloom!T(b,numberOfHashFunctions(elements, b), fun,fun2);
  return r;
}
/** **/
unittest {
  size_t elements = 1000;
  double probability = 0.01;
  auto db = doubleBloom!string(elements, probability, &md5!string, &murmur!string);
  // add values to the filter
  db.add("cat");
  db.add("dog", "zebra");
  db.add(["turtle", "parrot"]);
  // check if values are in the filter
  assert(db.check("cat"));
  // if more than one value is given to check, all of them must be found to return true
  assert(db.check("dog", "zebra"));
  assert(!db.check("snake", "zebra"));
}
class A2Bloom (T) : baseBloom!T {
  bool[] bitArray2;
}
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
  return cast(ulong)( ceil( _m(elements,probability)) );
}

/** Returns number of hash functions needed **/
ulong numberOfHashFunctions (T,U) (T elements, U bits) pure nothrow @safe @nogc {
  import std.math: round;
  return cast(ulong)round( _k(elements, bits));
}
/** Number of elements, that can be inserted **/
ulong numberOfElements (T,U) (T bits, U hashes, double probability) pure nothrow @safe @nogc {
  import std.math: ceil;
  return cast(ulong)( ceil( _n(bits, hashes, probability)) );
}
