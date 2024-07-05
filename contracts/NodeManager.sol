// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
import "./Node.sol"; // Ensure the correct path to the Node.sol file
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NodeManager is Pausable, AccessControl, Ownable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Node public nodeContract;

    struct NodeTier {
        bool status;
        string name;
        string metadata;
        uint256 price;
    }

    uint256 public nodeId;
    mapping(uint256 => NodeTier) public nodeTiers;
    mapping(address => uint256[]) private userNodeTiersLinks;
    mapping(uint256 => address) private nodeTierToOwner;

    struct DiscountCoupon {
        bool status;
        uint8 discountPercent;
    }

    uint256 public couponId;
    mapping(uint256 => DiscountCoupon) public discountCoupons;

    // Events
    event AddedNode(
        address indexed user,
        uint256 nodeId,
        bool status,
        string name,
        string metadata,
        uint256 price
    );
    event UpdatedNode(
        address indexed user,
        uint256 nodeId,
        bool status,
        string name,
        string metadata,
        uint256 price
    );

    event AddCoupon(
        address indexed user,
        uint256 couponId,
        bool status,
        uint8 discountPercent
    );

    event UpdateCoupon(
        address indexed user,
        uint256 couponId,
        bool status,
        uint8 discountPercent
    );
    event Sale(address indexed user, uint256 nodeId);
    event FundsWithdrawn(address indexed to, uint256 value);

    constructor(address _nodeContract) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nodeContract = Node(_nodeContract);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getNodeContractAddress() public view returns (address) {
        return address(nodeContract);
    }

    function setNodeContractAddress(address _nodeContract) public {
        nodeContract = Node(_nodeContract);
    }

    // NODE Tier MANAGEMENT

    function addNodeTier(
        string memory name,
        string memory metadata,
        uint256 price
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(price > 0, "Price must be greater than 0");
        nodeId++;
        NodeTier memory newNode = NodeTier(false, name, metadata, price);
        nodeTiers[nodeId] = newNode;
        emit AddedNode(
            msg.sender,
            nodeId,
            nodeTiers[nodeId].status,
            name,
            metadata,
            price
        );
    }

    function getNodeIdByIndex(address user, uint256 index)
        public
        view
        returns (uint256)
    {
        require(index < userNodeTiersLinks[user].length, "Index out of bounds");
        uint256 nodeTierId = userNodeTiersLinks[user][index];
        return nodeTierId;
    }

    function getOwnerByNodeId(uint256 _nodeId) public view returns (address) {
        return nodeTierToOwner[_nodeId];
    }

    function getUserTotalNode(address user) public view returns (uint256) {
        return userNodeTiersLinks[user].length;
    }

    function getNodeTierDetails(uint64 _nodeId)
        public
        view
        returns (NodeTier memory)
    {
        return nodeTiers[_nodeId];
    }

    function getTotalNode() public view returns (uint256) {
        return nodeId;
    }

    function updateNodeTier(
        uint64 _nodeId,
        string memory newName,
        string memory newMetadata,
        bool newStatus,
        uint256 newPrice
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(newPrice > 0, "Price must be greater than 0");
        nodeTiers[_nodeId].name = newName;
        nodeTiers[_nodeId].metadata = newMetadata;
        nodeTiers[_nodeId].status = newStatus;
        nodeTiers[_nodeId].price = newPrice;

        emit UpdatedNode(
            msg.sender,
            _nodeId,
            nodeTiers[_nodeId].status,
            nodeTiers[_nodeId].name,
            nodeTiers[_nodeId].metadata,
            nodeTiers[_nodeId].price
        );
    }

    // COUPON MANAGEMENT

    function addDiscountCoupon(uint8 discountPercent)
        public
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(discountPercent > 0, "Discount percent must be greater than 0");
        couponId++;
        DiscountCoupon memory newCoupon = DiscountCoupon(
            false,
            discountPercent
        );
        discountCoupons[couponId] = newCoupon;
        emit AddCoupon(
            msg.sender,
            couponId,
            discountCoupons[couponId].status,
            discountCoupons[couponId].discountPercent
        );
    }

    function getDiscountCoupon(uint64 _couponId)
        public
        view
        returns (DiscountCoupon memory)
    {
        return discountCoupons[_couponId];
    }

    function updateDiscountCoupon(
        uint64 _couponId,
        uint8 newDiscountPercent,
        bool newStatus
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(
            discountCoupons[_couponId].discountPercent > 0,
            "Coupon does not exist"
        );
        require(
            newDiscountPercent > 0,
            "Discount percent must be greater than 0"
        );
        discountCoupons[_couponId].discountPercent = newDiscountPercent;
        discountCoupons[_couponId].status = newStatus;
        emit UpdateCoupon(
            msg.sender,
            _couponId,
            discountCoupons[_couponId].status,
            discountCoupons[_couponId].discountPercent
        );
    }

    function buyNode(uint64 _nodeId) public payable whenNotPaused {
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(msg.value >= nodeTiers[_nodeId].price, "Insufficient funds");
        require(
            nodeTierToOwner[_nodeId] == address(0),
            "Node tier already owned"
        );
        nodeContract.safeMint(msg.sender, _nodeId);
        userNodeTiersLinks[msg.sender].push(nodeId);
        nodeTierToOwner[_nodeId] = msg.sender;
        emit Sale(msg.sender, _nodeId);
    }

    function buyAdmin(uint64 _nodeId, address nodeOwner)
        public
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(
            nodeTierToOwner[_nodeId] == address(0),
            "Node tier already owned"
        );
        nodeContract.safeMint(nodeOwner, _nodeId);
        userNodeTiersLinks[msg.sender].push(nodeId);
        nodeTierToOwner[_nodeId] = msg.sender;
        emit Sale(msg.sender, _nodeId);
    }

    function withdraw(address payable to, uint256 value) public onlyOwner {
        require(
            address(this).balance >= value,
            "Insufficient contract balance"
        );

        (bool sent, ) = to.call{value: value}("");
        require(sent, "Failed to send Ether");

        emit FundsWithdrawn(to, value);
    }

    // Fallback function to receive Ether
    receive() external payable {}
}
