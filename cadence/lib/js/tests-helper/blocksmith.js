import * as ft from "flow-js-testing";
import * as t from "@onflow/types";
import * as c from "./common";

/*
 * Deploys NonFungibleToken and Blocksmith contracts to SuperAdmin.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const deployBlocksmith = async () => {
	const SuperAdmin = await c.getSuperAdminAddress();
	await ft.mintFlow(SuperAdmin, "10000.0");

	await ft.deployContractByName({ to: SuperAdmin, name: "NonFungibleToken" });

	const addressMap = { NonFungibleToken: SuperAdmin };
	return ft.deployContractByName({ to: SuperAdmin, name: "Blocksmith", addressMap });
};

// Can only be ran after deployBlocksmith
const getAddressMap = async () => {
  const NonFungibleToken = await ft.getContractAddress("NonFungibleToken");
  const Blocksmith = await ft.getContractAddress("Blocksmith");
  return { Blocksmith, NonFungibleToken };
}

export const runScript = async ({name, args}) => {
  const script = await ft.getScriptCode({
    addressMap: getAddressMap,
    name,
  });

  try {
    return ft.executeScript({ code: script, args });
  } catch (e) {
    console.log(e);
  }
};

export const sendTransaction = async ({name, args, signers}) => {
  const transaction = await ft.getTransactionCode({
    addressMap: getAddressMap,
    name,
  });

  try {
    return ft.sendTransaction({ code: transaction, args, signers });
  } catch (e) {
    console.log(e);
  }
};

export const fundAndSetupAccounts = async (users) => {
  for (let user of users) {
    await c.fundUser(user);
    await setupAccount(user);
  }
}

/**
 * SCRIPTS
 */

export const getAdminAccess = async (address) => {
  const name = "creators/get_admin_access";
  const args = [[address, t.Address]];

  return runScript({ name, args });
};

export const getCreatorData = async (creatorID) => {
  const name = "creators/get_creator_data";
  const args = [[creatorID, t.UInt32]];

  return runScript({ name, args }); 
};

export const getSetData = async (creatorID, setID) => {
  const name = "sets/get_set_data";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
  ];

  return runScript({ name, args }); 
};

export const getBlueprint = async (creatorID, blueprintID) => {
  const name = "blueprints/get_blueprint";
  const args = [
    [creatorID, t.UInt32],
    [blueprintID, t.UInt32],
  ];

  return runScript({ name, args }); 
};

export const getBlueprints = async (creatorID) => {
  const name = "blueprints/get_blueprints";
  const args = [
    [creatorID, t.UInt32],
  ];

  return runScript({ name, args }); 
};

export const getBlueprintMetadata = async (creatorID, blueprintID) => {
  const name = "blueprints/get_blueprint_metadata";
  const args = [
    [creatorID, t.UInt32],
    [blueprintID, t.UInt32],
  ];

  return runScript({ name, args }); 
};

export const getCreationIds = async (address) => {
  const name = "creations/get_owned_creation_ids";
  const args = [
    [address, t.Address],
  ];

  return runScript({ name, args }); 
};

export const getCreationData = async (address, globalID) => {
  const name = "creations/get_creation_data";
  const args = [
    [address, t.Address],
    [globalID, t.UInt64],
  ];

  return runScript({ name, args }); 
};

/**
 * TRANSACTIONS
 */

// SUPER ADMIN TRANSACTIONS

export const checkSuperAdminResource = async (address) => {
  const name = "super_admin/super_admin_check";
  const args = [];
  const signers = [address]

  return sendTransaction({ name, args, signers });
};

export const grantAdminAccess = async (superAdmin, address, creatorID) => {
  const name = "super_admin/add_creator_access";
  const args = [
    [address, t.Address],
    [creatorID, t.UInt32],
  ];
  const signers = [superAdmin]

  return sendTransaction({ name, args, signers });
};

export const createCreator = async (superAdmin, address) => {
  const name = "super_admin/create_creator";
  const args = [
    [address, t.Address],
  ];
  const signers = [superAdmin]

  return sendTransaction({ name, args, signers });
};

