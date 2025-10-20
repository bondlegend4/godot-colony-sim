# ModelicaNFT Smart Contract Documentation

## Overview

The ModelicaNFT smart contract enables the creation, management, and trading of Modelica physics models as NFTs (Non-Fungible Tokens) on the blockchain with **full on-chain storage** of model code.

## Vision

Create a decentralized marketplace for physics models where:
- **Creators** can publish and monetize their Modelica models
- **Users** can discover, purchase, and use verified models
- **Models** are permanently stored on-chain, ensuring longevity
- **Versions** are tracked, creating an auditable history
- **Licenses** are enforced through smart contracts

## Architecture

```
┌────────────────────────────────────────────────┐
│           Blockchain (Base Sepolia)            │
│                                                │
│  ┌──────────────────────────────────────┐     │
│  │     ModelicaNFT Smart Contract        │     │
│  │                                       │     │
│  │  - Model Storage (on-chain)          │     │
│  │  - Version Control                    │     │
│  │  - Ownership (ERC-721)                │     │
│  │  - Verification System                │     │
│  │  - Parameter Storage                  │     │
│  └──────────────────────────────────────┘     │
│                                                │
└────────────────────────────────────────────────┘
                     ↕
┌────────────────────────────────────────────────┐
│              Client Applications               │
│                                                │
│  - Web3 dApp (browse/purchase models)         │
│  - Godot Integration (use models in-game)     │
│  - OpenModelica Plugin (import from chain)    │
└────────────────────────────────────────────────┘
```

## Key Features

### 1. On-Chain Storage
**Unlike** typical NFTs that store metadata on IPFS:
- ✅ Model code stored **directly on blockchain**
- ✅ **No external dependencies** (no IPFS, no centralized servers)
- ✅ **Permanent availability** as long as blockchain exists
- ✅ **Atomic transactions** - model and metadata in one transaction

**Trade-offs:**
- Higher gas costs for large models
- Block gas limit constraints (~30M gas)
- Best for models <50KB

### 2. Version Control System
- Each model can have multiple versions
- Complete code stored for each version
- Timestamps for all versions
- Immutable history

### 3. Verification System
- Contract owner can verify models
- Verified badge for quality assurance
- Community trust indicator

### 4. License Management
- Store license type (MIT, GPL, Commercial, etc.)
- On-chain license enforcement
- Royalty potential (future)

### 5. Dependency Tracking
- Record which models depend on others
- Build dependency graphs
- Ensure compatibility

## Smart Contract Interface

### Core Data Structures

#### ModelMetadata
```solidity
struct ModelMetadata {
    string name;              // Model name
    string description;       // Description
    string modelCode;         // Full Modelica code (on-chain!)
    string license;           // License type
    string[] dependencies;    // Other models required
    uint256 createdAt;        // Creation timestamp
    uint256 currentVersion;   // Current version number
    address creator;          // Creator address
    bool verified;            // Verification status
}
```

#### Version
```solidity
struct Version {
    uint256 versionNumber;
    string modelCode;         // Code for this version
    uint256 timestamp;
    string changeLog;         // What changed
}
```

### Main Functions

#### createModel
```solidity
function createModel(
    string memory _name,
    string memory _description,
    string memory _modelCode,
    string memory _license,
    string[] memory _dependencies
) public returns (uint256)
```

**Purpose:** Create and mint a new model NFT

**Parameters:**
- `_name` - Model name (e.g., "SimpleThermalMVP")
- `_description` - Model description
- `_modelCode` - Complete Modelica code
- `_license` - License identifier (e.g., "MIT")
- `_dependencies` - Array of dependency model names

**Returns:** Token ID of newly minted NFT

**Events:**
- `ModelCreated(uint256 tokenId, address creator, string name)`

**Example:**
```javascript
const modelCode = `
model SimpleThermalMVP
  input Boolean heaterOn;
  output Real temperature(start=250.0);
  // ... rest of model
