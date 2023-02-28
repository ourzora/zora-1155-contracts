// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IMinter1155} from "../interfaces/IMinter1155.sol";
import {IVersionedContract} from "../interfaces/IVersionedContract.sol";
import {ICreatorCommands} from "../interfaces/ICreatorCommands.sol";
import {SaleCommandHelper} from "./SaleCommandHelper.sol";

abstract contract SaleStrategy is IMinter1155, IVersionedContract {
    function contractURI() external virtual returns (string memory);

    function contractName() external virtual returns (string memory);

    function contractVersion() external virtual returns (string memory);

    function resetSale(uint256 tokenId) external virtual;

    function _getKey(address mediaContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encode(mediaContract, tokenId));
    }
}
