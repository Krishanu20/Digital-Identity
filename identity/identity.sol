// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DigitalIdentity
 * @dev A smart contract for managing decentralized digital identities
 * @author Your Name
 */
contract DigitalIdentity {
    // Events
    event IdentityCreated(address indexed user, string name);
    event IdentityUpdated(address indexed user, string field);
    event CredentialAdded(address indexed user, address indexed issuer, string credentialType);
    event CredentialRevoked(address indexed user, address indexed issuer, string credentialType);

    // Struct to store identity information
    struct Identity {
        string name;
        string email;
        string profileHash; // IPFS hash for additional profile data
        bool exists;
        uint256 createdAt;
        uint256 updatedAt;
    }

    // Struct to store credentials
    struct Credential {
        string credentialType; // e.g., "education", "employment", "certification"
        string dataHash; // IPFS hash containing credential data
        address issuer;
        uint256 issuedAt;
        bool isValid;
    }

    // Mappings
    mapping(address => Identity) private identities;
    mapping(address => Credential[]) private userCredentials;
    mapping(address => bool) public authorizedIssuers;
    
    // Contract owner
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyIdentityOwner(address _user) {
        require(msg.sender == _user, "Only identity owner can perform this action");
        _;
    }

    modifier identityExists(address _user) {
        require(identities[_user].exists, "Identity does not exist");
        _;
    }

    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Not an authorized credential issuer");
        _;
    }

    // Constructor
    constructor() {
        owner = msg.sender;
        authorizedIssuers[msg.sender] = true; // Owner is automatically an authorized issuer
    }

    /**
     * @dev Create a new digital identity
     * @param _name Full name of the user
     * @param _email Email address of the user
     * @param _profileHash IPFS hash containing additional profile information
     */
    function createIdentity(
        string memory _name,
        string memory _email,
        string memory _profileHash
    ) external {
        require(!identities[msg.sender].exists, "Identity already exists");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");

        identities[msg.sender] = Identity({
            name: _name,
            email: _email,
            profileHash: _profileHash,
            exists: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit IdentityCreated(msg.sender, _name);
    }

    /**
     * @dev Update existing identity information
     * @param _name New name (pass empty string to keep unchanged)
     * @param _email New email (pass empty string to keep unchanged)
     * @param _profileHash New profile hash (pass empty string to keep unchanged)
     */
    function updateIdentity(
        string memory _name,
        string memory _email,
        string memory _profileHash
    ) external onlyIdentityOwner(msg.sender) identityExists(msg.sender) {
        Identity storage identity = identities[msg.sender];

        if (bytes(_name).length > 0) {
            identity.name = _name;
            emit IdentityUpdated(msg.sender, "name");
        }
        
        if (bytes(_email).length > 0) {
            identity.email = _email;
            emit IdentityUpdated(msg.sender, "email");
        }
        
        if (bytes(_profileHash).length > 0) {
            identity.profileHash = _profileHash;
            emit IdentityUpdated(msg.sender, "profileHash");
        }

        identity.updatedAt = block.timestamp;
    }

    /**
     * @dev Add a credential to a user's identity (only authorized issuers)
     * @param _user Address of the user receiving the credential
     * @param _credentialType Type of credential (e.g., "degree", "certificate")
     * @param _dataHash IPFS hash containing the credential data
     */
    function addCredential(
        address _user,
        string memory _credentialType,
        string memory _dataHash
    ) external onlyAuthorizedIssuer identityExists(_user) {
        require(bytes(_credentialType).length > 0, "Credential type cannot be empty");
        require(bytes(_dataHash).length > 0, "Data hash cannot be empty");

        userCredentials[_user].push(Credential({
            credentialType: _credentialType,
            dataHash: _dataHash,
            issuer: msg.sender,
            issuedAt: block.timestamp,
            isValid: true
        }));

        emit CredentialAdded(_user, msg.sender, _credentialType);
    }

    /**
     * @dev Revoke a credential (only the original issuer can revoke)
     * @param _user Address of the user whose credential to revoke
     * @param _credentialIndex Index of the credential in the user's credential array
     */
    function revokeCredential(
        address _user,
        uint256 _credentialIndex
    ) external identityExists(_user) {
        require(_credentialIndex < userCredentials[_user].length, "Invalid credential index");
        
        Credential storage credential = userCredentials[_user][_credentialIndex];
        require(credential.issuer == msg.sender, "Only issuer can revoke credential");
        require(credential.isValid, "Credential already revoked");

        credential.isValid = false;
        
        emit CredentialRevoked(_user, msg.sender, credential.credentialType);
    }

    /**
     * @dev Get identity information for a user
     * @param _user Address of the user
     * @return name User's full name
     * @return email User's email address
     * @return profileHash IPFS hash of additional profile data
     * @return createdAt Timestamp when identity was created
     * @return updatedAt Timestamp when identity was last updated
     */
    function getIdentity(address _user) 
        external 
        view 
        identityExists(_user) 
        returns (
            string memory name,
            string memory email,
            string memory profileHash,
            uint256 createdAt,
            uint256 updatedAt
        ) 
    {
        Identity memory identity = identities[_user];
        return (
            identity.name,
            identity.email,
            identity.profileHash,
            identity.createdAt,
            identity.updatedAt
        );
    }

    /**
     * @dev Get all credentials for a user
     * @param _user Address of the user
     * @return credentialTypes Array of credential type strings
     * @return dataHashes Array of IPFS hashes containing credential data
     * @return issuers Array of addresses that issued each credential
     * @return issuedAts Array of timestamps when credentials were issued
     * @return validities Array of boolean values indicating credential validity
     */
    function getUserCredentials(address _user)
        external
        view
        identityExists(_user)
        returns (
            string[] memory credentialTypes,
            string[] memory dataHashes,
            address[] memory issuers,
            uint256[] memory issuedAts,
            bool[] memory validities
        )
    {
        uint256 length = userCredentials[_user].length;
        
        credentialTypes = new string[](length);
        dataHashes = new string[](length);
        issuers = new address[](length);
        issuedAts = new uint256[](length);
        validities = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            Credential memory cred = userCredentials[_user][i];
            credentialTypes[i] = cred.credentialType;
            dataHashes[i] = cred.dataHash;
            issuers[i] = cred.issuer;
            issuedAts[i] = cred.issuedAt;
            validities[i] = cred.isValid;
        }
    }

    /**
     * @dev Add an authorized credential issuer (only owner)
     * @param _issuer Address to authorize as credential issuer
     */
    function addAuthorizedIssuer(address _issuer) external onlyOwner {
        require(_issuer != address(0), "Invalid issuer address");
        authorizedIssuers[_issuer] = true;
    }

    /**
     * @dev Remove an authorized credential issuer (only owner)
     * @param _issuer Address to remove authorization
     */
    function removeAuthorizedIssuer(address _issuer) external onlyOwner {
        authorizedIssuers[_issuer] = false;
    }

    // Utility functions

    /**
     * @dev Check if an identity exists
     * @param _user Address to check
     * @return exists Boolean indicating if identity exists
     */
    function checkIdentityExists(address _user) external view returns (bool exists) {
        return identities[_user].exists;
    }

    /**
     * @dev Get the number of credentials for a user
     * @param _user Address of the user
     * @return count Number of credentials
     */
    function getCredentialCount(address _user) external view returns (uint256 count) {
        return userCredentials[_user].length;
    }
}# Digital-Identity
