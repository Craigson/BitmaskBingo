# Bitmask Bingo

## Installation

`forge install`

## Testing

Foundry will print out logs (emitted events) from the tests and present a gas report.

`forge test -vv --gas-report`

## Requirements

-   [] Support multiple players in a game
-   [] Support multiple concurrent games
-   [] Each player pays an ERC20 entry fee, transferred on join
-   [] Winner wins the pot of entry fees, transferred on win
-   [] Games have a minimum join duration before start
-   [] Games have a minimum turn duration between draws
-   [] Admin can update the entry fee, join duration, and turn duration
-   [] Interface exposing a public API (including getters and events) for a dApp to render current **and** historial game state
-   [] summary of worst-case gas costs

### Optimizing storage using bitwise operations

To optimize for gas usage, we want to limit the number of `SLOAD` and `SSTORE` operations. To achieve this, we'll be storing the player's card ( a 5x5 grid of tiles, with each tile holding a uint8 in the range 0-255 ). We'll also store separately the "state" of each tile in the grid, ie. whether or not it's been hit ( `0` for open and `1` for hit ) as single bits. We'll make use of bitwise operations to read and write the values in each tile.

Because bits are read right to left, we'll use the bottom-right tile as the `0` index. The Tile indices look as follows:

```
Tile Indices:

24 23 22 21 20
19 18 17 16 15
14 13 12 11 10
9  8  7  6  5
4  3  2  1  0

```

This means we can store all 25 of the `uint8` tile values in a single `uint256`. This new `storageContainer` has a total of 32 `buckets`, where each bucket is `8` bits in size ( `32 * 8 = 256` ). Because we only require 25 buckets to store our game board, we'll simply ignore the left-most 7 buckets. The layout in binary representation would look something like:

```
0000000011111111...00000000
|__31__||__30__|   |___0__|
```

We can take the same approach to storing the hits/misses of the game board, represented as `0`s and `1`s, corresponding to the same bit indices ( read right-to-left ) as the bingo numbers. Because we require only 25 bits for this, we can store the hits in a `uint32`.

```
Eg.

grid:
0  0  0  0  1
0  0  0  0  1
0  0  0  0  1
0  0  0  0  1
0  0  0  0  1

take the right-most 25 bits:
0000000 | 00001 00001 00001 00001 00001
|_ 7 _|   |____________ 25 ___________|

represented in binary as:
00000000000100001000010000100001

which gives a decimal value of:
uint32 column = 1082401;

```
