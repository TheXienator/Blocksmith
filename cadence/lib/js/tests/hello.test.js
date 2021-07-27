import path from "path";
import * as ft from "flow-js-testing";
import * as t from "@onflow/types";

const basePath = path.resolve(__dirname, "../../../");

// Instantiate emulator and path to Cadence files
beforeEach(async () => {
  const port = 8080;
  ft.init(basePath, port);
  return ft.emulator.start(port, false);
});

// Stop emulator, so it could be restarted
afterEach(async () => {
  return ft.emulator.stop();
});
  
describe("Accounts", () => {
  beforeEach(async () => {
    const Alice = await ft.getAccountAddress("Alice");
    const amount = "4200.0";

    try {
      const mintResult = await ft.mintFlow(Alice, amount);
    } catch (e) {
      console.log(e);
    }

    try {
      const result = await ft.getFlowBalance(Alice);
      console.log({ result });
    } catch (e) {
      console.log(e);
    }
  });

  xtest("Create Accounts", async () => {
    const Alice = await ft.getAccountAddress("Alice");

    console.log("Account were created with following addresses:\n", {
      Alice,
    });
  });

  xtest("Mint Flow", async() => {
    const Alice = await ft.getAccountAddress("Alice");
    const amount = "4200.0";

    try {
      const mintResult = await ft.mintFlow(Alice, amount);
      console.log({ mintResult });
    } catch (e) {
      console.log(e);
    }

    try {
      const result = await ft.getFlowBalance(Alice);
      console.log({ result });
    } catch (e) {
      console.log(e);
    }
  })

  xtest("Deploy Contract", async () => {
    const to = await ft.getAccountAddress("Alice");
    let name = "NonFungibleToken";
    try {
      const deploymentResult = await ft.deployContractByName({ to, name });
      console.log({ deploymentResult });
    } catch (e) {
      console.log(e);
    }


    name = "Blocksmith";
    const NonFungibleToken = await ft.getContractAddress("NonFungibleToken");
    const addressMap = { NonFungibleToken }
  
    try {
      const deploymentResult = await ft.deployContractByName({ to, name, addressMap });
      console.log({ deploymentResult });
    } catch (e) {
      console.log(e);
    }
  });

  xtest("Fetch Contract", async () => {
    const contract = await ft.getContractAddress("NonFungibleToken");
    console.log({ contract });
  });

  xtest("Get Transaction Code", async () => {
    const Blocksmith = await ft.getContractAddress("Blocksmith");
    const NonFungibleToken = await ft.getContractAddress("NonFungibleToken");
    const addressMap = { Blocksmith, NonFungibleToken };

    const txTemplate = await ft.getTransactionCode({
      name: "user/setup_account",
      addressMap,
    });
    console.log({ txTemplate });
  })
  
  xtest("Run Script", async () => {
    const Blocksmith = await ft.getContractAddress("Blocksmith");
    const NonFungibleToken = await ft.getContractAddress("NonFungibleToken");
    const addressMap = { Blocksmith, NonFungibleToken };

    const script = await ft.getScriptCode({
      addressMap,
      name: "creators/get_creator_data",
    });

    const args = [
      [1, t.UInt32],
    ];

    try {
      const result = await ft.executeScript({ code: script, args });
      console.log({ result });
    } catch (e) {
      console.log(e);
    }
  })

  xtest("Send Transaction", async () => {
    const Alice = await ft.getAccountAddress("Alice");

    // Read or create transaction code
    const code = `
      transaction(first: Int, second: Int, third: UFix64){
          prepare(alice: AuthAccount){
              // Log passed arguments
              log(first);
              log(second);
              
              log(alice.address);
          }
      }
    `;

    // Create list of arguments
    // You can group items with the same time under single array
    // Last item in the list should always be the type of passed values
    const args = [
      [13, t.Int],
      [38, t.Int],
      ["42.12", t.UFix64],
    ];

    // Specify order of signers
    const signers = [Alice];

    try {
      const txResult = await ft.sendTransaction({ code, args, signers });
      console.log({ txResult });
    } catch (e) {
      console.log(e);
    }
  })
});