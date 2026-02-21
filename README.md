# SentientGavel: Adaptive NFT Auction Price AI Contract

## Executive Summary

I have engineered **SentientGavel** to represent the next evolution in decentralized commerce on the Stacks blockchain. By merging the immutable logic of Clarity smart contracts with the predictive power of Artificial Intelligence, this system moves beyond the "set-and-forget" model of traditional auctions.

SentientGavel acts as a living marketplace. It listens to an authorized AI Oracle that feeds real-time market sentiment data into the contract. Whether the NFT market is in a state of "Irrational Exuberance" or a "Crypto Winter," the contract automatically recalibrates minimum bid thresholds and platform commissions to ensure market efficiency, seller protection, and buyer engagement.

---

## Key Features

### 1. Dynamic Price Adaptation

I have implemented a weighted multiplier system that calculates the `min-bid` for any given NFT based on its collection's sentiment score.

* **Extreme Bullishness (>80):** Automatically applies a +25% premium to the current price floor.
* **Extreme Bearishness (<20):** Automatically discounts the entry barrier by -25% to stimulate bidding.

### 2. Intelligent Commission Scaling

The contract features a `calculate-dynamic-commission` engine. Instead of a flat fee, the platform's take scales with market health:

* **Hype Mode:** 5% commission to capture value from high-velocity trading.
* **Subsidy Mode:** 1% commission to lower the friction for sellers in weak markets.
* **Standard Mode:** 2.5% baseline.

### 3. Bid Velocity Tracking

Every bid is logged with metadata, including the block height and total bid count. I designed the `bid-history` map to calculate "Volume Multipliers," which help the AI identify "trending" auctions in real-time.

### 4. Advanced Post-Auction Analytics

The `analyze-auction-performance` function provides a comprehensive "Post-Mortem" report. It evaluates price delta, bidding velocity, and an AI Feedback Score to suggest sentiment adjustments.

---

## Architectural Philosophy & Data Schema

The core philosophy of SentientGavel is **Adaptive Equilibrium**. Most smart contracts fail because they are rigid; they cannot react to the volatility inherent in the NFT space. To support this, I have structured the data layers to be both performant and transparent.

### Data Variables

* **`auction-counter`**: A global `uint` that tracks the total number of auctions created, ensuring unique identifiers for every listing.

### Data Maps

* **`auctions`**: Stores the core state of every listing.
* *Fields*: `seller`, `nft-id`, `collection-id`, `base-price`, `start-block`, `end-block`, `active`, `category`.


* **`bids`**: Tracks the current leading bid.
* *Fields*: `bidder`, `amount`, `block-height`.


* **`market-sentiment`**: The primary feed for AI data.
* *Fields*: Maps a `collection-id` to a `uint` (0-100).


* **`whitelisted-collections`**: A security map ensuring only verified projects can use the adaptive engine.
* **`bid-history`**: Stores aggregate data used for off-chain performance modeling.
* *Fields*: `total-bids`, `last-bid-block`, `volume-multiplier`.



---

## Function Reference

### I. Private Functions (Internal Logic)

These functions serve as the contract's "brain," handling calculations that are not directly accessible by users but drive the public-facing state changes.

* **`is-authorized`**: A security gatekeeper. I designed this to ensure that only the `CONTRACT-OWNER` or the designated `ORACLE-ADDR` can perform sensitive administrative tasks.
* **`calculate-dynamic-commission`**:
* **Logic**: Uses the `market-sentiment` map to return a value in basis points.
* **Impact**: It checks if sentiment is  (Hype) to set a 5% fee, or  (Weak) to set a 1% fee.


* **`calculate-adaptive-price`**:
* **Logic**: Multiplies the `current-price` by the `sentiment-mult` and divides by .
* **Impact**: Ensures that every new bid is mathematically tethered to broader market trends.



### II. Public Functions (State-Changing Operations)

These functions are the primary interface for users, sellers, and the AI oracle.

* **`start-auction`**: Initializes the auction state. It validates that the collection is whitelisted and that the duration falls within the safe range of  to  blocks.
* **`place-bid`**: This is a complex atomic operation. It calculates the AI-required minimum bid, checks against the 5% minimum increment rule, refunds the previous highest bidder, and locks the new STX amount.
* **`finalize-auction`**: The settlement engine. I included logic to deactivate the auction *before* fund transfer to prevent double-spending or re-entrancy. It settles funds to the seller and the owner.
* **`update-market-sentiment`**: The Oracle's entry point. It allows the AI to update the sentiment score (0-100) for specific collections.
* **`cancel-auction`**: A safety valve. An auction can *only* be cancelled if no bids have been placed.

### III. Read-Only Functions (Data Retrieval)

These functions provide transparency and data for off-chain analysis without costing gas.

* **`get-adaptive-multiplier`**: Provides a look-ahead at what the price multiplier currently is for a specific collection.
* **`analyze-auction-performance`**: An "Analytics-as-a-Service" endpoint. It returns a complex tuple containing:
* **Velocity**: Bids per 100 blocks.
* **Efficiency**: Delta from the reserve price.
* **Recommendation**: A signal ("HOT", "STEADY", "WEAK") that guides the AI on sentiment adjustments.



---

## Governance & Security

SentientGavel employs a "Least Privilege" model:

1. **Whitelist Enforcement**: Prevents malicious NFT transfers from clogging the AI logic.
2. **Oracle Constrainment**: The Oracle can only update sentiment scores; it cannot touch funds.
3. **Atomic Settlements**: All STX transfers are handled through `as-contract` calls, ensuring the contract remains the secure custodian of funds.

---

## License (MIT)

```text
Copyright (c) 2026 SentientGavel Project

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

```
