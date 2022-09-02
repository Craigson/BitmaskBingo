// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "./utils/StorageUtils.sol";

// TODO: change name or to a library
abstract contract GameMechanics {
    // Storage utils leverage bitwise operations for efficient
    // creating efficient storage mechanisms

    using StorageUtils for *;

    // structs
    struct GlobalGameSettings {
        uint256 entryFee;
        uint256 minimumTurnDuration;
        uint256 minimumJoinDuration;
    }

    struct BingoCard {
        uint256 numberStorage;
        uint32 hitStorage;
    }

    // We know that `lastDrawnNumber` will always be 0-255, so use 999 + 1000 to
    // to represent initial and finished states

    /**
     *   @dev We make use of uint64 to leverage struct packing to reduce teh number of
     *        storage slots.  The token currency has a max supply ( type(uint64.max)), and
     *        storing timestamps as uint64 gives us 100+ years;
     */
    struct Game {
        uint64 lastDrawnNumber; // waiting: 99, drawing: 0-255, finished: 1000
        uint64 lastDrawnAt;
        uint64 prizePool;
        uint64 createdAt;
    }

    /*  
        
        In order to assess whether a player has 'Bingo', we apply
        a mask to the bits that represent the player's board hits.
        If the result of the bitwise & equals the mask itself, then
        we know that the player had a row, column, or diagonal with
        all the tiles covered.
        
                24 23 22 21 20  --  y4
                19 18 17 16 15  --  y3
                14 13 12 11 10  --  y2
                9  8  7  6  5   --  y1
                4  3  2  1  0   --  y0
                
            /   |  |  |  |  |   \ 
        d1                      d0
                x  x  x  x  x
                4  3  2  1  0

        Eg. x0
        0  0  0  0  1        
        0  0  0  0  1
        0  0  0  0  1
        0  0  0  0  1
        0  0  0  0  1
        0  0  0  0  1

        represented in binary as:   0000000 | 00001 00001 00001 00001 00001

                          uint32:   |__7__|   |_____________25____________|

                    or decimal:     1082401
    */

    function createBingoCardForPlayer(uint256 _card, bytes32 _entropy)
        internal
        pure
        returns (uint256)
    {
        uint256 updatedCard = _card;
        for (uint256 i; i < 25; ++i) {
            uint256 rand = uint256(keccak256(abi.encode(_entropy, i))) % 255;
            updatedCard = StorageUtils.setBucketValueByIndex(
                updatedCard,
                i,
                rand
            );
        }
        return updatedCard;
    }
}
