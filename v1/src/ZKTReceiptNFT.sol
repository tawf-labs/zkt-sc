// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;
/// @title ZKT Receipt NFT (Soulbound + IPFS)
/// @notice Non-transferable NFT for donation & impact receipts

contract ZKTReceiptNFT {
    string public name = "ZKT Receipt";
    string public symbol = "ZKT-R";

    address public minter;
    uint256 public totalSupply;

    string internal constant IPFS_PREFIX = "ipfs://";

    struct Receipt {
        bytes32 campaignId;
        uint256 amount;
        bool isImpact;          // false = donation, true = disbursement
        string ipfsCID;         // IPFS CID pointing to metadata JSON
        bytes32 cidHash;        // keccak256(CID)
    }

    mapping(uint256 => Receipt) public receipts;
    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;

    event Minted(
        uint256 indexed tokenId,
        address indexed owner,
        bytes32 indexed campaignId,
        uint256 amount,
        bool isImpact,
        string ipfsCID
    );

    event IPFSCIDUpdated(
        uint256 indexed tokenId,
        string oldCID,
        string newCID
    );

    constructor(address _minter) {
        minter = _minter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "not minter");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMinter(address _minter) external {
        require(minter == address(0), "minter already set");
        require(_minter != address(0), "minter zero");
        minter = _minter;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC721 READ-ONLY
    //////////////////////////////////////////////////////////////*/

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "zero address");
        return _balanceOf[owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "nonexistent token");
        return string(abi.encodePacked(IPFS_PREFIX, receipts[tokenId].ipfsCID));
    }

    /*//////////////////////////////////////////////////////////////
                        SOULBOUND ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    function approve(address, uint256) external pure { revert("SOULBOUND"); }
    function setApprovalForAll(address, bool) external pure { revert("SOULBOUND"); }
    function transferFrom(address, address, uint256) external pure { revert("SOULBOUND"); }
    function safeTransferFrom(address, address, uint256) external pure { revert("SOULBOUND"); }
    function safeTransferFrom(address, address, uint256, bytes calldata) external pure { revert("SOULBOUND"); }

    /*//////////////////////////////////////////////////////////////
                            MINTING
    //////////////////////////////////////////////////////////////*/

    function mint(
        address to,
        bytes32 campaignId,
        uint256 amount,
        string calldata ipfsCID,
        bool isImpact
    ) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "to zero");

        tokenId = ++totalSupply;

        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;

        receipts[tokenId] = Receipt({
            campaignId: campaignId,
            amount: amount,
            isImpact: isImpact,
            ipfsCID: ipfsCID,
            cidHash: keccak256(bytes(ipfsCID))
        });

        emit Minted(
            tokenId,
            to,
            campaignId,
            amount,
            isImpact,
            ipfsCID
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN UPDATE METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows minter (admin) to update IPFS CID after minting
    /// @dev Used when NGO uploads report, images, etc. to Pinata folder
    function updateIPFSCID(
        uint256 tokenId,
        string calldata newCID
    ) external onlyMinter {
        require(_ownerOf[tokenId] != address(0), "nonexistent token");
        require(bytes(newCID).length > 0, "empty CID");

        string memory oldCID = receipts[tokenId].ipfsCID;
        receipts[tokenId].ipfsCID = newCID;
        receipts[tokenId].cidHash = keccak256(bytes(newCID));

        emit IPFSCIDUpdated(tokenId, oldCID, newCID);
    }
}
