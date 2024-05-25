-include .env

DEFAULT_ANVIL_KEY := 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
DEFAULT_ANVIL_ADDRESS := 0x90F79bf6EB2c4f870365E785982E1f101E93b906
DEFAULT_SEPOLIA_ADDRESS := 0x115F6cdf65789EF751D0EB1Bfb40533Ae510f598

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.1.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.0 --no-commit && forge install foundry-rs/forge-std@v1.7.0 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test -vvv

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network Sepolia,$(ARGS)),--network Sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployUpperControl.s.sol:DeployUpperControl $(NETWORK_ARGS)
	
deploy-game:
	@forge script script/DeployGame.s.sol:DeployGame $(NETWORK_ARGS)