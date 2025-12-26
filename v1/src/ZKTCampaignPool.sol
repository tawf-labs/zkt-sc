// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IZKTReceiptNFT {
    function mint(
        address to,
        bytes32 campaignId,
        uint256 amount,
        string calldata ipfsCID,
        bool isImpact
    ) external returns (uint256 tokenId);
    
    function updateIPFSCID(
        uint256 tokenId,
        string calldata newCID
    ) external;
}

/*//////////////////////////////////////////////////////////////
                        CORE CONTRACT
//////////////////////////////////////////////////////////////*/

contract ZKTCampaignPool {
    address public admin;        // multisig
    IERC20  public immutable token;        // e.g. USDC
    IZKTReceiptNFT public immutable receiptNFT;  // Donation receipt NFT

    bool public paused;

    constructor(
        address _admin,
        address _token,
        address _receiptNFT
    ) {
        require(_admin != address(0), "admin zero");
        require(_token != address(0), "token zero");
        require(_receiptNFT != address(0), "nft zero");

        admin = _admin;
        token = IERC20(_token);
        receiptNFT = IZKTReceiptNFT(_receiptNFT);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN TRANSFER
    //////////////////////////////////////////////////////////////*/

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "new admin zero");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            CAMPAIGN
    //////////////////////////////////////////////////////////////*/

    struct Campaign {
        bool exists;
        bool allocationLocked;
        bool disbursed;
        bool closed;
        uint256 totalRaised;
        uint256 startTime;
        uint256 endTime;
    }

    mapping(bytes32 => Campaign) public campaigns;

    event CampaignCreated(bytes32 indexed campaignId, uint256 startTime, uint256 endTime);
    event CampaignClosed(bytes32 indexed campaignId);

    function createCampaign(
        bytes32 campaignId,
        uint256 startTime,
        uint256 endTime
    ) external onlyAdmin {
        require(!campaigns[campaignId].exists, "exists");
        require(endTime > startTime, "invalid time");
        require(endTime > block.timestamp, "end in past");

        campaigns[campaignId] = Campaign({
            exists: true,
            allocationLocked: false,
            disbursed: false,
            closed: false,
            totalRaised: 0,
            startTime: startTime,
            endTime: endTime
        });

        emit CampaignCreated(campaignId, startTime, endTime);
    }

    function closeCampaign(bytes32 campaignId) external onlyAdmin {
        Campaign storage c = campaigns[campaignId];
        require(c.exists, "no campaign");
        require(!c.closed, "already closed");

        c.closed = true;
        emit CampaignClosed(campaignId);
    }

    /*//////////////////////////////////////////////////////////////
                                NGO
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => bool) public approvedNGO;
    mapping(bytes32 => address) public ngoWallet;

    function approveNGO(bytes32 ngoId, address wallet) external onlyAdmin {
        require(wallet != address(0), "zero wallet");
        approvedNGO[ngoId] = true;
        ngoWallet[ngoId] = wallet;
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOCATION
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => mapping(bytes32 => uint256)) public allocationBps;
    mapping(bytes32 => uint256) public totalBps;

    function setAllocation(
        bytes32 campaignId,
        bytes32 ngoId,
        uint256 bps
    ) external onlyAdmin {
        Campaign storage c = campaigns[campaignId];
        require(c.exists, "no campaign");
        require(!c.allocationLocked, "locked");
        require(approvedNGO[ngoId], "ngo not approved");

        totalBps[campaignId] =
            totalBps[campaignId]
            - allocationBps[campaignId][ngoId]
            + bps;

        require(totalBps[campaignId] <= 10_000, "over 100%");
        allocationBps[campaignId][ngoId] = bps;
    }

    function lockAllocation(bytes32 campaignId) external onlyAdmin {
        require(totalBps[campaignId] == 10_000, "must be 100%");
        campaigns[campaignId].allocationLocked = true;
    }

    /*//////////////////////////////////////////////////////////////
                                DONATE
    //////////////////////////////////////////////////////////////*/

    event Donated(
        bytes32 indexed campaignId,
        address indexed donor,
        uint256 amount,
        uint256 indexed tokenId
    );

    function donate(
        bytes32 campaignId,
        uint256 amount
    ) external whenNotPaused {
        Campaign storage c = campaigns[campaignId];

        require(c.exists, "no campaign");
        require(!c.closed, "closed");
        require(block.timestamp >= c.startTime, "not started");
        require(block.timestamp <= c.endTime, "ended");
        require(c.allocationLocked, "allocation not locked");
        require(amount > 0, "zero");

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transfer failed"
        );

        c.totalRaised += amount;

        // Mint receipt NFT to donor (admin will update CID via Pinata later)
        uint256 tokenId = receiptNFT.mint(
            msg.sender,
            campaignId,
            amount,
            "",  // Empty CID initially - admin updates after uploading to Pinata
            false  // isImpact = false (this is donation, not disbursement)
        );

        emit Donated(campaignId, msg.sender, amount, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            DISBURSE
    //////////////////////////////////////////////////////////////*/

    event Disbursed(
        bytes32 indexed campaignId,
        bytes32 indexed ngoId,
        uint256 amount
    );

    function disburse(
        bytes32 campaignId,
        bytes32[] calldata ngoIds
    ) external onlyAdmin whenNotPaused {
        Campaign storage c = campaigns[campaignId];
        require(c.exists, "no campaign");
        require(!c.disbursed, "already disbursed");

        c.disbursed = true;
        uint256 total = c.totalRaised;

        for (uint256 i = 0; i < ngoIds.length; i++) {
            bytes32 ngoId = ngoIds[i];
            uint256 bps = allocationBps[campaignId][ngoId];
            if (bps == 0) continue;

            uint256 amount = (total * bps) / 10_000;
            address wallet = ngoWallet[ngoId];

            require(token.transfer(wallet, amount), "transfer failed");

            emit Disbursed(
                campaignId,
                ngoId,
                amount
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE
    //////////////////////////////////////////////////////////////*/

    event Paused();
    event Unpaused();

    function pause() external onlyAdmin {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused();
    }

    /*//////////////////////////////////////////////////////////////
                        NFT METADATA UPDATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin function to update IPFS CID for receipt NFTs
    /// @dev Called after NGO uploads reports/images to Pinata
    /// @param tokenId The NFT token ID to update
    /// @param pinataCID The Pinata folder CID containing reports and images
    function updateReceiptMetadata(
        uint256 tokenId,
        string calldata pinataCID
    ) external onlyAdmin {
        receiptNFT.updateIPFSCID(tokenId, pinataCID);
    }

    /// @notice Batch update IPFS CID for multiple receipt NFTs
    /// @dev Useful for updating all receipts in a campaign at once
    /// @param tokenIds Array of NFT token IDs to update
    /// @param pinataCID The Pinata folder CID containing reports and images
    function batchUpdateReceiptMetadata(
        uint256[] calldata tokenIds,
        string calldata pinataCID
    ) external onlyAdmin {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            receiptNFT.updateIPFSCID(tokenIds[i], pinataCID);
        }
    }
}