// ADMIN TRANSACTIONS 

export const updateCreatorMetadata = async (admin, creatorID, metadata) => {
  const convertedMetadata = [];
  for (const key in metadata) {
    const item = {key: key, value: metadata[key]};
    convertedMetadata.push(item);
  }
  
  const name = "admin/add_metadata_to_creator";
  const args = [
    [creatorID, t.UInt32],
    [convertedMetadata, t.Dictionary({key: t.String, value: t.String})],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const createBlueprint = async (admin, creatorID, metadata, creationLimit) => {
  const convertedMetadata = [];
  for (const key in metadata) {
    const item = {key: key, value: metadata[key]};
    convertedMetadata.push(item);
  }

  const name = "admin/create_blueprint";
  const args = [
    [creatorID, t.UInt32],
    [convertedMetadata, t.Dictionary({key: t.String, value: t.String})],
    [creationLimit, t.Optional(t.UInt32)],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const createSet = async (admin, creatorID, setName) => {
  const name = "admin/create_set";
  const args = [
    [creatorID, t.UInt32],
    [setName, t.String],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const createBulkBlueprintsAndSets = async (
  admin, creatorID, creationMetadatas, creationLimit, setNames
) => {
  for (let creationMetadata of creationMetadatas) {
    await createBlueprint(admin, creatorID, creationMetadata, creationLimit);
  }
  for (let setName of setNames) {
    await createSet(admin, creatorID, setName);
  }
}

export const addBlueprintsToSet = async (admin, creatorID, setID, blueprintIDs) => {
  const name = "admin/add_blueprints_to_set";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
    [blueprintIDs, t.Array(t.UInt32)],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const lockSet = async (admin, creatorID, setID) => {
  const name = "admin/lock_set";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const mintCreation = async (admin, creatorID, setID, blueprintID, recipient) => {
  const name = "admin/mint_creation";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
    [blueprintID, t.UInt32],
    [recipient, t.Address],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const mintCreations = async (admin, creatorID, setID, blueprintIDs, recipient) => {
  const name = "admin/batch_mint_creations";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
    [blueprintIDs, t.Array(t.UInt32)],
    [recipient, t.Address],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const retireBlueprintFromSet = async (admin, creatorID, setID, blueprintID) => {
  const name = "admin/retire_blueprint_from_set";
  const args = [
    [creatorID, t.UInt32],
    [setID, t.UInt32],
    [blueprintID, t.UInt32],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const createBlueprintSet = async (admin, creatorID, metadata, creationLimit, setName) => {
  const convertedMetadata = [];
  for (const key in metadata) {
    const item = {key: key, value: metadata[key]};
    convertedMetadata.push(item);
  }

  const name = "admin/create_blueprint_set";
  const args = [
    [creatorID, t.UInt32],
    [convertedMetadata, t.Dictionary({key: t.String, value: t.String})],
    [creationLimit, t.Optional(t.UInt32)],
    [setName, t.String],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const createBlueprintSetAndMint = async (admin, creatorID, recipient) => {
  const name = "admin/create_blueprint_set_and_mint";
  const args = [
    [creatorID, t.UInt32],
    [recipient, t.Address],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

export const incrementSeries = async (admin, creatorID) => {
  const name = "admin/increment_series";
  const args = [
    [creatorID, t.UInt32],
  ];
  const signers = [admin]

  return sendTransaction({ name, args, signers });
}

// ALL USER TRANSACTIONS 

export const setupAccount = async (user) => {
  const name = "user/setup_account";
  const args = [];
  const signers = [user]

  return sendTransaction({ name, args, signers });
};

export const transferCreation = async (user, transferAddress, withdrawID) => {
  const name = "user/transfer_creation";
  const args = [
    [transferAddress, t.Address],
    [withdrawID, t.UInt64],
  ];
  const signers = [user]

  return sendTransaction({ name, args, signers });
};
