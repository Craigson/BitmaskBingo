// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../src/GameMechanics.sol";

import "forge-std/Test.sol";
import "ds-test/test.sol";

//
//
//

/**
 * @dev This contract tests the game logic for scoring and winning at onchain Bingo
 *      We won't be deploying any contracts, just inheriting from the GameMechanics
 *      and testing them
 */
contract GameLogicTest is Test, GameMechanics {
    /*
        We'll use the bingo numbers as tests to create our usescases:
        
                24 23 22 21 20  --  y4
                19 18 17 16 15  --  y3
                14 13 12 11 10  --  y2
                9  8  7  6  5   --  y1
                4  3  2  1  0   --  y0
                
            /   |  |  |  |  |   \ 
        d1                      d0
                x  x  x  x  x
                4  3  2  1  0

        Eg. A bingo card with hits on numbers 24, 23, 22, 21, and 20

        [24] [23] [22] [21] [20]   <== y4
        19    18   17   16   15
        14    13   12   11   10
        9     8    7    6    5
        4     3    2    1    0 

        would need to correspond to hitmask (see GameMechanics.sol):
        32505856, // y4: 00000001111100000000000000000000
    */

    uint256 cardNumberStorage;

    uint256[] cardNumbers;

    uint256[] x0 = [0, 5, 10, 15, 20];
    uint256[] x1 = [1, 6, 11, 16, 21];
    uint256[] x2 = [2, 7, 12, 17, 22];
    uint256[] x3 = [3, 8, 13, 18, 23];
    uint256[] x4 = [4, 9, 14, 19, 24];
    uint256[] y0 = [0, 1, 2, 3, 4];
    uint256[] y1 = [5, 6, 7, 8, 9];
    uint256[] y2 = [10, 11, 12, 13, 14];
    uint256[] y3 = [15, 16, 17, 18, 19];
    uint256[] y4 = [20, 21, 22, 23, 24];
    uint256[] d0 = [0, 6, 12, 18, 24];
    uint256[] d1 = [4, 8, 12, 16, 20];

    /*
        24   [23] [22] [21] [20]
       [19]   18  [17]  16  [15]
        14    13  [12]  11  10
        9    [8]   7    6   [5]
       [4]    3    2    1   [0] 
    */
    uint256[] failRandom = [23, 22, 21, 20, 19, 17, 15, 12, 8, 5, 4, 0];

    constructor() {
        uint256 temp = uint256(0);
        for (uint256 i; i < 25; ++i) {
            temp = StorageUtils.setBucketValueByIndex(temp, i, i);
        }

        cardNumberStorage = temp;
        cardNumbers = getNumbersArrayForCard(temp);
    }

    // test the columns
    function test_x0() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < x0.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, x0[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_x1() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < x1.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, x1[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_x2() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < x2.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, x2[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_x3() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < x3.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, x3[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_x4() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < x4.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, x4[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    // test the rows
    function test_y0() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < y0.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, y0[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_y1() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < y1.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, y1[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_y2() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < y2.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, y2[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_y3() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < y3.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, y3[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    // test the diagonals

    function test_d0() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < d0.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, d0[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    function test_d1() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < d1.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(numbers, d1[i]);
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertTrue(isWinner);
    }

    // test not winning

    function testNotWinner() public {
        uint32 hits = uint32(0);
        uint256[] memory numbers = cardNumbers;
        bool isWinner;
        for (uint256 i; i < failRandom.length; ++i) {
            (bool hasNumber, uint32 location) = playerHasNumber(
                numbers,
                failRandom[i]
            );
            require(hasNumber, "something went wrong");
            hits = StorageUtils.setBitValueByIndex(hits, location);
            uint32[12] memory bingoHitMasks = winningBingoMasks;
            isWinner = checkForBingo(bingoHitMasks, hits);
        }
        assertFalse(isWinner);
    }
}
