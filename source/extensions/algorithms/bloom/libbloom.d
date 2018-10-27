/** **/
module extensions.algorithms.bloom.libbloom;

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
ubyte[] md5 (ubyte[] s) @system pure nothrow {
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
ubyte[] murmur (ubyte[] s) @system pure nothrow {
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
