// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./ICatMinter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// reseterRole which can modify the summonDelay and nom balances

contract CatStaker is AccessControl {

  modifier onlyAdmin {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
    _;
  }

  modifier onlyStakerAdmin {
    require(hasRole(STAKER_ADMIN_ROLE, msg.sender), "Not staker admin");
    _;
  }

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  bytes32 public constant STAKER_ADMIN_ROLE = keccak256("STAKER_ADMIN_ROLE");

  IERC20 public cat;
  ICatMinter public catMinter;

  uint256 public maxCats;
  uint256 public numCats;

  uint256 public maxStake;

  struct Stake {
    uint256 amount;
    uint256 startBlock;
  }
  mapping(address => Stake) public stakeRecords;

  // amount of nom needed to summon cat
  uint256 public nomFee;

  // fee in CAT to pay to reset delay
  uint256 public resetFee;

  // starting delay
  uint256 public startDelay;

  // initial rarity
  uint256 public rarity;

  // the amount of nom accrued by each account
  mapping(address => uint256) public nomBalances;

  // the additional delay between mintings for each account
  mapping(address => uint256) public summonDelay;

  // the block at which each account can summon
  mapping(address => uint256) public nextSummonTime;

  constructor() public {

    // Give caller admin permissions
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

    // Make the caller admin a staker admin
    grantRole(STAKER_ADMIN_ROLE, msg.sender);

    // starting fee is 1 CAT to reset
    resetFee = 1 * (10**18);

    // starting max stake of 5 CAT
    maxStake = 5 * (10**18);

    // starting delay is 3000 blocks, ~12 hours
    startDelay = 3000;

    // starting maxCats is 256
    maxCats = 256;

    // starting rarity is 1
    rarity = 1;
  }

  function addStake(uint256 amount) public {

    // award existing nom
    awardNom(msg.sender);

    // update to total amount
    uint256 newAmount = stakeRecords[msg.sender].amount.add(amount);

    // ensure the total is less than max stake
    require(newAmount <= maxStake, "Exceeds max stake");

    // update stake records
    stakeRecords[msg.sender] = Stake(
      newAmount,
      block.number
    );

    // initialize the summonDelay if it's 0
    if (summonDelay[msg.sender] == 0) {
      summonDelay[msg.sender] = startDelay;
    }

    // transfer tokens to contract
    cat.safeTransferFrom(msg.sender, address(this), amount);
  }

  function removeStake() public {
    // award nom
    awardNom(msg.sender);

    // calculate how much CAT to transfer back
    uint256 amountToTransfer = stakeRecords[msg.sender].amount;

    // remove stake records
    delete stakeRecords[msg.sender];

    // transfer tokens back
    cat.safeTransfer(msg.sender, amountToTransfer);
  }

  function emergencyRemoveStake() public {
    // calculate how much to award
    uint256 amountToTransfer = stakeRecords[msg.sender].amount;

    // remove stake records
    delete stakeRecords[msg.sender];

    // transfer tokens back
    cat.safeTransfer(msg.sender, amountToTransfer);
  }

  // Awards accumulated nom and resets startBlock
  function awardNom(address a) public {
    // If there is an existing amount staked, add the current accumulated amount and reset the block number
    if (stakeRecords[a].amount != 0) {
      uint256 nomAmount = stakeRecords[a].amount.mul(block.number.sub(stakeRecords[a].startBlock));
      nomBalances[a] = nomBalances[a].add(nomAmount);

      // reset the start block
      stakeRecords[a].startBlock = block.number;
    }
  }

  // Claim a cat
  function claimCat() public returns (uint256) {

    // award nom first
    awardNom(msg.sender);

    // check conditions
    require(nomBalances[msg.sender] >= nomFee, "Not enough NOM");
    require(block.number >= nextSummonTime[msg.sender], "Time isn't up yet");
    require(numCats < maxCats, "All cats are out");

    // remove nom fee from caller's nom balance
    nomBalances[msg.sender] = nomBalances[msg.sender].sub(nomFee);

    // update the next block where summon can happen
    nextSummonTime[msg.sender] = summonDelay[msg.sender] + block.number;

    // double the delay time
    summonDelay[msg.sender] = summonDelay[msg.sender].mul(2);

    // Update num cats count
    numCats = numCats.add(1);

    // mint the cat
    uint256 id = catMinter.mintCat(
      msg.sender,
      0,
      0,
      1,
      uint256(blockhash(block.number.sub(1))),
      0,
      rarity
    );

    // return new cat id
    return(id);
  }

  function resetDelay() public {
    // set delay to the starting value
    summonDelay[msg.sender] = startDelay;

    // move tokens to the CAT contract as fee
    cat.safeTransferFrom(msg.sender, address(cat), resetFee);
  }

  function moveTokens(address tokenAddress, address to, uint256 numTokens) public onlyAdmin {
    require(tokenAddress != address(cat), "Can't move CAT");
    IERC20 _token = IERC20(tokenAddress);
    _token.safeTransfer(to, numTokens);
  }

  function setCAT(address tokenAddress) public onlyAdmin {
    require(address(cat) == address(0), "already set");
    cat = IERC20(tokenAddress);
  }

  function setCatMinter(address a) public onlyAdmin {
    require(address(catMinter) == address(0), "already set");
    catMinter = ICatMinter(a);
  }

  function setRarity(uint256 r) public onlyAdmin {
    rarity = r;
  }

  function setMaxCats(uint256 m) public onlyAdmin {
    maxCats = m;
  }

  function setMaxStake(uint256 m) public onlyAdmin {
    maxStake = m;
  }

  function setStartDelay(uint256 s) public onlyAdmin {
    startDelay = s;
  }

  function setResetFee(uint256 f) public onlyAdmin {
    resetFee = f;
  }

  function setNomFee(uint256 f) public onlyAdmin {
    nomFee = f;
  }

  // Allows admin to add new staker admins
  function setStakerAdminRole(address a) public onlyAdmin {
    grantRole(STAKER_ADMIN_ROLE, a);
  }

  function setNomBalances(address a, uint256 d) public onlyStakerAdmin {
    nomBalances[a] = d;
  }

  function setSummonDelay(address a, uint256 d) public onlyStakerAdmin {
    summonDelay[a] = d;
  }

  function pendingNom(address a) public view returns(uint256) {
    uint256 nomAmount = stakeRecords[a].amount.mul(block.number.sub(stakeRecords[a].startBlock));
    return(nomAmount);
  }
}