end SimpleThermalMVP;
`;

const tx = await modelicaNFT.createModel(
    "SimpleThermalMVP",
    "Minimal thermal model for habitat simulation",
    modelCode,
    "MIT",
    []  // No dependencies
);

const receipt = await tx.wait();
const tokenId = receipt.events[0].args.tokenId;
```

#### updateModel
```solidity
function updateModel(
    uint256 _tokenId,
    string memory _newModelCode
) public
```

**Purpose:** Update model with new version

**Requirements:**
- Caller must be model owner
- Creates new version entry
- Increments version number

**Example:**
```javascript
const newCode = `
model SimpleThermalMVP
  // Version 2.0 with improved heat loss calculation
  input Boolean heaterOn;
  output Real temperature(start=250.0);
  parameter Real lossCoefficient = 2.5;  // Updated!
  // ... rest of model
end SimpleThermalMVP;
`;

await modelicaNFT.updateModel(tokenId, newCode);
```

#### getModel
```solidity
function getModel(uint256 _tokenId) 
    public view 
    returns (ModelMetadata memory)
```

**Purpose:** Retrieve model metadata and code

**Returns:** Complete ModelMetadata struct

**Example:**
```javascript
const model = await modelicaNFT.getModel(tokenId);
console.log("Name:", model.name);
console.log("Code:", model.modelCode);
console.log("Version:", model.currentVersion.toString());
console.log("Creator:", model.creator);
```

#### getModelCode
```solidity
function getModelCode(uint256 _tokenId) 
    public view 
    returns (string memory)
```

**Purpose:** Get just the model code (current version)

**Example:**
```javascript
const code = await modelicaNFT.getModelCode(tokenId);
// Write to file
fs.writeFileSync('SimpleThermalMVP.mo', code);
```

#### verifyModel
```solidity
function verifyModel(uint256 _tokenId) public onlyOwner
```

**Purpose:** Mark model as verified (quality assurance)

**Requirements:**
- Only contract owner can verify
- Used for community trust

**Example:**
```javascript
// As contract owner
await modelicaNFT.verifyModel(tokenId);
```

#### setModelParameter / getModelParameter
```solidity
function setModelParameter(
    uint256 _tokenId,
    string memory _key,
    string memory _value
) public

function getModelParameter(
    uint256 _tokenId,
    string memory _key
) public view returns (string memory)
```

**Purpose:** Store custom key-value metadata

**Use Cases:**
- Simulation settings
- Recommended solvers
- Performance metrics
- Documentation URLs

**Example:**
```javascript
// Set parameters
await modelicaNFT.setModelParameter(tokenId, "simulationTime", "100");
await modelicaNFT.setModelParameter(tokenId, "solver", "dassl");
await modelicaNFT.setModelParameter(tokenId, "testedVersion", "OMC 1.26.0");

// Get parameters
const simTime = await modelicaNFT.getModelParameter(tokenId, "simulationTime");
console.log("Simulation time:", simTime); // "100"
```

## Integration Patterns

### Pattern 1: Publish Model to Blockchain

```javascript
// publish_model.js
const fs = require('fs');
const { ethers } = require('hardhat');

async function publishModel(modelPath) {
    // Read model file
    const modelCode = fs.readFileSync(modelPath, 'utf8');
    
    // Extract metadata from model
    const name = extractModelName(modelCode);
    const description = extractDocumentation(modelCode);
    
    // Deploy to blockchain
    const ModelicaNFT = await ethers.getContractFactory("ModelicaNFT");
    const nft = await ModelicaNFT.attach(CONTRACT_ADDRESS);
    
    const tx = await nft.createModel(
        name,
        description,
        modelCode,
        "MIT",
        []
    );
    
    const receipt = await tx.wait();
    const tokenId = receipt.events[0].args.tokenId;
    
    console.log(`✓ Model published! Token ID: ${tokenId}`);
    console.log(`View at: https://basescan.org/token/${CONTRACT_ADDRESS}?a=${tokenId}`);
    
    return tokenId;
}

