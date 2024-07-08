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
        uint256 price;
    }

    uint256 private nodeId;
    mapping(uint256 => NodeTier) public nodeTiers;
    mapping(address => EnumerableSet.UintSet) private userNodeTiersIdLinks;
    mapping(uint256 => address) private nodeTiersIdUserLinks;

    struct DiscountCoupon {
        bool status;
        uint8 discountPercent;
    }

    uint256 private couponId;
    mapping(uint256 => DiscountCoupon) public discountCoupons;

    // Referral
    uint256 private referenceId;
    uint256 private referenceRate;
    struct ReferralInformation {
        string code;
        uint256 totalSales;
    }
    mapping(uint256 => ReferralInformation) private referrals;
    mapping(address => uint256) private userReferralIdLinks;
    mapping(uint256 => address) private referralIdUserLinks;

    // Events
    event AddedNode(
        address indexed user,
        uint256 nodeId,
        bool status,
        string name,
        uint256 price
    );
    event UpdatedNode(
        address indexed user,
        uint256 nodeId,
        bool status,
        string name,
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

    constructor(
        address _nodeContract,
        uint256 _referenceRate
    ) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        require(_referenceRate <= 100, "Invalid input");
        referenceRate = _referenceRate;
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
        uint256 price
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(price > 0, "Price must be greater than 0");
        nodeId++;
        NodeTier memory newNode = NodeTier(false, name, price);
        nodeTiers[nodeId] = newNode;
        emit AddedNode(
            msg.sender,
            nodeId,
            nodeTiers[nodeId].status,
            name,
            price
        );
    }

    function getNodeIdByIndex(
        address user,
        uint256 index
    ) public view returns (uint256) {
        require(
            index < userNodeTiersIdLinks[user].length(),
            "Index out of bounds"
        );
        uint256 nodeTierId = userNodeTiersIdLinks[user].at(index);
        return nodeTierId;
    }

    function getOwnerByNodeId(uint256 _nodeId) public view returns (address) {
        return nodeTiersIdUserLinks[_nodeId];
    }

    function getUserTotalNode(address user) public view returns (uint256) {
        return userNodeTiersIdLinks[user].length();
    }

    function getNodeTierDetails(
        uint256 _nodeId
    ) public view returns (NodeTier memory) {
        return nodeTiers[_nodeId];
    }

    function getLastNodeId() public view returns (uint256) {
        return nodeId;
    }

    function updateNodeTier(
        uint256 _nodeId,
        string memory newName,
        bool newStatus,
        uint256 newPrice
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(newPrice > 0, "Price must be greater than 0");
        nodeTiers[_nodeId].name = newName;
        nodeTiers[_nodeId].status = newStatus;
        nodeTiers[_nodeId].price = newPrice;

        emit UpdatedNode(
            msg.sender,
            _nodeId,
            nodeTiers[_nodeId].status,
            nodeTiers[_nodeId].name,
            nodeTiers[_nodeId].price
        );
    }

    // COUPON MANAGEMENT

    function addDiscountCoupon(
        uint8 discountPercent
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
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

    function getDiscountCoupon(
        uint256 _couponId
    ) public view returns (DiscountCoupon memory) {
        return discountCoupons[_couponId];
    }

    function getLastCouponId() public view returns (uint256) {
        return couponId;
    }

    function updateDiscountCoupon(
        uint256 _couponId,
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

    function buyNode(
        uint256 _nodeId,
        uint256 referralId,
        string memory metadata
    ) public payable whenNotPaused {
        uint256 price = nodeTiers[_nodeId].price;
        address caller = msg.sender;
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(msg.value >= price, "Insufficient funds");
        require(
            nodeTiersIdUserLinks[_nodeId] == address(0),
            "Node tier already owned"
        );

        // Referral code can only be used once per person
        if (
            referralId > 0 &&
            referralIdUserLinks[referralId] != address(0) &&
            referralIdUserLinks[referralId] != caller
        ) {
            address referralsOwner = referralIdUserLinks[referralId];
            uint256 totalSales = (price * referenceRate) / 100;
            require(address(this).balance >= totalSales, "Not enough balance");
            (bool sent, ) = referralsOwner.call{value: totalSales}("");
            require(sent, "Failed to send Ether");
            referrals[referralId].totalSales += totalSales;
        }

        nodeContract.safeMint(caller, _nodeId, metadata);
        userNodeTiersIdLinks[caller].add(_nodeId);
        nodeTiersIdUserLinks[_nodeId] = caller;

        // add Referral for user
        if (userReferralIdLinks[caller] == 0) {
            referenceId++;
            uint256 currentTimestamp = block.timestamp;
            string memory _code = string(
                abi.encodePacked(
                    "BachiSwap_",
                    uint256str(referenceId),
                    "_",
                    uint256str(currentTimestamp)
                )
            );
            userReferralIdLinks[caller] = referenceId;
            referralIdUserLinks[referenceId] = caller;
            referrals[referenceId].code = _code;
        }
        emit Sale(caller, _nodeId);
    }

    function getReferralIdByOwner(address owner) public view returns (uint256) {
        return userReferralIdLinks[owner];
    }

    function getOwnerByReferralId(
        uint256 referralId
    ) public view returns (address) {
        return referralIdUserLinks[referralId];
    }

    function getReferralInfo(
        uint256 referralId
    ) public view returns (string memory code, uint256 totalSales) {
        return (referrals[referralId].code, referrals[referralId].totalSales);
    }

    function getReferenceRate() public view returns (uint256) {
        return referenceRate;
    }

    function setReferenceRate(
        uint256 _referenceRate
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_referenceRate <= 100, "Invalid input");
        referenceRate = _referenceRate;
    }

    function buyAdmin(
        uint256 _nodeId,
        address nodeOwner,
        string memory metadata
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        require(nodeTiers[_nodeId].price > 0, "Node does not exist");
        require(
            nodeTiersIdUserLinks[_nodeId] == address(0),
            "Node tier already owned"
        );
        nodeContract.safeMint(nodeOwner, _nodeId, metadata);
        userNodeTiersIdLinks[msg.sender].add(_nodeId);
        nodeTiersIdUserLinks[_nodeId] = msg.sender;
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
