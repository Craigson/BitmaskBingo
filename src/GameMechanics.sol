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

    uint32[12] winningBingoMasks = [
        1082401, //  x0: 00000000000100001000010000100001
        2164802, //  x1: 00000000001000010000100001000010
        4329604, //  x2: 00000000010000100001000010000100
        8659208, //  x3: 00000000100001000010000100001000
        17318416, //  x4: 00000001000010000100001000010000
        31, //      y0: 00000000000000000000000000011111
        992, //     y1: 00000000000000000000001111100000
        31744, //   y2: 00000000000000000111110000000000
        1015808, // y3: 00000000000011111000000000000000
        32505856, // y4: 00000001111100000000000000000000
        17043521, // d0: 00000001000001000001000001000001
        1118480 // d1: 00000000000100010001000100010000
    ];
    

    /**
     *   @dev   Pure function doesn't read from, or write to, storage, making it
     *          very efficient. Only the value returned from the function is added
     *          to storage.
     */
    function createBingoCardForPlayer(uint256 _card, bytes32 _entropy)
        internal
        pure
        returns (uint256)
    {
        uint256 updatedCard = _card;
        uint256 len = 25;
        for (uint256 i; i < len; ++i) {
            uint256 rand = uint256(keccak256(abi.encode(_entropy, i))) % 255;
            updatedCard = StorageUtils.setBucketValueByIndex(
                updatedCard,
                i,
                rand
            );
        }
        return updatedCard;
    }

    function checkGameForPlayer(address _player, address[] memory _gamePlayers)
        internal
        pure
        returns (bool)
    {
        assembly {
            let player := _player
            let gamePlayers := _gamePlayers
            let len := mload(gamePlayers)
            let i := 0
            for { } lt(i, len) { i := add(i, 1) } {
                let playerAddress := mload(add(gamePlayers, mul(add(i, 1), 32)))
                if eq(playerAddress, player) {
                    return(1, 0)
                }
            }
            return(0, 0)
        }
    }

    function playerHasNumber(uint256[] memory _playerNumbers, uint256 _target)
        internal
        pure
        returns (bool, uint32)
    {
        uint256 len = _playerNumbers.length;
        for (uint256 i; i < len; ++i) {
            if (_playerNumbers[i] == _target) {
                return (true, uint32(i));
            }
        }

        return (false, uint32(99));
    }

    /**
     *  @dev    The array of integers returned will be in reverse order to how the bits
     *          are accessed.  When stored in the integer, they are accessed from right-to-left,
     *          but when they're converted to an integer array, they're read left-to-right. So the 5x5
     *          card of the binary representation has the 0th index at the bottom right, and the 24th index
     *          at the top left.  The decimal representation, ie. when rendering the number array, has
     *          the 0th element appears top-left, and the 24th element appears bottom right.
     */
    function getNumbersArrayForCard(uint256 _card)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory cardNumbers = new uint256[](25);
        uint256 len = 25;
        for (uint256 i; i < len; ++i) {
            cardNumbers[i] = StorageUtils.getBucketValueByIndex(_card, i);
        }
        return cardNumbers;
    }

    // TODO: must must must test if this returns it in the wrong order
    /**
     *  @dev    Returns an array of binary integers (0 or 1) representing
     *          the hit state by index.
     *  @dev    The array of integers returned will be in reverse order to how the bits
     *          are accessed.  When stored in the integer, they are accessed from right-to-left,
     *          but when they're converted to an integer array, they're read left-to-right. So the 5x5
     *          card of the binary representation has the 0th index at the bottom right, and the 24th index
     *          at the top left.  The decimal representation, ie. when rendering the number array, has
     *          the 0th element appears top-left, and the 24th element appears bottom right.
     */
    function getHitsArrayForCard(uint32 _hits)
        internal
        pure
        returns (uint256[] memory)
    {
        assembly {
            let hits := _hits
            let hitsArray := mload(0x40)
            mstore(hitsArray, 25)
            let len := 25
            let i := 0
            for { } lt(i, len) { i := add(i, 1) } {
                let bit := and(hits, 1)
                mstore(add(hitsArray, mul(add(i, 1), 32)), bit)
                hits := div(hits, 2)
            }
            return (hitsArray, 0)
        }
    }

    function checkCardForHit(uint256[] memory _playerIds, uint256 _target)
        internal
        pure
        returns (bool)
    {
        assembly { 
            let len := mload(_playerIds)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                if eq(mload(add(_playerIds, mul(add(i, 1), 32))), _target) {
                    return(1, 0)
                }
            }
            return(0, 0)
        }
    }

    // note: if the bitwise AND ( & ) between the players grid and the mask
    // is equal to the mask itself, then all the mask values must be present
    // meaning that the players grid contains a winning combination
    function checkForBingo(uint32[12] memory _hitMasks, uint32 _playerHits)
        internal
        pure
        returns (bool)
    {   
        assembly {
            let len := mload(_hitMasks)
            let mask := add(_hitMasks, 0x20)
            let end := add(mask, mul(len, 0x20))
            for { } lt(mask, end) { mask := add(mask, 0x20) } {
                if eq(and(mload(mask), _playerHits), mload(mask)) {
                    return(1, 0)
                }
            }
        }
    }

    
}
