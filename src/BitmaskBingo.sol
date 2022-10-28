// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBitmaskBingo.sol";
import "./GameMechanics.sol";

contract BitmaskBingo is GameMechanics, IBitmaskBingo {
    // private
    address private immutable owner;
    address private immutable bingoToken;

    GlobalGameSettings gameSettings =
        GlobalGameSettings({
            entryFee: 1000,
            minimumJoinDuration: 1 hours,
            minimumTurnDuration: 5 minutes
        });

    // keep track of the players and the game
    mapping(bytes32 => Game) gameRegistry;
    mapping(address => mapping(bytes32 => BingoCard)) playerRegistry;

    // erros
    error GameDoesExist();
    error DuplicateGameId();
    error GameAlreadyStarted();
    error PlayerStillJoining(); // drawNumber: player are still joining
    error TurnDurationPending(); // drawNumber: turn duration pending
    error NotHaveNumber(); 
    error GameHasEnded();
    error PlayerIsNotAMember();
    error GameDoesNotExist();

    constructor(address _token) {
        owner = msg.sender;
        bingoToken = _token;
    }

    // ================================ P L A Y E R  F U N C T I O N S

    function createGame() external returns (bytes32 gameId) {
        GlobalGameSettings memory settings = gameSettings;
        uint256 joinFee = settings.entryFee;

        // this will revert if balances are not sufficient
        IERC20(bingoToken).transferFrom(msg.sender, address(this), joinFee);

        // generate a uuid for the game and check that it doesn't already exist so we cannot overwrite
        gameId = keccak256(abi.encode(blockhash(block.number - 1), msg.sender));
        if(gameRegistry[gameId].createdAt == 0){ revert DuplicateGameId();}

        // create the game
        Game memory newGame = Game({
            lastDrawnAt: uint64(block.timestamp),
            lastDrawnNumber: 999, // we haven't drawn any numbers yet
            prizePool: uint64(joinFee),
            createdAt: uint64(block.timestamp)
        });

        // store the game
        gameRegistry[gameId] = newGame;

        uint256 playerNumbersForCard = createBingoCardForPlayer(
            uint256(0),
            blockhash(block.number - 1)
        );

        // store the player's game card
        playerRegistry[msg.sender][gameId] = BingoCard({
            numberStorage: playerNumbersForCard, // single uint32 that stores all the tile numbers
            hitStorage: 4096 // uint32 ie 0000000|0000000000001000000000000 which has the middle tile (index 12) marked as "hit"
        });

        emit GameCreated(
            msg.sender,
            gameId,
            playerNumbersForCard,
            block.timestamp
        );
    }

    
    /**
     * @dev  No need to check the player's token balance or allowance,
     *       `transferFrom` will revert if either are insufficient.
     */
    function joinGame(bytes32 _gameId) external {
        Game memory gameJoined = gameRegistry[_gameId];

        // game exists
        if(gameJoined.createdAt != 0){revert GameDoesExist();}

        GlobalGameSettings memory settings = gameSettings;
        // player can't rejoin the game to reset their card once the game has started
        if(block.timestamp < gameJoined.createdAt + settings.minimumJoinDuration){revert GameAlreadyStarted();}

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

        emit PlayerJoined(_gameId, msg.sender, playerNumbersForCard);
    }

    /**
     *   @dev    Can be drawn by any player in a game, but they bare the gas costs.
     */
    function drawNumber(bytes32 _gameId) external onlyPlayer(_gameId) {
        Game memory game = gameRegistry[_gameId];
        GlobalGameSettings memory settings = gameSettings;
        if(block.timestamp < game.lastDrawnAt + settings.minimumTurnDuration){revert PlayerStillJoining();}
        if(block.timestamp < game.lastDrawnAt + settings.minimumTurnDuration){revert TurnDurationPending();}

        uint256 random = uint256(
            keccak256(abi.encode(blockhash(block.number - 1)))
        ) % 256; // should this be 255

        game.lastDrawnNumber = uint64(random);
        game.lastDrawnAt = uint64(block.timestamp);

        gameRegistry[_gameId] = game;

        emit GameNumberDrawn(_gameId, msg.sender, random);
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
        if(hasNumber){revert NotHaveNumber();}
        uint32 playerCardHits = playerCard.hitStorage;

        // update the hit bitmap
        playerCardHits = StorageUtils.setBitValueByIndex(
            playerCardHits,
            location
        );

        playerCard.hitStorage = playerCardHits;

        playerRegistry[msg.sender][_gameId] = playerCard;

        emit PlayerHitRecorded(msg.sender, _gameId, lastDrawnNumber, location);
    }

    function claimPrize(bytes32 _gameId)
        external
        onlyPlayer(_gameId)
        returns (bool success)
    {
        // confirm winner
        BingoCard memory playerCard = playerRegistry[msg.sender][_gameId];
        uint32 playerHits = playerCard.hitStorage;
        uint32[12] memory bingoHitMasks = winningBingoMasks;
        bool isWinner = checkForBingo(bingoHitMasks, playerHits);
        if(!isWinner){revert PlayerIsNotAMember();}

        // mark as game completed
        Game memory game = gameRegistry[_gameId];
        uint256 prize = game.prizePool;
        game.lastDrawnNumber = 1000; // `1000` indicates that the game is finished
        game.prizePool = 0;
        gameRegistry[_gameId] = game;

        // transfer prize
        IERC20(bingoToken).approve(address(this), prize);
        IERC20(bingoToken).transferFrom(address(this), msg.sender, prize);

        success = true;
        emit GameEnded(_gameId, block.timestamp);
        emit Bingo(_gameId, msg.sender, prize);
    }

    // ================================ C O N V E N I E N C E  F U N C T I O N S

    function getGameSettings()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            gameSettings.entryFee,
            gameSettings.minimumTurnDuration,
            gameSettings.minimumJoinDuration
        );
    }

    function getGameById(bytes32 _gameId)
        external
        view
        returns (
            uint256 lastDrawn,
            uint256 lastDrawnAt,
            uint256 prizepool,
            uint256 createdAt
        )
    {
        Game memory game = gameRegistry[_gameId];
        if (game.createdAt != 0) {
            revert GameDoesExist();
        }
        lastDrawn = game.lastDrawnNumber;
        lastDrawnAt = game.lastDrawnAt;
        prizepool = game.prizePool;
        createdAt = game.createdAt;
    }

    // convenience function for getting players numbers on their card
    function getPlayerCardNumbersForGame(address _player, bytes32 _gameId)
        external
        view
        returns (uint256[] memory)
    {
        BingoCard memory playerCard = playerRegistry[_player][_gameId];
        uint256[] memory boardnumberStorage = new uint256[](25);
        uint256 len = 25;
        for (uint256 i; i < len; ++i) {
            boardnumberStorage[i] = StorageUtils.getBucketValueByIndex(
                playerCard.numberStorage,
                i
            );
        }
        return boardnumberStorage;
    }

    // TODO: maybe return which line is the winner
    function checkForWinner(address _player, bytes32 _gameId)
        external
        view
        returns (bool weGotAWinner)
    {
        BingoCard memory playerCard = playerRegistry[_player][_gameId];
        uint32[12] memory masks = winningBingoMasks;
        uint32 playerHits = playerCard.hitStorage;

        weGotAWinner = checkForBingo(masks, playerHits);
    }

    function getLastDrawnNumberForGame(bytes32 _gameId)
        external
        view
        returns (uint256 latest)
    {
        return gameRegistry[_gameId].lastDrawnNumber;
    }

    /**
     *  @dev    Converts the storage integers and returns two separate arrays,
     *          one containing the numbers and the other their corresponding state (hit).
     *  @dev    For each array of integers returned, they will be in reverse order to how the bits
     *          are accessed and stored.  When stored as bits in the single uint, they are accessed from right-to-left,
     *          but when they're converted to an array of integers, they're read left-to-right. So the 5x5
     *          card of the binary representation has the 0th index at the bottom right, and the 24th index
     *          at the top left.  The decimal representation, ie. rendering the bingo card in the front-end, has
     *          the 0th element at the top-left, and the 24th element appears bottom right.
     */
    function getPlayerBingoCardForGame(address _player, bytes32 _gameId)
        external
        view
        returns (
            uint256[] memory cardNumbers,
            uint256[] memory cardHits,
            uint256 numberStorage, // return for reference
            uint32 hitStorage // return for reference
        )
    {
        BingoCard memory playerCard = playerRegistry[_player][_gameId];

        numberStorage = playerCard.numberStorage;
        hitStorage = playerCard.hitStorage;

        cardNumbers = getNumbersArrayForCard(numberStorage);
        cardHits = getHitsArrayForCard(hitStorage);
    }

    function checkGameHasPlayer(address _player, bytes32 _gameId)
        external
        view
        returns (bool isPlayer)
    {
        BingoCard memory playerCard = playerRegistry[_player][_gameId];
        isPlayer = playerCard.hitStorage != 0;
    }

    // ================================ A D M I N  F U N C T I O N S

    // TODO: test this
    function updateEntryFee(uint256 _fee) external onlyOwner {
        gameSettings.entryFee = _fee;
    }

    function updateJoinDuration(uint256 _joinDuration) external onlyOwner {
        gameSettings.minimumJoinDuration = _joinDuration;
    }

    function updateUpdateTurnDuration(uint256 _turnDuration)
        external
        onlyOwner
    {
        gameSettings.minimumTurnDuration = _turnDuration;
    }

    // ================================ M O D I F I E R S

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    /**
     *   @dev   checks that the game exists, that it has not ended, and
     *          that the player is a member.
     */
    modifier onlyPlayer(bytes32 _gameId) {
        Game memory game = gameRegistry[_gameId];
        if(game.createdAt != 0){revert GameDoesNotExist();}
        if(game.lastDrawnNumber == 1000){revert GameHasEnded();} // TODO: test this

        BingoCard memory playerCard = playerRegistry[msg.sender][_gameId];
        bool playerIsMember = playerCard.numberStorage != 0;
        if (!playerIsMember) {revert PlayerIsNotAMember();}
        _;
    }
}
