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

    address private immutable owner;
    address private immutable bingoToken; // ERC20

    // keep track of the games and the players
    mapping(bytes32 => Game) gameRegistry;
    mapping(address => mapping(bytes32 => BingoCard)) playerRegistry;

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

        gameRegistry[gameId] = newGame;

        uint256 playerNumbersForCard = createBingoCardForPlayer(
            uint256(0),
            blockhash(block.number - 1)
        );

        playerRegistry[msg.sender][gameId] = BingoCard({
            numberStorage: playerNumbersForCard, // single uint32 that stores all the tile numbers
            hitStorage: 4096 // uint32 ie 0000000|0000000000001000000000000 which has the middle tile (index 12) marked as "hit"
        });
    }

    function joinGame(bytes32 _gameId) external {
        Game memory gameJoined = gameRegistry[_gameId];
        require(
            gameJoined.lastDrawnNumber == 999,
            "joinGame: Game does not exist"
        ); // TODO: test

        GlobalGameSettings memory settings = gameSettings;
        require(
            block.timestamp <
                gameJoined.createdAt + settings.minimumJoinDuration,
            "joinGame: Game already started"
        );

        uint256 joinFee = gameSettings.entryFee;
        IERC20(bingoToken).transferFrom(msg.sender, address(this), joinFee);

        Game storage g = gameRegistry[_gameId];
        g.prizePool += uint64(joinFee);

        uint256 playerNumbersForCard = createBingoCardForPlayer(
            uint256(0),
            blockhash(block.number - 1)
        );

        playerRegistry[msg.sender][_gameId] = BingoCard({
            numberStorage: playerNumbersForCard, // single uint32 that stores all the card numbers
            hitStorage: 4096 // uint32 ie 0000000|0000000000001000000000000 which has the middle spot (index 12) marked as "hit"
        });
    }

    function drawNumber(bytes32 _gameId) external onlyPlayer(_gameId) {
        Game memory game = gameRegistry[_gameId];
        GlobalGameSettings memory settings = gameSettings;
        require(
            block.timestamp > game.createdAt + settings.minimumJoinDuration,
            "drawNumber: player are still joining"
        );
        require(
            block.timestamp > game.lastDrawnAt + settings.minimumTurnDuration,
            "drawNumber: turn duration pending"
        );

        uint256 random = uint256(
            keccak256(abi.encode(blockhash(block.number - 1)))
        ) % 256; // should this be 255

        game.lastDrawnNumber = uint64(random);
        game.lastDrawnAt = uint64(block.timestamp);

        gameRegistry[_gameId] = game;
    }

    function markNumberOnCard(bytes32 _gameId) external onlyPlayer(_gameId) {
        // get player card
        BingoCard memory playerCard = playerRegistry[msg.sender][_gameId];

        // get latest number
        Game memory game = gameRegistry[_gameId];
        uint256 lastDrawnNumber = game.lastDrawnNumber;
        uint256[] memory numbers = getNumbersArrayForCard(
            playerCard.numberStorage
        );
        (bool hasNumber, uint32 location) = playerHasNumber(
            numbers,
            lastDrawnNumber
        );
        require(hasNumber, "Player's card does not have last drawn number");
        uint32 playerCardHits = playerCard.hitStorage;

        // update the hit bitmap
        playerCardHits = StorageUtils.setBitValueByIndex(
            playerCardHits,
            location
        );

        playerCard.hitStorage = playerCardHits;

        playerRegistry[msg.sender][_gameId] = playerCard;
    }
}
