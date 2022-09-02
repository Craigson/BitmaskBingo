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

    // game data
    uint256 initialEntryFee = 1000;

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

    // TODO: add more settings tests
    function test_updateGameSettings_asAdmin() public {
        bingoGameContract.updateEntryFee(initialEntryFee * 2);
        (uint256 updatedFee, , ) = bingoGameContract.getGameSettings();
        assertEq(updatedFee, initialEntryFee * 2);
    }

    // ================================ C R E A T E  G A M E
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

        // TODO: check for emit
        emit log_named_bytes32("Game ID", gameId);
        vm.stopPrank();
    }

    // ================================ J O I N  G A M E

    function testFail_joinGameEarly_asPlayerTwo() public {
        // get the game ID created by the other player
        bytes32 gameIdToJoin = playerToCreatedGameIds[playerOne];
        emit log_named_bytes32("game id to join: ", gameIdToJoin);
        // TODO: get joinFee from contract

        vm.startPrank(playerTwo);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bingoGameContract.joinGame(gameIdToJoin);
    }

    // test creating a game without sufficient funds for entry fee
    function testFail_createGame_asPlayerWithoutBalance() public {
        vm.startPrank(playerWithoutFunds);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bytes32 gameId = bingoGameContract.createGame();

        vm.stopPrank();
    }

    function test_createMultipleGames_asPlayerOne() public {
        vm.startPrank(playerOne);

        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee * 4
        );
        assertTrue(success);

        // games cannot share an ID, so TX must be in different blocks
        bytes32 gameIdOne = bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bytes32 gameIdTwo = bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bytes32 gameIdThree = bingoGameContract.createGame();
        vm.roll(block.number + 1);

        bytes32 gameIdFour = bingoGameContract.createGame();
        vm.roll(block.number + 1);

        vm.stopPrank();
    }

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
        // TODO: expect Transfer

        vm.stopPrank();

        // check player balance decreased
        assertEq(
            playerTwoBalanceBefore,
            playerTwoBalanceAfter + initialEntryFee
        );

        // check prizepool increased
        assertEq(prizePoolBefore + initialEntryFee, prizePoolAfter);
    }

    function playerCreateGame(address player) internal returns (bytes32) {
        vm.startPrank(player);

        // approve the token spend before we can join
        bool success = token.approve(
            address(bingoGameContract),
            initialEntryFee
        );
        assertTrue(success);

        bytes32 gameId = bingoGameContract.createGame();
        playerToCreatedGameIds[player] = gameId;

        // TODO: check for emit
        emit log_named_bytes32("Game ID", gameId);
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
