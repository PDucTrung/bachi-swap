// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Node is ERC721, ERC721Burnable, AccessControl, Ownable {
    address private nodeManagerAddress;

    constructor(string memory name, string memory symbol, address _nodeManagerAddress)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nodeManagerAddress = _nodeManagerAddress;
    }

    modifier onlyNodeManager() {
        require(nodeManagerAddress == msg.sender, "Unauthorized: Only node manager");
        _;
    }

    function setNodeManagerAddress(address newAddress) public onlyOwner {
        nodeManagerAddress = newAddress;
    }

    function getNodeManagerAddress() public view returns (address) {
        return nodeManagerAddress;
    }

    function safeMint(address to, uint256 tokenId) public onlyNodeManager {
        _safeMint(to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}