// Usage
publishModel('./models/SimpleThermalMVP.mo');
```

### Pattern 2: Download Model from Blockchain

```javascript
// download_model.js
async function downloadModel(tokenId, outputPath) {
    const nft = await ethers.getContractAt("ModelicaNFT", CONTRACT_ADDRESS);
    
    // Get model data
    const model = await nft.getModel(tokenId);
    
    // Write to file
    fs.writeFileSync(outputPath, model.modelCode);
    
    // Write metadata
    const metadata = {
        name: model.name,
        description: model.description,
        license: model.license,
        creator: model.creator,
        version: model.currentVersion.toString(),
        createdAt: new Date(model.createdAt.toNumber() * 1000).toISOString(),
        verified: model.verified
    };
    
    fs.writeFileSync(
        outputPath.replace('.mo', '.json'),
        JSON.stringify(metadata, null, 2)
    );
    
    console.log(`✓ Model downloaded to ${outputPath}`);
}

// Usage
downloadModel(1, './downloaded/SimpleThermalMVP.mo');
```

### Pattern 3: Godot Integration

```gdscript
# blockchain_model_loader.gd
extends Node
class_name BlockchainModelLoader

const WEB3_RPC = "https://sepolia.base.org"
const CONTRACT_ADDRESS = "0x..." # Your deployed contract

signal model_downloaded(model_code: String)
signal download_failed(error: String)

func download_model_from_chain(token_id: int):
    """Download model from blockchain and load into game"""
    print("Downloading model #%d from blockchain..." % token_id)
    
    # Call smart contract via HTTP RPC
    var query = {
        "jsonrpc": "2.0",
        "method": "eth_call",
        "params": [{
            "to": CONTRACT_ADDRESS,
            "data": _encode_function_call("getModelCode", [token_id])
        }, "latest"],
        "id": 1
    }
    
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_model_received)
    
    http.request(
        WEB3_RPC,
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        JSON.stringify(query)
    )

func _on_model_received(result, response_code, headers, body):
    if response_code != 200:
        download_failed.emit("HTTP error: %d" % response_code)
        return
    
    var json = JSON.parse_string(body.get_string_from_utf8())
    var model_code = _decode_string(json.result)
    
    # Save to local file
    var file = FileAccess.open("user://downloaded_model.mo", FileAccess.WRITE)
    file.store_string(model_code)
    file.close()
    
    print("✓ Model downloaded and saved")
    model_downloaded.emit(model_code)

func _encode_function_call(function_name: String, params: Array) -> String:
    # Simplified - use proper ABI encoding in production
    return "0x..." # Function signature + encoded params

func _decode_string(hex_data: String) -> String:
    # Decode hex string to UTF-8
    # Simplified implementation
    return ""
```

### Pattern 4: Model Marketplace dApp

```javascript
// marketplace.js - React component
import { ethers } from 'ethers';
import ModelicaNFTABI from './ModelicaNFT.json';

