/** **/
module extensions.algorithms.bloom.libbloom;
debug { import std.stdio; }

/** Bits to decimal number **/
size_t sumBits (bool[] bits) pure nothrow @safe @nogc {
  import std.algorithm: min;
  size_t numeral = 0;
  for (size_t i = 0; i < min(size_t.sizeof*8,bits.length); ++i) {
    if (bits[i]) numeral |= size_t(1) << (bits.length - 1 - i);
  }
  return numeral;
}
/** **/
unittest {
  assert(sumBits([0,0,0,1]) == 1);
  assert(sumBits([0,0,1,0]) == 2);
  assert(sumBits([0,0,1,1]) == 3);
  assert(sumBits([1,1,1,1]) == 15);
  assert(sumBits([1,1,1,1,1,1,1,1]) == 255);
  bool[size_t.sizeof*8] big = true;   // 64-bits all true
  bool[size_t.sizeof*8+1] bigger = true; // 65 bits all true
  assert(sumBits(big) == size_t.max);
  assert(sumBits(bigger) == size_t.max);

}
/** Bit addition
 *
 * Returns true if no overflow occured, otherwise false
 **/
package bool addition (bool[] a, bool[] b, out bool[] result) pure nothrow @safe {
  import std.algorithm: max, swap;
  bool carry = false;
  if (a.length != b.length) {
    if (a.length < b.length) { swap(a,b); }
    // at this point a is always longer than b
    bool[] c;
    c.length = a.length-b.length;
    b = c ~ b;
    // at this point a and b have same length
  }
  result.length = a.length;
  for (size_t i=a.length-1; i!=-1; i--) {
    result[i] = (a[i]^b[i])^carry;
    carry = (a[i]&b[i]) || (carry && (a[i] != b[i]));
  }
  return !carry;
}
unittest {
  bool[] result;
  addition([0,1,0,1],[0,0,0,1], result);
  assert(addition([0,0,0,0],[0,0,0,0], result) && result == [0,0,0,0]);
  assert(addition([0,0,0,0],[0,0,0,1], result) && result == [0,0,0,1]);
  assert(addition([0,0,0,1],[0,0,0,1], result) && result == [0,0,1,0]);
  assert(!addition([1,1,1,1],[0,0,0,1], result) && result == [0,0,0,0]);
}
unittest {
  bool[] result;
  assert(addition([0,1], [0,0,1,0], result) && result == [0,0,1,1]);
}

package bool subtraction (bool[] a, bool[] b, out bool[] result) {
  import std.range;
  import std.algorithm;
  bool[] complement;
  bool[] c = b.map!(a => a != true).array;
  addition(c, [0,0,0,1], complement);
  addition(a, complement, result);
  return true;
}
unittest {
  bool[] result;
  subtraction([0,0,1,1], [0,0,0,1], result);
  writefln ("result: %s", result);
}
/*******************
**    Raw math     *
********************
* n: capacity (expected number of elements)
* m: number of cells required
* k: optimal number of hash functions
* p: false-positive rate
**/
/** Number of bits in array needed **/
package double _m (T) (T n, double p) pure nothrow @safe @nogc
in {
  assert (n > 0);
  assert (0 <= p && p <= 1);
}
out (result) {
  assert (result > 0);
}
body {
  import std.math: ceil, log, pow;
  //return ceil((n * log(p)) / log(1 / pow(2, log(2))));
  return (n * log(p)) / log(1.0 / pow(2, log(2)));
}
/** Number of hash functions needed **/
package double _k (T) (T n, double m) pure nothrow @safe @nogc
in {
    assert (n > 0);
    assert (m > 0);
}
out (result) {
  assert (result > 0);
}
body {
  import std.math: log;
  return (m/n * log(2.0));
}
/** Number of elements that can be inserted  **/
package double _n (T,U) (T m, U k, double p) pure nothrow @safe @nogc
in {
  assert (m > 0);
  assert (k > 0);
  assert (0 <= p && p <= 1);
}
out (result) {
  assert (result > 0);
}
body {
  import std.math: log, exp;
  m = cast(double)m;
  k = cast(double)k;
  return (m / (-1.0 * k / log(1.0 - exp(log(p) / k))));
}
/** Probability of false positive **/
package double _p (T,U) (T n, U k, double m) pure nothrow @safe @nogc
in {
  assert (n > 0);
  assert (k > 0);
  assert (m > 0);
}
out (result) {
  assert (0 <= result && result <= 0);
}
body {
  import std.math: log, pow, exp, E;
  return pow(1.0 - pow(E,(k*n/m)*-1.0), k);
}
//* reduce ubyte[] to decimal (ulong)
deprecated ("use the one from conv.bits!") package ulong bitsToNumber (ubyte[] u) {
  ulong a;
  auto i = 0;
  while (i<u.length) {
    a |= (u[i] & 0xff) << 8*(u.length-i-1);
    i++;
  }
  return a;
}
/** **/
ubyte[] md5 (ubyte[] s...) @system pure nothrow {
  import std.digest.md;
  import std.array: array;
  MD5 md;
  md.start();
  md.put(s);
  return md.finish.array;
}
/** **/
@system nothrow pure unittest {
  assert (md5(cast(ubyte[])"horse").length != 0);
  assert (md5(cast(ubyte[])"rat") == md5(cast(ubyte[])"rat"));
  assert (md5(cast(ubyte[])"cat") != md5(cast(ubyte[])"dog"));
}
/** **/
ubyte[] murmur (ubyte[] s...) @system pure nothrow {
  import std.digest.murmurhash;
  import std.array: array;
  MurmurHash3!32 murmur;
  murmur.start();
  murmur.put(s);
  return murmur.finish.array;
}
/** **/
@system pure nothrow unittest {
  assert (murmur(cast(ubyte[])"kipepeo") == murmur(cast(ubyte[])"kipepeo"));
  assert (murmur(cast(ubyte[])"hippo") != murmur(cast(ubyte[])"lion"));
}
/** **/
ubyte[] crc (ubyte[] s) @system pure nothrow {
  import std.digest.crc;
  import std.array: array;
  CRC32 crc;
  crc.start();
  crc.put(s);
  return crc.finish.array;
}
/** **/
@system pure nothrow unittest {
  assert (crc(cast(ubyte[])"snake") == crc(cast(ubyte[])"snake"));
  assert (crc(cast(ubyte[])"parrot") != crc(cast(ubyte[])"sparrow"));
}
unittest {
  assert(md5(cast(ubyte[])"turtle") != murmur(cast(ubyte[])"turtle"));
  assert(murmur(cast(ubyte[])"turtle") != crc(cast(ubyte[])"turtle"));
}
