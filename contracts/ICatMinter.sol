// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./UsesCat.sol";

interface ICatMinter is IERC721, UsesCat {

  function mintCat(address to,
                       uint256 parent1,
                       uint256 parent2,
                       uint256 gen,
                       uint256 bits,
                       uint256 exp,
                       uint256 rarity
                      ) external returns (uint256);

  function modifyCat(uint256 id,
                     bool ignoreZeros,
                     uint256 parent1,
                     uint256 parent2,
                     uint256 gen,
                     uint256 bits,
                     uint256 exp,
                     uint256 rarity
  ) external;

  function catRecords(uint256 id) external returns (Cat memory);

  function setTokenURI(uint256 id, string calldata uri) external;
}