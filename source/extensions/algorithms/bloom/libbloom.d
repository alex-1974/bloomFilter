/** **/
module extensions.algorithms.bloom.libbloom;

/*******************
**    Raw math     *
*******************/

/** Number of bits in array needed **/
package double _m (T) (T n, double p) {
  import std.math: ceil, log, pow;
  //return ceil((n * log(p)) / log(1 / pow(2, log(2))));
  return (n * log(p)) / log(1.0 / pow(2, log(2)));
}
/** Number of hash functions needed **/
package double _k (T) (T n, double m) {
  import std.math: log;
  return (m/n * log(2.0));
}
/** Number of elements that can be inserted  **/
package double _n (T,U) (T m, U k, double p) {
  import std.math: log, exp;
  m = cast(double)m;
  k = cast(double)k;
  return (m / (-1.0 * k / log(1.0 - exp(log(p) / k))));
}
/** Probability of false positive **/
package double _p (T,U) (T n, U k, double m) {
  import std.math: log, pow, exp, E;
  return pow(1.0 - pow(E,(k*n/m)*-1.0), k);
}
//* reduce ubyte[] to decimal (ulong)
package ulong bitsToNumber (ubyte[] u) {
  ulong a;
  auto i = 0;
  while (i<u.length) {
    a |= (u[i] & 0xff) << 8*(u.length-i-1);
    i++;
  }
  return a;
}
/** **/
ubyte[] md5 (T) (T s) {
  import std.digest.md;
  import std.array: array;
  MD5 md;
  md.start();
  md.put(cast(ubyte[])s);
  return md.finish.array;
}
/** **/
unittest {
  assert (md5("horse").length != 0);
  assert (md5("rat") == md5("rat"));
  assert (md5("cat") != md5("dog"));
}
/** **/
ubyte[] murmur (T) (T s) {
  import std.digest.murmurhash;
  import std.array: array;
  MurmurHash3!32 murmur;
  murmur.start();
  murmur.put(cast(ubyte[])s);
  return murmur.finish.array;
}
/** **/
unittest {
  assert (murmur("kipepeo") == murmur("kipepeo"));
  assert (murmur("hippo") != murmur("lion"));
}
ubyte[] crc (T) (T s) {
  import std.digest.crc;
  import std.array: array;
  CRC32 crc;
  crc.start();
  crc.put(cast(ubyte[])s);
  return crc.finish.array;
}
/** **/
unittest {
  assert (crc("snake") == crc("snake"));
  assert (crc("parrot") != crc("sparrow"));
}
unittest {
  assert(md5("turtle") != murmur("turtle"));
  assert(murmur("turtle") != crc("turtle"));
}
