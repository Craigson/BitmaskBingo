// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IBitmaskBingo {
    function createGame() external returns (bytes32 gameId);

    function joinGame(bytes32 _gameId) external;
}
