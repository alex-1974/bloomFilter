/** Various bloom filter implementations


A Bloom filter is a space-efficient probabilistic data structure that is used
to test whether an element is a member of a set. False positive matches are possible,
but false negatives are not – in other words, a query returns either <em>possibly in set</em> or <em>definitely not in set</em>.

<h2>Size of the filter</h2>

If we want a filter for 100.000 Elements and accept a false-positive rate of 1% we need 960.000 bits (117KiB), thats about 9,6 bits/element.
The 1% false-positive rate can be further reduced by a factor of ten by adding only about 4,8 bits per element
(100.000 elements at 0,1% false-positive with filter size of 1437759 bits (175,51KiB), approx. 14,4 bits/element).

how many bits in array?
A larger filter will have less false positives

<h2>Hash functions</h2>

Basic requirements:
<ul>
 <li>Easy and fast to compute</li>
 <li>Collisions don't really matter</li>
 <li>It is more important that they are evenly and randomly distributed</li>
</ul>
class vs struct
Structs are value-typed therefore faster than the referenced-type classes

<h3>How many hash functions?</h3>
The more, the slower the bloom filter, and the quicker it fills up. Too few may suffer from too many false positiv.

<h2>Math</h2>
*
* <ul><li>The number of required bits
* <math mode="display" display="inline"" xmlns="http://www.w3.org/1998/Math/MathML"><mrow>
*  <mi>m</mi> <mo>=</mo> <mo>-</mo>
*  <mfrac>
*  <mrow><mi>n</mi> <mi>ln</mi> <mi>p</mi></mrow>
*  <mrow><msup>
*   <mrow><mo> ( </mo><mi>ln</mi><mn>2</mn><mo> ) </mo></mrow>
*   <mn>2</mn>
*  </msup></mrow>
*  </mfrac>
* </mrow></math>
* </li>
* <li>The number of required hash functions
* <math mode="display" display="inline"" xmlns="http://www.w3.org/1998/Math/MathML"><mrow>
*  <mi>k</mi><mo>=</mo>
*  <mfrac><mi>m</mi><mi>n</mi></mfrac>
*  <mi>ln</mi><mn>2</mn>
* </mrow></math>
* </li>
* <li>The probability of false positives
* <math mode="display" display="inline"" xmlns="http://www.w3.org/1998/Math/MathML">
* <mi>p</mi> <mo>&#8776;</mo>
* <mrow>
*  <msup>
*   <mrow><mo> ( </mo> <mn>1</mn><mo>-</mo>
*    <mrow><msup>
*    <mi>e</mi>
*    <mfrac><mrow><mo>-</mo><mi>k</mi><mi>n</mi></mrow><mrow><mi>m</mi></mrow></mfrac>
*    </msup></mrow>
*   <mo> ) </mo></mrow>
*   <mrow><mi>k</mi></mrow>
*  </msup></mrow>
* </math>
* </li>
* </ul>
* See:
* <ul>
*  <li><a href="http://matthias.vallentin.net/blog/2011/06/a-garden-variety-of-bloom-filters/">A garden variety of bloom filters</a></li>
*  <li><a href="https://en.wikipedia.org/wiki/Bloom_filter">Wikipedia: Bloom filter</a></li>
*  <li><a href="https://www.hackerearth.com/practice/data-structures/hash-tables/basics-of-hash-tables/tutorial/">Basics of hash tables</a></li>
*  <li><a href="https://stackoverflow.com/questions/658439/how-many-hash-functions-does-my-bloom-filter-need">How many hash functions does my bloom filter need</a></li>
* </ul>
*
* Authors: Alexander Leisser, (alex.leisser@gmail.com)
* Version: 1.0alpha
* History:
*  1.0alpha initial version
* Copyright: Alexander Leisser
* License: <a href="https://www.gnu.org/licenses/gpl-3.0.html">GPL-3.0</a>
**/
module extensions.algorithms.bloom;

public import extensions.algorithms.bloom.common;
