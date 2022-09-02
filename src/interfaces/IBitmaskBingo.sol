// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// TODO: document these inline
interface IBitmaskBingo {
    // ================================ P L A Y E R  F U N C T I O N S

    /**
     *   @notice    Creates a new game of Bingo
     *   @dev       will revert if player doesn't have sufficient token balance
     *   @return    gameId The ID of the created game
     */
    function createGame() external returns (bytes32 gameId);

    /**
     *   @notice    Join a Bingo game as a player
     *   @dev       will revert if player doesn't have sufficient token balance
     *   @param     _gameId the ID of the game to join
     */
    function joinGame(bytes32 _gameId) external;

    /**
     *   @notice    Starts a new number and draws a random number
     *   @dev       Can only be called by player who joined the game
     *   @param     _gameId the ID of the game to joinparam
     */
    function drawNumber(bytes32 _gameId) external;

    /**
     *   @notice    Marks the latest drawn number as a hit if the player's card contains it.
     *   @dev       Can only be called by player who joined the game
     *   @param     _gameId the ID of the game to joinparam
     */
    function markNumberOnCard(bytes32 _gameId) external;

    /**
     *   @notice    Claims the prize and ends the game.
     *   @dev       Player must have a winning combination of numbers
     *   @param     _gameId the ID of the game to joinparam
     *   @return    success
     */
    function claimPrize(bytes32 _gameId) external returns (bool success);

    // ================================ P U B L I C  F U N C T I O N S

    /**
     *   @notice    Gets the games current settings
     *   @return    The entry fee, join duration, and turn duration
     */
    function getGameSettings()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    /**
     *   @notice    Fetch a game by its ID
     *   @param     _gameId the ID of the game to joinparam
     *   @return    lastDrawn Returns last drawn number, time of last drawn number, prize pool, and time the game was created
     */
    function getGameById(bytes32 _gameId)
        external
        view
        returns (
            uint256 lastDrawn,
            uint256 lastDrawnAt,
            uint256 prizepool,
            uint256 createdAt
        );

    /**
     *   @notice    Gets the numbers present on a player's card
     *   @dev       Converts the integer storing the values into an array
     *   @param     _player the player's address
     *   @param     _gameId the game ID of the game the card belongs to
     *   @return    Array of numbers belonging to the card
     */
    function getPlayerCardNumbersForGame(address _player, bytes32 _gameId)
        external
        view
        returns (uint256[] memory);

    /**
     *   @notice    Checks if a player has won the game
     *   @dev       Doesn't claim the prize, just a convenience function for the front-end
     *   @param     _player The player to check
     *   @param     _gameId the game the player belongs to
     *   @return    weGotAWinner True if the player is the winner
     */
    function checkForWinner(address _player, bytes32 _gameId)
        external
        view
        returns (bool weGotAWinner);

    /**
     *   @notice    Gets the last number drawn in the active round
     *   @param     _gameId the ID of the game to joinp
     *   @return    latest The latest number
     */
    function getLastDrawnNumberForGame(bytes32 _gameId)
        external
        view
        returns (uint256 latest);

    /**
     *   @notice    Gets all the details of the Player's Bingo card
     *   @dev       Converts the storage integers and returns two separate arrays,
     *              one containing the numbers and the other their corresponding state (hit).
     *   @dev       For each array of integers returned, they will be in reverse order to how the bits
     *              are accessed and stored.  When stored as bits in the single uint, they are accessed from right-to-left,
     *              but when they're converted to an array of integers, they're read left-to-right. So the 5x5
     *              card of the binary representation has the 0th index at the bottom right, and the 24th index
     *              at the top left.  The decimal representation, ie. rendering the bingo card in the front-end, has
     *              the 0th element at the top-left, and the 24th element appears bottom right.
     *   @param     _player the player whose card to getch
     *   @param     _gameId the ID of the game to joinp
     *   @return    cardNumbers  Array containing the numbers
     *   @return    cardHits    Array containing the hits
     */
    function getPlayerBingoCardForGame(address _player, bytes32 _gameId)
        external
        view
        returns (
            uint256[] memory cardNumbers,
            uint256[] memory cardHits,
            uint256 numberStorage,
            uint32 hitStorage
        );

    // ================================ A D M I N  F U N C T I O N S

    /**
     *   @notice    Update the entry fee
     *   @param     _fee the new fee
     */
    function updateEntryFee(uint256 _fee) external;

    /**
     *   @notice    Update the join duration
     *   @param     _joinDuration the new join duration
     */
    function updateJoinDuration(uint256 _joinDuration) external;

    /**
     *   @notice    Update the turn duration
     *   @param     _turnDuration the new turn duration
     */
    function updateUpdateTurnDuration(uint256 _turnDuration) external;

    // ================================ P U B L I C  F U N C T I O N S

    // ================================ E V E N T S

    // a new game of Bingo is created
    event GameCreated(
        address indexed creator,
        bytes32 indexed id,
        uint256 creatorCardNumbers,
        uint256 timestamp
    );

    // a player joins an existing game
    event PlayerJoined(
        bytes32 indexed id,
        address indexed player,
        uint256 playerCardNumbers
    );

    // a new number is drawn for the game
    event GameNumberDrawn(
        bytes32 indexed gameId,
        address indexed drawnBy,
        uint256 number
    );

    // player marks a number as a hit on their card
    event PlayerHitRecorded(
        address indexed player,
        bytes32 indexed gameId,
        uint256 number,
        uint256 hitPosition
    );

    // game has come to an end once the prize is claimed
    event GameEnded(bytes32 indexed gameId, uint256 time);

    // a winner claims the prize
    event Bingo(bytes32 indexed gameId, address indexed winner, uint256 prize);
}
