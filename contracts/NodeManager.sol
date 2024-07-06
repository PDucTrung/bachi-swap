// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
import "./Node.sol"; // Ensure the correct path to the Node.sol file
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NodeManager is Pausable, AccessControl, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Node public nodeContract;

    struct NodeTier {
        bool status;
        string name;
        string metadata;
        uint256 price;
    }

    uint256 private nodeId;
    mapping(uint256 => NodeTier) public nodeTiers;
    mapping(address => EnumerableSet.UintSet) private userNodeTiersLinks;
    mapping(uint256 => address) private nodeTierToOwner;

    struct DiscountCoupon {
        bool status;
        uint8 discountPercent;
    }

    uint256 private couponId;
    mapping(uint256 => DiscountCoupon) public discountCoupons;

    // Affiliate
    uint256 private referenceId;
    uint256 private referenceRevenue;
    struct AffiliateInformation {
        uint256 totalSales;
        uint256 commissionRate;
        EnumerableSet.AddressSet usersUsed;
    }
    mapping(string => AffiliateInformation) private affiliates;
    mapping(address => string) private userAffiliateIdLinks;
    mapping(string => address) private affiliateIdUserLinks;
    EnumerableSet.AddressSet usersUsedReference;

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

    constructor(address _nodeContract, uint256 _referenceRevenue)
        Ownable(msg.sender)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        referenceRevenue = _referenceRevenue;
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
        require(
            index < userNodeTiersLinks[user].length(),
            "Index out of bounds"
        );
        uint256 nodeTierId = userNodeTiersLinks[user].at(index);
        return nodeTierId;
    }

    function getOwnerByNodeId(uint256 _nodeId) public view returns (address) {
        return nodeTierToOwner[_nodeId];
    }

    function getUserTotalNode(address user) public view returns (uint256) {
        return userNodeTiersLinks[user].length();
    }

    function getNodeTierDetails(uint64 _nodeId)
        public
        view
        returns (NodeTier memory)
    {
        return nodeTiers[_nodeId];
    }

    function getLastNodeId() public view returns (uint256) {
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

    function getLastCouponId() public view returns (uint256) {
        return couponId;
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

    function buyNode(uint64 _nodeId, string memory affiliateId)
        public
        payable
        whenNotPaused
    {
        uint256 price = nodeTiers[_nodeId].price;
        address caller = msg.sender;
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(msg.value >= price, "Insufficient funds");
        require(
            nodeTierToOwner[_nodeId] == address(0),
            "Node tier already owned"
        );
        // Referral code can only be used once per person
        if (
            affiliateIdUserLinks[affiliateId] != caller &&
            usersUsedReference.contains(caller) &&
            !affiliates[affiliateId].usersUsed.contains(caller)
        ) {
            address affiliatesOwner = affiliateIdUserLinks[affiliateId];
            uint256 totalSales = (price *
                affiliates[affiliateId].commissionRate) / 100;
            (bool sent, ) = affiliatesOwner.call{value: totalSales}("");
            require(sent, "Failed to send Ether");
            affiliates[affiliateId].totalSales += totalSales;
            affiliates[affiliateId].usersUsed.add(caller);
            usersUsedReference.add(caller);
        }

        nodeContract.safeMint(caller, _nodeId);
        userNodeTiersLinks[caller].add(_nodeId);
        nodeTierToOwner[_nodeId] = caller;

        // add Affiliate for user
        if (bytes(userAffiliateIdLinks[caller]).length == 0) {
            referenceId++;
            uint256 currentTimestamp = block.timestamp;
            string memory _affiliateId = string(
                abi.encodePacked(
                    "BachiSwap_",
                    uint256str(referenceId),
                    "_",
                    uint256str(currentTimestamp)
                )
            );
            userAffiliateIdLinks[caller] = _affiliateId;
            affiliateIdUserLinks[_affiliateId] = caller;
            affiliates[_affiliateId].commissionRate = referenceRevenue;
        }
        emit Sale(caller, _nodeId);
    }

    function getAffiliateIdByOwner(address owner)
        public
        view
        returns (string memory)
    {
        return userAffiliateIdLinks[owner];
    }

    function getOwnerByAffiliateId(string memory affiliateId)
        public
        view
        returns (address)
    {
        return affiliateIdUserLinks[affiliateId];
    }

    function getAffiliateInfo(string memory affiliateId)
        public
        view
        returns (uint256 totalSales, uint256 commissionRate)
    {
        return (
            affiliates[affiliateId].totalSales,
            affiliates[affiliateId].commissionRate
        );
    }

    function getUserUsedAffiliateByIndex(
        string memory affiliateId,
        uint256 index
    ) public view returns (address) {
        address user = affiliates[affiliateId].usersUsed.at(index);
        return user;
    }

    function getTotalUserUsedAffiliate(string memory affiliateId)
        public
        view
        returns (uint256)
    {
        return affiliates[affiliateId].usersUsed.length();
    }

    function userUsedTheReferralCode(address user) public view returns (bool) {
        return usersUsedReference.contains(user);
    }

    function getUserUsedTheReferralCodeByIndex(uint256 index)
        public
        view
        returns (address)
    {
        return usersUsedReference.at(index);
    }

    function getReferenceRevenue() public view returns (uint256) {
        return referenceRevenue;
    }

    function setReferenceRevenue(uint256 _referenceRevenue)
        public
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(_referenceRevenue <= 100, "Invalid input");
        referenceRevenue = _referenceRevenue;
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
        userNodeTiersLinks[msg.sender].add(_nodeId);
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

    // Helper function to convert uint256 to string
    function uint256str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // Fallback function to receive Ether
    receive() external payable {}
}
