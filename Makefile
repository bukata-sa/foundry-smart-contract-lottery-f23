ifneq (,$(wildcard ./.env))
    include .env
    export
endif

.PHONY: all help install deploy test build

all:; help

help:
	@echo "Usage: make <CMD> [ARGS]"

install:; forge install smartcontractkit/chainlink-brownie-contracts --no-commit

deploy-anvil:
	@forge script script/RaffleDeploy.s.sol:RaffleDeployAnvil --rpc-url http://localhost:8545 --private-key $(ANVIL_PRIVATE_KEY) --broadcast

deploy-sepolia:
	@forge script script/RaffleDeploy.s.sol:RaffleDeploySepolia --rpc-url $(SEPOLIA_RPC) --account sepolia_wallet --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
