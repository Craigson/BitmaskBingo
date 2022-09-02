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
