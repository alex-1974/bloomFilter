/** Various bloom filter implementations
*
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
* <ul>
*  <li><a href="http://matthias.vallentin.net/blog/2011/06/a-garden-variety-of-bloom-filters/">A garden variety of bloom filters</a></li>
*  <li><a href="https://en.wikipedia.org/wiki/Bloom_filter">Wikipedia: Bloom filter</a></li>
*  <li><a href="https://www.hackerearth.com/practice/data-structures/hash-tables/basics-of-hash-tables/tutorial/">Basics of hash tables</a></li>
*  <li><a href="https://stackoverflow.com/questions/658439/how-many-hash-functions-does-my-bloom-filter-need">How many hash functions does my bloom filter need</a></li>
* </ul>
**/
module extensions.algorithms.bloom;

public import extensions.algorithms.bloom.common;
//private import extensions.algorithms.bloom.libbloom;
