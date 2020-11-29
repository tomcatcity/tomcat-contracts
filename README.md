# TomcatCity-Contracts

Architecture
The main contract is CatMinter.sol, which is the actual ERC-721 implementation. Using AccessControl, we can assign different contracts to be cat minters.

ICatMinter.sol is the minter interface, which is exposed to contracts with minting privileges, allowing them to mint and modify the on-chain data of cats.

The default Cat struct is in UsesCat.sol. Contracts which want to access on-chain information about a cat inherit from this contract.

CatStaker.sol is the main staking contract. Users can add and remove their staked CAT to generate Nom, which is then used to redeem cats.

CatSpawner.sol is the spawning contract, which takes in two cats and spawns a new cat.

The underlying token is CAT.sol, a token with a fee on transfer, settable from 1 to 10%.

Tests
There is a comprehensive set of tests in test/tests.js. Test coverage is close to 100%, and the comments explain the cases being tested for. See coverage/.
