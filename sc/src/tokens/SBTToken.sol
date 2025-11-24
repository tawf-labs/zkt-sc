// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title SBTToken
 * @notice Soulbound Token (non-transferable NFT) for ZKT donation proof
 * @dev ERC721 with transfers blocked except minting/burning
 * Each SBT represents a donor's contribution to a specific campaign pool
 */
contract SBTToken is ERC721URIStorage, AccessControl {
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 private _tokenIdCounter;
    
    // Token metadata
    struct SBTMetadata {
        uint256 poolId;
        address donor;
        uint256 totalDonated;
        uint256 mintedAt;
        string campaignType; // "Zakat" or "Normal"
        bool isActive;
    }
    
    // Mappings
    mapping(uint256 => SBTMetadata) public tokenMetadata;
    mapping(address => mapping(uint256 => uint256)) public donorPoolToToken; // donor => poolId => tokenId
    
    // Events
    event SBTMinted(
        uint256 indexed tokenId,
        address indexed donor,
        uint256 indexed poolId,
        uint256 amount,
        string campaignType
    );
    event SBTUpdated(uint256 indexed tokenId, uint256 newTotalDonated);
    event SBTBurned(uint256 indexed tokenId, address indexed donor, string reason);
    
    constructor() ERC721("ZKT Donation SBT", "ZKT-SBT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    /**
     * @notice Mint a new SBT to a donor for their first donation to a pool
     * @param to Donor address
     * @param poolId Campaign pool ID
     * @param amount Initial donation amount
     * @param campaignType "Zakat" or "Normal"
     * @return tokenId The minted token ID
     */
    function mint(
        address to,
        uint256 poolId,
        uint256 amount,
        string memory campaignType
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(to != address(0), "SBT: Cannot mint to zero address");
        require(amount > 0, "SBT: Amount must be greater than 0");
        require(
            donorPoolToToken[to][poolId] == 0,
            "SBT: Donor already has SBT for this pool"
        );
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _safeMint(to, tokenId);
        
        tokenMetadata[tokenId] = SBTMetadata({
            poolId: poolId,
            donor: to,
            totalDonated: amount,
            mintedAt: block.timestamp,
            campaignType: campaignType,
            isActive: true
        });
        
        donorPoolToToken[to][poolId] = tokenId;
        
        // Generate and set token URI
        string memory uri = _generateTokenURI(tokenId);
        _setTokenURI(tokenId, uri);
        
        emit SBTMinted(tokenId, to, poolId, amount, campaignType);
        
        return tokenId;
    }
    
    /**
     * @notice Update SBT metadata when donor makes additional donations
     * @param donor Donor address
     * @param poolId Campaign pool ID
     * @param additionalAmount Amount to add to total donated
     */
    function updateDonation(
        address donor,
        uint256 poolId,
        uint256 additionalAmount
    ) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = donorPoolToToken[donor][poolId];
        require(tokenId != 0, "SBT: No SBT found for this donor and pool");
        require(tokenMetadata[tokenId].isActive, "SBT: Token is not active");
        
        tokenMetadata[tokenId].totalDonated += additionalAmount;
        
        // Update token URI with new amount
        string memory uri = _generateTokenURI(tokenId);
        _setTokenURI(tokenId, uri);
        
        emit SBTUpdated(tokenId, tokenMetadata[tokenId].totalDonated);
    }
    
    /**
     * @notice Burn SBT (admin only, e.g., if donation refunded due to fraud)
     * @param tokenId Token ID to burn
     * @param reason Reason for burning
     */
    function burn(uint256 tokenId, string memory reason) external onlyRole(ADMIN_ROLE) {
        require(_ownerOf(tokenId) != address(0), "SBT: Token does not exist");
        
        address donor = tokenMetadata[tokenId].donor;
        uint256 poolId = tokenMetadata[tokenId].poolId;
        
        tokenMetadata[tokenId].isActive = false;
        donorPoolToToken[donor][poolId] = 0;
        
        _burn(tokenId);
        
        emit SBTBurned(tokenId, donor, reason);
    }
    
    /**
     * @notice Generate on-chain JSON metadata for token
     * @param tokenId Token ID
     * @return Base64-encoded JSON metadata URI
     */
    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        SBTMetadata memory meta = tokenMetadata[tokenId];
        
        bytes memory json = abi.encodePacked(
            '{"name": "ZKT Donation SBT #',
            tokenId.toString(),
            '", "description": "Soulbound token proving contribution to ZKT campaign pool #',
            meta.poolId.toString(),
            '", "image": "ipfs://QmZKTDonationBadge", "attributes": [',
            '{"trait_type": "Pool ID", "value": "',
            meta.poolId.toString(),
            '"}, {"trait_type": "Campaign Type", "value": "',
            meta.campaignType,
            '"}, {"trait_type": "Total Donated", "value": "',
            meta.totalDonated.toString(),
            ' IDRX"}, {"trait_type": "Minted At", "value": "',
            meta.mintedAt.toString(),
            '"}, {"trait_type": "Status", "value": "',
            meta.isActive ? "Active" : "Burned",
            '"}]}'
        );
        
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(json)
            )
        );
    }
    
    /**
     * @notice Get SBT token ID for a donor and pool
     * @param donor Donor address
     * @param poolId Pool ID
     * @return tokenId (0 if no SBT exists)
     */
    function getTokenIdForDonorAndPool(address donor, uint256 poolId) 
        external 
        view 
        returns (uint256) 
    {
        return donorPoolToToken[donor][poolId];
    }
    
    /**
     * @notice Override transfer functions to make token non-transferable (soulbound)
     * @dev Only allow transfers during minting (from address(0)) and burning (to address(0))
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0)) and burning (to == address(0))
        require(
            from == address(0) || to == address(0),
            "SBT: Token is non-transferable (soulbound)"
        );
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @notice Get total number of SBTs minted
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @notice Required override for AccessControl + ERC721
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
