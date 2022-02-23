// SPDX-License-Identifier: MIT
import './SimpleStorage.sol';

pragma solidity ^0.6.0;

contract StorageFactory is SimpleStorage {

    SimpleStorage[] public ssArray;
    function createSimpleStorageContract() public {
        SimpleStorage simpleStorage = new SimpleStorage();
        ssArray.push(simpleStorage);
    }

    function sfStore(uint256 _ssIndex, uint256 _ssNum) public {
        SimpleStorage(address(ssArray[_ssIndex])).store(_ssNum);
    }

    function sfGet(uint256 _ssIndex) public view returns(uint256) {
        return SimpleStorage(address(ssArray[_ssIndex])).retrieve();
    }
}
