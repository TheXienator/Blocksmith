# Nfty
This is all our cadence code and flow integration

## Getting started

### Emulator Setup

Run `flow emulator` and keep it running in a terminal tab while testing.

By default all flow commands link to the emulator unless you override to use the testnet/mainnet. 

### Testnet Setup

**Account Creation**

1. Download the Flow command-line interface (https://docs.onflow.org/flow-cli/install/)

2. Run `flow keys generate` to generate keys for the next two steps:

3. Create a testnet account through Faucet: https://testnet-faucet-v2.onflow.org/

4. Create a file titled `flow.testnet.json` with the structure below -- This file name is ignored by git
```
{
  "accounts": {
    "testnet-account": {
      "address": "#{FLOW_ADDRESS}",
      "keys": "#{FLOW_PRIVATE_KEY}"
    }
  }
}
```

5. Verify account creation by running `flow accounts get #{FLOW_ADDRESS} --network testnet`

**Deploying Contracts**

There are two ways to deploy through Flow-CLI

1. Populate flow.json with all the contracts and run the command `flow project deploy`

2. Add contracts one-by-one on demand by running `flow accounts add-contract HelloWorld ./contracts/HelloWorld.cdc`

You can delete contracts at any time by running `flow accounts remove-contract HelloWorld`
