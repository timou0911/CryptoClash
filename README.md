![LOGO](./LOGO.png)
# <p align="center"> CryptoClash </p>
<p align="center"> Strategic Battles for Market Dominance </p>

Table of Contents
------------------
- [Brief Introduciton]()
- [Idea Inspiration]()
- [Features]()
- [Project Structure(remember to add parts that use Chainlnk)]()
- [List of Frameworks and Libraries]()
- [Demo Video]()
- [Etherscan Link]()
- [Further Improvement and Features to Add]()

## Brief Introduction

This is an innovative economic strategy game based on AI and economic randomness. In the game, players assume dual roles as currency issuers and investors.

As currency issuers, players create their own currencies, enhance their trading volume and currency  price by organizing events, and promote their currencies based on market positioning and strategies. As investors, players analyze the market to buy and sell other players' currencies to generate profits as well as decrease other players’ currency prices.

Ultimately, player rankings are determined by total profits, challenging their economic acumen and strategic decision-making skills.

## Idea Inspiration

### AI's potential

Inspired by the powerful capabilities of AI, we are developing an economic strategy game that leverages AI to revolutionize and enhance game mechanics. We discovered that AI can be utilized for dynamic simulation and price prediction based on the prompts we provide.

### Madness of crypto

Beyond AI's abilities, we've been captivated by the wild, unpredictable nature of the crypto world, especially the exhilarating chaos of pump-and-dump schemes that happen all too often. This frenetic madness has not only inspired us but has become the centerpiece of our game, promising an electrifying and unpredictable gameplay experience where fortunes can be made or lost in the blink of an eye.

## Features (What it does)

### Token Issuance and Management

This game provides players with the opportunity to learn about and simulate investments, while also allowing them to experience working with and issuing their own currencies, such as controlling the number of their tokens on the market. This innovative approach aims to educate and engage players in the complexities of financial strategies and cryptocurrency markets, making learning both interactive and enjoyable.

### Trade Other Players’ Tokens to Profit or Dump the Price

In addition to managing their own tokens, players can trade others' tokens to make a profit. However, be cautious—after purchasing other tokens, their price may increase, benefiting the token issuer! Conversely, you can accumulate a significant amount of a token and then sell it all to dump the price. This is why our game dApp is called a strategy game, as it incorporates elements of game theory.

### Interplay Between AI-Powered Market Simulation and Players' Actions

Players' decisions will be closely monitored by the AI, which will simulate market responses based on their actions, creating a dynamic and interactive gameplay experience. As players make moves to promote their currencies, trade tokens, and strategize their investments, the AI will adjust the market conditions accordingly. This continuous feedback loop ensures that every decision has a significant impact, challenging players to think ahead and adapt their strategies in real time.

### More Randomness to The Market

Will the market be influenced solely by players? Absolutely not. To more accurately simulate the real-world financial environment, we've introduced elements of randomness to the game. Market conditions can be unpredictably affected by random events, causing certain token prices to fluctuate dramatically. These random events ensure that no two game sessions are ever the same, compelling players to remain vigilant, adaptable, and ready to seize opportunities or mitigate risks at any moment. This infusion of randomness not only enhances realism but also keeps the gameplay thrilling and unpredictable, mirroring the volatile nature of real-world markets.

## Project Structure (How we built it)

> Since we're building a game dApp supported by Chainlink products, it's better to have a central contract for creating new game instances, receiving Chainlink responses, and then distributing the responses to certain game instances.

### UpperControl.sol - Management Contract

It serves three main functionalities:

1. **Contract Factory**: Responsible for allowing players to create new game rounds and record them.
2. **Game Instances Tracking**: Monitors the state of game instances to prevent unauthorized access.
3. **Chainlink Callee and Information Distributor**: `UpperControl` is subscribed to Chainlink Functions, VRF, and Automation. When it receives data from Chainlink, it distributes the data to designated game instances or performs specific actions on them.

When a game instance needs random words or AI-generated data, it sends a signal along with information or prompts to `UpperColtrol`, and then `UpperContro`l requests Chainlink VRF or Functions. After it’s triggered by Chainlink, it sends received data back to the game instances.

### Game.sol - Each Round of the Game

### Chainlink Products Used

- Chalink Functions
- Chainlink VRF: decide which random event to be triggered.

## Game Flow

1. Players enter the game with an entry fee.
2. Players issued their own tokens and have 10000 stable coin initially.
3. Contract asks for random words and uses them to trigger random event types. (e.g., A company bought a token issued by player 1, so his token price pumps up.)
4. Contract sends random event type to AI along with token prices currently.
5. AI generates a detailed random event and decides each token price after the event then sends it back to the game contract.
6. Players will be notified of the event details and know the prices change.
7. Contract updates token prices.
8. Players receive the AI assistant’s investment advice and then buy and sell tokens issued by him and other players according to new token prices. (Players attempt to make a profit and dump prices of tokens issued by others to make them lose money.)
10. Loop for ten rounds, except the first round, AI will receive random event types, players’ trade action, and token prices now to generate more precise prices. After ten rounds, settle each player’s total balance(All the tokens issued by each player + stable coin) to decide the winner. The winner receives the entry fee of all players.

## List of Framework, Libraries, and Tools

### Smart Contract

- Framework
    - Foundry
- Contract Inheritation or Used
    - Chainlink-Brownie Contracts
    - Foundry Devops
    - VRFCoordinatorV2Interface
    - VRFConsumerBaseV2
    - FunctionsClient
    - FunctionsRequest
    - ConfirmedOwner
- Libraries
    - ethers.js

### Front End

- React
- Tailwind CSS

## Further Improvement & Features to Add (What's next for)

### Upgradeability

Currently, both `UpperControl.sol` and `Game.sol` aren’t upgradeable. This feature will be implemented soon.

### Thorough Testing

Only several functions are tested with unit tests now. Further unit tests and integration tests should be done.

### More Clean Chainlink Subscription Code

Currently, we make `UpperControl.sol` subscribed to Chainlink, and send received data to game instances. However, a better way is to make `UpperControl.sol` the subscription creator(add `createSubscription` method to the code), and add each game instance as a consumer(add `addConsumer.sol` to the code), then remove consumer after the game finished(add `removeConsumer` to the code). Due to limited time, we haven’t implemented it yet.
