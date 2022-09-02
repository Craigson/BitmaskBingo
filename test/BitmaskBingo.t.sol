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
}