function ModelMarketplace() {
    const [models, setModels] = useState([]);
    const [loading, setLoading] = useState(true);
    
    useEffect(() => {
        loadModels();
    }, []);
    
    async function loadModels() {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const contract = new ethers.Contract(
            CONTRACT_ADDRESS,
            ModelicaNFTABI,
            provider
        );
        
        // Get all model creation events
        const filter = contract.filters.ModelCreated();
        const events = await contract.queryFilter(filter);
        
        // Load model data
        const modelData = await Promise.all(
            events.map(async (event) => {
                const tokenId = event.args.tokenId;
                const model = await contract.getModel(tokenId);
                return {
                    tokenId: tokenId.toString(),
                    name: model.name,
                    description: model.description,
                    creator: model.creator,
                    verified: model.verified,
                    license: model.license,
                    version: model.currentVersion.toString()
                };
            })
        );
        
        setModels(modelData);
        setLoading(false);
    }
    
    async function downloadModel(tokenId) {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const contract = new ethers.Contract(
            CONTRACT_ADDRESS,
            ModelicaNFTABI,
            provider
        );
        
        const code = await contract.getModelCode(tokenId);
        const model = await contract.getModel(tokenId);
        
        // Create download
        const blob = new Blob([code], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${model.name}.mo`;
        a.click();
    }
    
    return (
        <div className="marketplace">
            <h1>Modelica Model Marketplace</h1>
            {loading ? (
                <p>Loading models...</p>
            ) : (
                <div className="model-grid">
                    {models.map(model => (
                        <ModelCard 
                            key={model.tokenId}
                            model={model}
                            onDownload={() => downloadModel(model.tokenId)}
                        />
                    ))}
                </div>
            )}
        </div>
    );
}

function ModelCard({ model, onDownload }) {
    return (
        <div className="model-card">
            <h3>
                {model.name}
                {model.verified && <span className="verified">✓</span>}
            </h3>
            <p>{model.description}</p>
            <div className="metadata">
                <span>License: {model.license}</span>
                <span>Version: {model.version}</span>
                <span>Creator: {model.creator.slice(0, 8)}...</span>
            </div>
            <button onClick={onDownload}>Download Model</button>
        </div>
    );
}
```

## Gas Optimization Strategies

### Problem: Large Models = High Gas Costs

**Example Gas Costs (Base Sepolia):**
- 1 KB model: ~50,000 gas (~$0.01)
- 10 KB model: ~500,000 gas (~$0.10)
- 50 KB model: ~2,500,000 gas (~$0.50)
- 100 KB model: May exceed block gas limit!

### Solution 1: Model Compression

```javascript
// compress_model.js
const pako = require('pako');

function compressModel(modelCode) {
    // Compress using gzip
    const compressed = pako.gzip(modelCode);
    const base64 = Buffer.from(compressed).toString('base64');
    return base64;
}

function decompressModel(compressedBase64) {
    const buffer = Buffer.from(compressedBase64, 'base64');
    const decompressed = pako.ungzip(buffer, { to: 'string' });
    return decompressed;
}

// Usage
const original = fs.readFileSync('SimpleThermalMVP.mo', 'utf8');
const compressed = compressModel(original);

console.log(`Original: ${original.length} bytes`);
console.log(`Compressed: ${compressed.length} bytes`);
console.log(`Savings: ${((1 - compressed.length/original.length) * 100).toFixed(1)}%`);

// Store compressed version on-chain
await nft.createModel(name, description, compressed, license, deps);
```

### Solution 2: Chunked Storage

For very large models, split into chunks:

```solidity
// ModelicaNFT_Chunked.sol
mapping(uint256 => string[]) private modelChunks;

function createModelChunked(
    string memory _name,
    string[] memory _chunks,
    // ... other params
) public {
    uint256 tokenId = _tokenIdCounter.current();
    modelChunks[tokenId] = _chunks;
    // ... rest of creation
}

function getModelCode(uint256 _tokenId) public view returns (string memory) {
    string[] memory chunks = modelChunks[_tokenId];
    return _concatenateChunks(chunks);
}
```

### Solution 3: Hybrid Approach

Store hash on-chain, full code on IPFS:

```solidity
struct ModelMetadata {
    string name;
    string ipfsHash;          // IPFS content hash
    bytes32 codeHash;         // On-chain verification hash
    // ... other fields
}

function verifyModelCode(
    uint256 _tokenId,
    string memory _code
) public view returns (bool) {
    return keccak256(bytes(_code)) == models[_tokenId].codeHash;
}
```

## Security Considerations

### 1. Input Validation

```solidity
function createModel(
    string memory _name,
    string memory _modelCode,
    // ...
) public {
    // Validate inputs
    require(bytes(_name).length > 0, "Name cannot be empty");
    require(bytes(_name).length <= 100, "Name too long");
    require(bytes(_modelCode).length > 0, "Model code cannot be empty");
    require(bytes(_modelCode).length <= 50000, "Model too large"); // 50KB limit
    
    // ... rest of function
}
```

### 2. Access Control

```solidity
// Only creator can update
function updateModel(uint256 _tokenId, string memory _code) public {
    require(ownerOf(_tokenId) == msg.sender, "Not model owner");
    // ... update logic
}

// Only verified creators can mark as verified
function verifyModel(uint256 _tokenId) public onlyOwner {
    models[_tokenId].verified = true;
}
```

### 3. Reentrancy Protection

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ModelicaNFT is ERC721, ReentrancyGuard {
    function createModel(...) public nonReentrant returns (uint256) {
        // Safe from reentrancy attacks
    }
}
```

### 4. Code Injection Prevention

```solidity
// Sanitize model code before storage
function _sanitizeCode(string memory _code) private pure returns (string memory) {
    // Remove potentially malicious content
    // In practice, validation happens off-chain before submission
    return _code;
}
```

## Deployment Guide

### Prerequisites

```bash
npm install --save-dev hardhat
npm install @openzeppelin/contracts
npm install dotenv
```

### Hardhat Configuration

```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
    solidity: "0.8.20",
    networks: {
        "base-sepolia": {
            url: "https://sepolia.base.org",
            accounts: [process.env.PRIVATE_KEY],
            chainId: 84532
        },
        "base-mainnet": {
            url: "https://mainnet.base.org",
            accounts: [process.env.PRIVATE_KEY],
            chainId: 8453
        }
    },
    etherscan: {
        apiKey: {
            "base-sepolia": process.env.BASESCAN_API_KEY
        }
    }
};
```

### Deployment Script

```javascript
// scripts/deploy.js
const hre = require("hardhat");

async function main() {
    console.log("Deploying ModelicaNFT...");
    
    const ModelicaNFT = await hre.ethers.getContractFactory("ModelicaNFT");
    const nft = await ModelicaNFT.deploy();
    
    await nft.waitForDeployment();
    
    const address = await nft.getAddress();
    console.log("ModelicaNFT deployed to:", address);
    
    // Verify on Basescan
    if (network.name !== "hardhat") {
        console.log("Waiting for block confirmations...");
        await nft.deploymentTransaction().wait(5);
        
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: []
        });
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Deploy Commands

```bash
# Test locally
npx hardhat test

# Deploy to Base Sepolia (testnet)
npx hardhat run scripts/deploy.js --network base-sepolia

# Deploy to Base Mainnet (production)
npx hardhat run scripts/deploy.js --network base-mainnet

# Verify contract
npx hardhat verify --network base-sepolia DEPLOYED_ADDRESS
```

## Testing

### Test Suite

```javascript
// test/ModelicaNFT.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ModelicaNFT", function () {
    let nft;
    let owner, creator, buyer;
    
    beforeEach(async function () {
        [owner, creator, buyer] = await ethers.getSigners();
        
        const ModelicaNFT = await ethers.getContractFactory("ModelicaNFT");
        nft = await ModelicaNFT.deploy();
    });
    
    describe("Model Creation", function () {
        it("Should create a new model", async function () {
            const modelCode = "model Test\nend Test;";
            
            const tx = await nft.connect(creator).createModel(
                "TestModel",
                "A test model",
                modelCode,
                "MIT",
                []
            );
            
            const receipt = await tx.wait();
            const tokenId = receipt.events[0].args.tokenId;
            
            expect(await nft.ownerOf(tokenId)).to.equal(creator.address);
            
            const model = await nft.getModel(tokenId);
            expect(model.name).to.equal("TestModel");
            expect(model.modelCode).to.equal(modelCode);
        });
        
        it("Should reject empty model name", async function () {
            await expect(
                nft.createModel("", "Description", "code", "MIT", [])
            ).to.be.revertedWith("Name cannot be empty");
        });
    });
    
    describe("Model Updates", function () {
        it("Should update model and create new version", async function () {
            // Create model
            const tx1 = await nft.connect(creator).createModel(
                "Test", "Desc", "v1 code", "MIT", []
            );
            const tokenId = (await tx1.wait()).events[0].args.tokenId;
            
            // Update model
            await nft.connect(creator).updateModel(tokenId, "v2 code");
            
            const model = await nft.getModel(tokenId);
            expect(model.currentVersion).to.equal(2);
            expect(model.modelCode).to.equal("v2 code");
        });
        
        it("Should reject update from non-owner", async function () {
            const tx = await nft.connect(creator).createModel(
                "Test", "Desc", "code", "MIT", []
            );
            const tokenId = (await tx.wait()).events[0].args.tokenId;
            
            await expect(
                nft.connect(buyer).updateModel(tokenId, "hacked code")
            ).to.be.revertedWith("Not model owner");
        });
    });
    
    describe("Verification", function () {
        it("Should allow owner to verify model", async function () {
            const tx = await nft.connect(creator).createModel(
                "Test", "Desc", "code", "MIT", []
            );
            const tokenId = (await tx.wait()).events[0].args.tokenId;
            
            await nft.connect(owner).verifyModel(tokenId);
            
            const model = await nft.getModel(tokenId);
            expect(model.verified).to.be.true;
        });
        
        it("Should reject verification from non-owner", async function () {
            const tx = await nft.connect(creator).createModel(
                "Test", "Desc", "code", "MIT", []
            );
            const tokenId = (await tx.wait()).events[0].args.tokenId;
            
            await expect(
                nft.connect(creator).verifyModel(tokenId)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });
});
```

## Future Enhancements

### 1. Royalty System

```solidity
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract ModelicaNFT is ERC721, ERC2981 {
    function setModelRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint96 _feeNumerator
    ) public {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }
}
```

### 2. Model Dependencies NFT-Based

```solidity
function createModel(
    string memory _name,
    uint256[] memory _dependencyTokenIds  // Instead of strings
) public {
    // Verify all dependency NFTs exist
    for (uint i = 0; i < _dependencyTokenIds.length; i++) {
        require(_exists(_dependencyTokenIds[i]), "Dependency not found");
    }
    // ... rest of creation
}
```

### 3. Access Control / Paywalls

```solidity
mapping(uint256 => uint256) public modelPrice;
mapping(uint256 => mapping(address => bool)) public hasAccess;

function purchaseAccess(uint256 _tokenId) public payable {
    require(msg.value >= modelPrice[_tokenId], "Insufficient payment");
    hasAccess[_tokenId][msg.sender] = true;
    payable(ownerOf(_tokenId)).transfer(msg.value);
}

function getModelCode(uint256 _tokenId) public view returns (string memory) {
    require(
        hasAccess[_tokenId][msg.sender] || ownerOf(_tokenId) == msg.sender,
        "Access denied"
    );
    return models[_tokenId].modelCode;
}
```

### 4. Model Composition

```solidity
function composeModel(
    string memory _name,
    uint256[] memory _componentTokenIds,
    string memory _compositionCode
) public returns (uint256) {
    // Create composite model from existing NFTs
    // Require ownership or licenses for all components
}
```

## Use Cases

### 1. Open Source Model Library
- Creators publish free, open-source models
- Permanent, decentralized storage
- Attribution through NFT ownership
- Community verification system

### 2. Commercial Model Marketplace
- Sell access to proprietary models
- Royalties on model usage
- Version control for updates
- License enforcement

### 3. Research & Education
- Publish research models with DOI-like permanence
- Track citations through on-chain references
- Educational model collections
- Reproducible science

### 4. Game Asset Integration
- Physics models as game NFTs
- Trade simulation components
- Cross-game compatibility
- Creator economy for modders

## See Also

- [Smart Contract Source Code](../contracts/ModelicaNFT.sol)
- [OpenZeppelin ERC721](https://docs.openzeppelin.com/contracts/4.x/erc721)
- [Base Network Documentation](https://docs.base.org/)
- [Hardhat Documentation](https://hardhat.org/)