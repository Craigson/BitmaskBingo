// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "ds-test/test.sol";
import "../src/BitmaskBingo.sol";
import "../src/BingoToken.sol";

contract BitmaskBingoTest is Test {
    struct GlobalGameSettings {
        uint256 initialEntryFee;
        uint256 minimumTurnDuration;
        uint256 minimumJoinDuration;
    }

    // contracts
    BitmaskBingo bingoGameContract;
    BingoToken token;

    // players
    address playerOne = address(99);
    address playerTwo = address(100);
    address playerThree = address(101);
    address playerWithoutFunds = address(102);

    address[] multiWinners;

    // game data
    uint256 initialEntryFee = 1000;

    // we cannot access event data, so store a reference to games for testing purposes
    mapping(address => bytes32) playerToCreatedGameIds;

    constructor() {
        // deploy the token
        token = new BingoToken();

        // deploy the game contract
        bingoGameContract = new BitmaskBingo(address(token));

        // supply each player with 10k tokens
        token.mint(playerOne, initialEntryFee * 10);
        token.mint(playerTwo, initialEntryFee * 10);
    }

    function test_correctOpeningBalances() public {
        assertEq(token.balanceOf(playerOne), initialEntryFee * 10);
        assertEq(token.balanceOf(playerTwo), initialEntryFee * 10);
    }

    // ================================ A D M I N  T E S T S

    function test_updateGameSettings_asAdmin() public {
        uint256 newEntryFee = initialEntryFee * 2;
        uint256 newJoinDuration = 2 hours;
        uint256 newTurnDuration = 10 minutes;
        bingoGameContract.updateEntryFee(newEntryFee);
        bingoGameContract.updateJoinDuration(newJoinDuration);
        bingoGameContract.updateUpdateTurnDuration(newTurnDuration);

        (
            uint256 updatedFee,
            uint256 updatedTurnDuration,
            uint256 updatedJoinDuration
        ) = bingoGameContract.getGameSettings();

        assertEq(updatedFee, newEntryFee);
        assertEq(newJoinDuration, updatedJoinDuration);
        assertEq(newTurnDuration, updatedTurnDuration);
    }

    // ================================ C R E A T E  G A M E

    // test creating a game by a player with sufficient funds for the entry fee
    function test_createGame_asPlayerOne() public {
        vm.startPrank(playerOne);

        // approve the token spend before we can join
        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bytes32 gameId = bingoGameContract.createGame();
        playerToCreatedGameIds[playerOne] = gameId;

        emit log_named_bytes32("Game ID", gameId);
        vm.stopPrank();
    }

    // test creating a game without sufficient funds for entry fee
    function testFail_createGame_asPlayerWithoutBalance() public {
        vm.startPrank(playerWithoutFunds);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bingoGameContract.createGame();

        vm.stopPrank();
    }

    // test single player creating multiple concurrent games
    function test_createMultipleGames_asPlayerOne() public {
        vm.startPrank(playerOne);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee * 4
        );
        assertTrue(success);

        // games cannot share an ID, so TX must be in different blocks
        bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bingoGameContract.createGame();
        vm.roll(block.number + 1);

        vm.stopPrank();
    }

    // ================================ J O I N  G A M E

    // test joining a game, user token balance decreasing, and prize pool balance increasing
    function test_joinGame_asPlayerTwo() public {
        // advance the block number to ensure different bingo card
        vm.warp(block.timestamp + 2 hours);

        // get the game ID created by the other player
        bytes32 gameIdToJoin = playerCreateGame(playerOne);

        vm.startPrank(playerTwo);
        uint256 playerTwoBalanceBefore = token.balanceOf(playerTwo);
        (, , uint256 prizePoolBefore, ) = bingoGameContract.getGameById(
            gameIdToJoin
        );
        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bingoGameContract.joinGame(gameIdToJoin);
        uint256 playerTwoBalanceAfter = token.balanceOf(playerTwo);
        (, , uint256 prizePoolAfter, ) = bingoGameContract.getGameById(
            gameIdToJoin
        );

        vm.stopPrank();

        // check player balance decreased
        assertEq(
            playerTwoBalanceBefore,
            playerTwoBalanceAfter + initialEntryFee
        );

        // check prizepool increased
        assertEq(prizePoolBefore + initialEntryFee, prizePoolAfter);
    }

    // test joining a game after the join period has expired
    function testFail_joinGameLate_asPlayerThree() public {
        vm.warp(block.timestamp + 2 hours);
        // get the game ID created by the other player
        bytes32 gameIdToJoin = playerToCreatedGameIds[playerOne];

        vm.startPrank(playerThree);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bingoGameContract.joinGame(gameIdToJoin);
    }

    // test joining a game that doesn't exist
    function testFail_joinNonExistingGame_asPlayerOne() public {
        bytes32 nonExistentId = keccak256(abi.encode(playerOne));

        vm.startPrank(playerOne);
        bingoGameContract.joinGame(nonExistentId);
    }

    // ================================ P L A Y I N G  A  G A M E

    // test a complete game between two players
    function test_playGame_asTwoPlayers() public {
        // create a game
        bytes32 id = playerCreateGame(playerOne);
        vm.roll(block.number + 1);

        // join the game
        playerJoinGame(id, playerTwo);

        uint256[] memory playerOneCardNumbers = bingoGameContract
            .getPlayerCardNumbersForGame(playerOne, id);
        uint256[] memory playerTwoCardNumbers = bingoGameContract
            .getPlayerCardNumbersForGame(playerTwo, id);

        vm.warp(block.timestamp + 65 minutes);

        bool hasWinner;
        uint256 iterations;
        address winner;

        // reasoanble to assume that within 500 turns one of the players will get Bingo
        for (uint256 i; i < 500; ++i) {
            // alternate between players picking a card
            address playerToDraw = i % 2 == 0 ? playerOne : playerTwo;
            vm.prank(playerToDraw);
            bingoGameContract.drawNumber(id);
            uint256 latest = bingoGameContract.getLastDrawnNumberForGame(id);

            // player one
            vm.startPrank(playerOne);

            bool shouldClaimOne = playerHasNumber(playerOneCardNumbers, latest);
            if (shouldClaimOne) {
                bingoGameContract.markNumberOnCard(id);
                hasWinner = bingoGameContract.checkForWinner(playerOne, id);

                if (hasWinner) {
                    emit log_string("Player One wins!");
                    iterations = i;
                    winner = playerOne;
                    break;
                }
            }
            vm.stopPrank();

            // player two
            vm.startPrank(playerTwo);

            bool shouldClaimTwo = playerHasNumber(playerTwoCardNumbers, latest);
            if (shouldClaimTwo) {
                bingoGameContract.markNumberOnCard(id);
                hasWinner = bingoGameContract.checkForWinner(playerTwo, id);
                if (hasWinner) {
                    emit log_string("Player Two wins!");
                    iterations = i;
                    winner = playerTwo;
                    break;
                }
            }
            vm.stopPrank();
            vm.warp(block.timestamp + 7 minutes);
            vm.roll(block.timestamp + 1);
        }

        if (!hasWinner)
            revert(
                "Could not find a winner: try increasing iterations of loop"
            );

        (, , uint256 gamePrizeBefore, ) = bingoGameContract.getGameById(id);

        uint256 winnerBalanceBeforeClaiming = token.balanceOf(winner);
        bool success = bingoGameContract.claimPrize(id);
        assertTrue(success);
        uint256 winnerBalanceAfterClaiming = token.balanceOf(winner);
        (, , uint256 gamePrizeAfter, ) = bingoGameContract.getGameById(id);
        assertEq(
            winnerBalanceAfterClaiming,
            winnerBalanceBeforeClaiming + gamePrizeBefore
        );
        assertEq(gamePrizeAfter, 0);
    }

    // ================================= H E L P E R S

    // convenience function to create a game
    function playerCreateGame(address player) internal returns (bytes32) {
        vm.startPrank(player);

        // approve the token spend before we can join
        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bytes32 gameId = bingoGameContract.createGame();
        vm.expectEmit(true, true, false, false);

        playerToCreatedGameIds[player] = gameId;

        vm.stopPrank();

        return gameId;
    }

    // convenience function for joining a game
    function playerJoinGame(bytes32 id, address player) internal {
        vm.startPrank(player);

        uint256 initialContractBalance = token.balanceOf(
            address(bingoGameContract)
        );

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bingoGameContract.joinGame(id);

        assertEq(
            initialContractBalance + initialEntryFee,
            token.balanceOf(address(bingoGameContract))
        );

        vm.stopPrank();
    }

    // check a player's card contains a rumber
    function playerHasNumber(uint256[] memory _playerIds, uint256 _target)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < _playerIds.length; ++i) {
            if (_playerIds[i] == _target) return true;
        }

        return false;
    }
}
