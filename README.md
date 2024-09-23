#   Supersub Contract

## Overview

The `Subscription_SuperApp` is a smart contract built on Ethereum that leverages Superfluid's Constant Flow Agreement (CFA) to manage subscriptions. It integrates ERC721 (NFTs) for issuing subscription passes and handles continuous payments using Superfluid streams. This contract enables users to subscribe, track their subscription tier, and handle payments seamlessly.

## Features

- **Subscription Management:** Users can subscribe by initiating a payment stream to the contract, which will issue them a unique ERC721 pass.
- **Flow-Based Subscriptions:** The contract tracks continuous payment flows from users and calculates tiers based on the total value transmitted.
- **Superfluid Integration:** Uses Superfluid’s Constant Flow Agreement to handle ongoing streams of payments.
- **ERC721 Passes:** Each user receives a non-transferable NFT pass, which represents their active subscription.
- **Tiers System:** Based on the total transmitted value (TTV), users are categorized into different subscription tiers.
- **Airdrop for Demo:** There's a demo feature for airdropping passes with a predefined balance, for front-end simulations.

## How It Works

1. **Subscription Creation:**
   - A user initiates a Superfluid stream to the contract using the accepted SuperToken.
   - Upon starting the stream, an NFT pass is minted for the user if they do not already have one.
   - The user's subscription is considered active, and they are assigned an active pass.

2. **Subscription Management:**
   - The contract continuously tracks the payment stream and updates the user’s tier based on the total value transmitted (TTV).
   - Tiers are updated based on the flow rate and duration of the subscription.

3. **Subscription Termination:**
   - If a user's stream is terminated, their pass is deactivated, and they lose access to subscription benefits.
   - The pass remains in their wallet but will no longer be valid for active subscription benefits.

4. **Tier Calculation:**
   - The contract determines the user's subscription tier based on the total value transmitted through their flow.
   - The contract supports multiple tiers, which can be adjusted by the owner.

## Contract Components

### Key Libraries and Interfaces

- **Superfluid Integration:**
  - `ISuperfluid`: Interface to interact with the Superfluid host.
  - `ISuperToken`: SuperToken interface for the accepted token.
  - `CFAv1Library`: A wrapper for the Constant Flow Agreement (CFA) library.

- **NFT Integration:**
  - `ERC721` and `ERC721Enumerable`: Used for issuing subscription passes as NFTs.
  - `Ownable`: Contract ownership functionality to restrict sensitive operations.

### State Variables

- **Subscription Pass Management:**
  - `activePass`: Maps each user to their active subscription pass ID.
  - `passState`: Tracks the active/inactive state of each pass.
  - `TTV`: Tracks the total transmitted value for each pass (used to calculate subscription tiers).

- **Subscription Tiers:**
  - `tiers`: An array of thresholds defining the different subscription levels.

### Events

- `Subscription_Created(address subscriber)`: Emitted when a user creates a new subscription.
- `Subscription_Updated(address subscriber)`: Emitted when a user's subscription is updated (i.e., flow rate changes).
- `Subscription_Terminated(address subscriber)`: Emitted when a user's subscription is terminated.

### Modifiers

- `onlyHost()`: Ensures that only the Superfluid host can call certain functions.
- `onlyExpected()`: Ensures that only valid SuperTokens and agreements are processed by the contract.

### Superfluid Callbacks

- `afterAgreementCreated`: Handles the creation of a new subscription stream and issues an NFT pass to the subscriber.
- `beforeAgreementUpdated` and `afterAgreementUpdated`: Used to update the subscription data when a user changes their flow rate.
- `beforeAgreementTerminated` and `afterAgreementTerminated`: Handles the termination of a subscription stream and deactivates the corresponding pass.

### External Functions

- **`switchPass(uint256 _newPassId)`**: Allows users to switch their active pass, transferring the benefits of their subscription to a new pass.
- **`activeTier(address _user)`**: Returns the active subscription tier for a given user.
- **`getPassdata(uint256 _tokenId)`**: Provides detailed information about a specific subscription pass.
- **`generalInfo()`**: Provides general information about the contract (name, symbol, W3 name, and subscription tiers).
- **`payout()`**: Allows the contract owner to withdraw all funds from the contract.
- **`updateW3Name(string _w3name)`**: Allows the owner to update the contract’s Web3 name.
- **`airdropPass(uint256 _startBalance, address _receiver)`**: A demo method to airdrop subscription passes with a specified balance.

## Deployment

1. **Prerequisites:**
   - Superfluid protocol setup.
   - A deployed SuperToken that users will use to stream payments.

2. **Deployment Steps:**
   - Deploy the `Subscription_SuperApp` contract, passing the Superfluid host address, the accepted SuperToken address, subscription tiers, and the desired NFT name and symbol.

3. **Post-Deployment:**
   - Register the contract as a SuperApp using the Superfluid host's `registerApp` method.
   - Set the tiers for the subscription using `updateTier` if needed.

## Demo

For demo purposes, use the `airdropPass` method to simulate users buying passes and subscribing to the service. This feature bypasses the Superfluid stream initiation for testing.
