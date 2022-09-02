// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBitmaskBingo.sol";

contract BitmaskBingo is GameMechanics, IBitmaskBingo {
    struct Game {
        uint64 lastDrawnNumber; // last drawn number - waiting: 99, drawing: 0-255, finished: 1000
        uint64 lastDrawnAt; // time of last drawn number
        uint64 prizePool; // supply of tokens in the prizepool
        uint64 createdAt; // time game was created
    }

    struct GlobalGameSettings {
        uint256 entryFee;
        uint256 minimumTurnDuration;
        uint256 minimumJoinDuration;
    }

    GlobalGameSettings gameSettings =
        GlobalGameSettings({
            entryFee: 1000,
            minimumJoinDuration: 1 hours,
            minimumTurnDuration: 5 minutes
        });

    // private
    address private immutable owner;
    address private immutable bingoToken;

    constructor(address _token) {
        owner = msg.sender;
        bingoToken = _token;
    }

    function createGame() external returns (bytes32 gameId) {
        GlobalGameSettings memory settings = gameSettings;
        uint256 joinFee = settings.entryFee;
        emit LogUint256(joinFee);

        // TODO: check, effects interaction?
        IERC20(bingoToken).transferFrom(msg.sender, address(this), joinFee);

        // generate a uuid for the game
        gameId = keccak256(abi.encode(blockhash(block.number - 1), msg.sender));

        // create the game
        Game memory newGame = Game({
            lastDrawnAt: uint64(block.timestamp),
            lastDrawnNumber: 999, // we haven't drawn any numbers yet
            prizePool: uint64(joinFee),
            createdAt: uint64(block.timestamp)
        });
    }

    function joinGame(bytes32 _gameId) external {
        Game memory gameJoined = gameRegistry[_gameId];

        GlobalGameSettings memory settings = gameSettings;
        require(
            block.timestamp <
                gameJoined.createdAt + settings.minimumJoinDuration,
            "joinGame: Game already started"
        );

        uint256 joinFee = gameSettings.entryFee;
        IERC20(bingoToken).transferFrom(msg.sender, address(this), joinFee);
    }
}
