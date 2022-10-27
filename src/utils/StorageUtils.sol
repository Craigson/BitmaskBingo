// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

library StorageUtils {
    uint256 private constant BUCKET_SIZE_IN_BITS = 8;

    // ======================================= Bingo Tiles

    /**
     *   @dev Sets the uint8 value stored in
     */
    function setBucketValueByIndex(
        uint256 _storageContainer,
        uint256 _bucketIndex,
        uint256 _newValue
    ) internal pure returns (uint256 tempSlot) {
        uint256 numBitsToShiftLeft = BUCKET_SIZE_IN_BITS * _bucketIndex;
        tempSlot = _storageContainer + (_newValue << numBitsToShiftLeft);
    }

    /**
     *  @dev    Gets the uint8 value stored in a bucket using the bucket index.
     */
    function getBucketValueByIndex(
        uint256 _storageContainer,
        uint256 _bucketIndex
    ) internal pure returns (uint256 bucketValue) {
        // subtracting one sets all bits to the right as 1s, thus creating the mask
        /*
            Eg.
            uint8 shift = (uint8(1) << 4)
                        = 16
                        = 0 0 0 1 0 0 0 0
            uint8 mask  = mask - 1
                        = 15
                        = 0 0 0 0 1 1 1 1
        */
        uint256 mask = (uint256(1) << BUCKET_SIZE_IN_BITS) - 1;

        // calculate the number of bits to shift by
        uint256 numBitsToShiftRight = BUCKET_SIZE_IN_BITS * _bucketIndex;

        /*
            Apply the mask by using the Bitwise AND ( & ) after shifting
            in order to isolate the value stored at the index:
            
            Eg.
            If we want to isolate the value ( 4 bits ) in bucket 1, we
            need to shift 4 bits to the. We know that the value stored in
            the bucket at index 1 is `3` ( because we put it there).

            distance (index):  4

            slot:       1 0 1 1 | 0 1 0 1 | 0 0 1 1 | 0 1 0 1
            buckets:    |__3__|   |__2__|   |__1__|   |__0__|
            
            shifted = (slot >> 4) & mask;

            or

            slot:       0 0 0 0 | 1 0 1 1 | 0 1 0 1 | 0 0 1 1
            buckets:    |__3__|   |__2__|   |__1__|   |__0__|
            mask:       0 0 0 0 | 0 0 0 0 | 0 0 0 0 | 1 1 1 1

            result = 0 0 0 0 | 0 0 0 0 | 0 0 0 0 | 0 0 1 1
                   = 3;

        */

        return (_storageContainer >> numBitsToShiftRight) & mask;
    }

    // ======================================= Bingo Hits

    /**
     *   @dev   Returns a copy of the original storage integer with
     *          the updated bit and the supplied index.
     */
    function setBitValueByIndex(uint32 _board, uint32 _location)
        internal
        pure
        returns (uint32 updated)
    {
        uint32 mask = (uint32(1) << _location);
        updated = _board | mask;
    }

    function getBitValueByIndex(uint32 _hitStorage, uint32 _index)
        internal
        pure
        returns (uint256)
    {
        return _hitStorage & (uint32(1) << _index) != 0 ? 1 : 0;
    }
}
