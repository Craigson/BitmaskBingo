// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IBitmaskBingo {
    function createGame() external returns (bytes32 gameId);

    function joinGame(bytes32 _gameId) external;

    // ================================ A D M I N  F U N C T I O N S

    function updateEntryFee(uint256 _fee) external;

    function updateJoinDuration(uint256 _joinDuration) external;

    function updateUpdateTurnDuration(uint256 _turnDuration) external;
}
