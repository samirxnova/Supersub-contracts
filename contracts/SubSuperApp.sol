// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {
  ISuperfluid,
  ISuperToken,
  ISuperApp,
  ISuperAgreement,
  SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { CFAv1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { SuperAppBase } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Constant Flow Agreement registration key, used to get the address from the host.
bytes32 constant CFA_ID = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

/// @dev Thrown when the callback caller is not the host.
error Unauthorized();

/// @dev Thrown when the token being streamed to this contract is invalid
error InvalidToken();

/// @dev Thrown when the agreement is other than the Constant Flow Agreement V1
error InvalidAgreement();

contract Subscription_SuperApp is SuperAppBase, ERC721, ERC721Enumerable, Ownable {
  using CFAv1Library for CFAv1Library.InitData;
  using Counters for Counters.Counter;

  CFAv1Library.InitData public cfaV1Lib;
  ISuperToken internal immutable acceptedToken;
  Counters.Counter private passTracker;
  ISuperfluid private host;

  // User => tokenId
  /// @dev Active Pass Registry of Subscribers, 0 means no active pass
  mapping(address => uint256) public activePass;

  // tokenId => active
  /// @dev State Registry of Pass
  mapping(uint256 => bool) public passState;

  // tokenId => Total Transmitted Value
  /// @dev Registry on value transmitted per pass
  mapping(uint256 => uint256) public TTV;
  // mapping(uint256 => uint256) public permaTier;

  uint256[] public tiers;
  string public w3name;

  event Subscription_Created(address subscriber);
  event Subscription_Updated(address subscriber);
  event Subscription_Terminated(address subscriber);

  constructor(
    ISuperfluid _host,
    ISuperToken _acceptedToken,
    string memory _name,
    string memory _symbol,
    uint256[] memory _tiers
  ) ERC721(_name, _symbol) {
    assert(address(_host) != address(0));
    assert(address(_acceptedToken) != address(0));

    acceptedToken = _acceptedToken;
    host = _host;

    cfaV1Lib = CFAv1Library.InitData({ host: host, cfa: IConstantFlowAgreementV1(address(host.getAgreementClass(CFA_ID))) });

    // Registers Super App, indicating it is the final level (it cannot stream to other super
    // apps), and that the `before*` callbacks should not be called on this contract, only the
    // `after*` callbacks.
    host.registerApp(SuperAppDefinitions.APP_LEVEL_FINAL | SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP);

    passTracker.increment(); //start passId at 1

    tiers = _tiers;
  }

  // ---------------------------------------------------------------------------------------------
  // MODIFIERS

  modifier onlyHost() {
    if (msg.sender != address(cfaV1Lib.host)) revert Unauthorized();
    _;
  }

  modifier onlyExpected(ISuperToken superToken, address agreementClass) {
    if (superToken != acceptedToken) revert InvalidToken();
    if (agreementClass != address(cfaV1Lib.cfa)) revert InvalidAgreement();
    _;
  }

  // ---------------------------------------------------------------------------------------------
  // SUPER APP CALLBACKS

  function afterAgreementCreated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId
    bytes calldata _agreementData,
    bytes calldata, // _cbdata,
    bytes calldata _ctx
  ) external override onlyExpected(_superToken, _agreementClass) onlyHost returns (bytes memory newCtx) {
    (address sender, ) = abi.decode(_agreementData, (address, address));

    if (balanceOf(sender) > 0) {
      uint256 passId = tokenOfOwnerByIndex(sender, 0);
      activePass[sender] = passId;
      passState[passId] = true;
    } else {
      _issuePass(sender);
    }

    emit Subscription_Created(sender);
    newCtx = _ctx;
  }

  function beforeAgreementUpdated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32 _agreementId,
    bytes calldata, /*agreementData*/
    bytes calldata /*ctx*/
  ) external view override onlyExpected(_superToken, _agreementClass) onlyHost returns (bytes memory) {
    (uint256 timestamp, int96 flowRate, , ) = cfaV1Lib.cfa.getFlowByID(_superToken, _agreementId);
    return abi.encode(timestamp, flowRate);
  }

  function afterAgreementUpdated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, // _agreementId,
    bytes calldata _agreementData,
    bytes calldata _cbdata,
    bytes calldata _ctx
  ) external override onlyExpected(_superToken, _agreementClass) onlyHost returns (bytes memory newCtx) {
    (uint256 oldTimestamp, int96 oldFlowRate) = abi.decode(_cbdata, (uint256, int96));
    (address sender, ) = abi.decode(_agreementData, (address, address));

    _logPass(activePass[sender], oldTimestamp, oldFlowRate);
    emit Subscription_Updated(sender);
    newCtx = _ctx;
  }

  function beforeAgreementTerminated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32 _agreementId,
    bytes calldata,
    bytes calldata
  ) external view override onlyExpected(_superToken, _agreementClass) onlyHost returns (bytes memory) {
    (uint256 timestamp, int96 flowRate, , ) = cfaV1Lib.cfa.getFlowByID(_superToken, _agreementId);
    return abi.encode(timestamp, flowRate);
  }

  function afterAgreementTerminated(
    ISuperToken, //_superToken,
    address, //_agreementClass,
    bytes32, // _agreementId,
    bytes calldata _agreementData,
    bytes calldata _cbdata,
    bytes calldata _ctx
  ) external override onlyHost returns (bytes memory newCtx) {
    (address sender, ) = abi.decode(_agreementData, (address, address));
    (uint256 timestamp, int96 flowRate) = abi.decode(_cbdata, (uint256, int96));

    uint256 passId = activePass[sender];

    if (passId > 0) {
      _logPass(passId, timestamp, flowRate);
      _deactivatePass(passId);
      _clearActivePass(sender);
    }

    emit Subscription_Terminated(sender);
    newCtx = _ctx;
  }

  // ---------------------------------------------------------------------------------------------
  // Interal
  function _issuePass(address to) internal {
    require(activePass[to] == 0, "SFA: Subscriber has active pass");
    uint256 passId = passTracker.current();
    _safeMint(to, passId, "");
    activePass[to] = passId;
    passState[passId] = true;
    passTracker.increment();
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);

    if (from != address(0) && from != to) {
      if (activePass[from] == tokenId) {
        (uint256 timestamp, int96 flowRate, , ) = cfaV1Lib.cfa.getFlow(acceptedToken, from, address(this));
        _logPass(tokenId, timestamp, flowRate);
        _deactivatePass(tokenId);
        _clearActivePass(from);
        cfaV1Lib.deleteFlow(from, address(this), acceptedToken);
      }
    }
  }

  function _deactivatePass(uint256 passId) internal {
    passState[passId] = false;
  }

  function _clearActivePass(address _subscriber) internal {
    activePass[_subscriber] = 0;
  }

  function _logPass(
    uint256 _passId,
    uint256 _timestamp,
    int96 _flowRate
  ) internal {
    (, uint256 _TTV) = _calculatePass(_passId, _timestamp, _flowRate);
    TTV[_passId] = _TTV;
    // permaTier[_passId] = _tier;
  }

  function _calculatePass(
    uint256 _passId,
    uint256 _timestamp,
    int96 _flowRate
  ) internal view returns (uint256 _tier, uint256 _TTV) {
    uint256 timeElapsed = block.timestamp - _timestamp;
    uint256 _added_TTV = timeElapsed * uint256(uint96(_flowRate));
    _TTV = _added_TTV + TTV[_passId];

    _tier = 0;
    for (uint256 i = 0; i < tiers.length; i++) {
      if (tiers[i] <= _TTV) {
        _tier = i;
      }
    }

    // _tier = _tier > permaTier[_passId] ? _tier : permaTier[_passId];
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  // ---------------------------------------------------------------------------------------------
  // External
  function switchPass(uint256 _newPassId) external {
    require(ownerOf(_newPassId) == msg.sender, "Not Owner of Pass");
    (uint256 timestamp, int96 flowRate, , ) = cfaV1Lib.cfa.getFlow(acceptedToken, msg.sender, address(this));
    require(timestamp > 0, "No stream active");

    uint256 oldPass = activePass[msg.sender];

    _logPass(oldPass, timestamp, flowRate);
    _deactivatePass(oldPass);
    activePass[msg.sender] = _newPassId;
  }

  function activeTier(address _user) public view returns (uint256) {
    require(activePass[_user] > 0, "User has no active Pass");
    (uint256 timestamp, int96 flowRate, , ) = cfaV1Lib.cfa.getFlow(acceptedToken, _user, address(this));
    (uint256 tier, ) = _calculatePass(activePass[_user], timestamp, flowRate);
    return tier;
  }

  function updateTier(uint256[] calldata _newTiers) external onlyOwner {
    tiers = _newTiers;
  }

  function getPassdata(uint256 _tokenId)
    public
    view
    returns (
      bool active,
      uint256 passBalance,
      uint256 balanceTimestamp,
      int96 flowRate,
      uint256 tier,
      uint256 toNextTier
    )
  {
    require(_exists(_tokenId), "Invalid PassId");
    address owner = ownerOf(_tokenId);
    (uint256 timestamp, int96 _flowRate, , ) = cfaV1Lib.cfa.getFlow(acceptedToken, owner, address(this));
    (tier, passBalance) = _calculatePass(_tokenId, timestamp, _flowRate);

    active = passState[_tokenId];
    flowRate = _flowRate;
    balanceTimestamp = block.timestamp;

    if (tier < tiers.length - 1) {
      uint256 nextTier = tiers[tier + 1];
      toNextTier = nextTier - passBalance;
    } else {
      toNextTier = 0;
    }
  }

  function generalInfo()
    external
    view
    returns (
      string memory subName,
      string memory subSymbol,
      string memory subW3name,
      uint256[] memory subTiers
    )
  {
    subName = name();
    subSymbol = symbol();
    subW3name = w3name;
    subTiers = tiers;
  }

  function payout() external onlyOwner {
    acceptedToken.transferAll(msg.sender);
  }

  function updateW3Name(string memory _w3name) external onlyOwner {
    w3name = _w3name;
  }

  function getPassdataViaAddress(address _target) external view returns (bool active, uint256 tier) {
    uint256 passId = activePass[_target];
    if (passId == 0) {
      active = false;
      tier = 0;
    } else {
      (active, , , , tier, ) = getPassdata(passId);
    }
  }

  /// @dev This Method only exsits for DEMO PURPOSES ONLY.
  // In the front-end users can emulate buying the pass from opensea, to shortcircuit the protocol issues a pass directly
  function airdropPass(uint256 _startBalance, address _receiver) external {
    require(balanceOf(_receiver) == 0, "SSA: Receiver already owns a pass");
    _issuePass(_receiver);
    uint256 passId = activePass[_receiver];
    TTV[passId] = _startBalance;
    passState[passId] = false;
  }
}
