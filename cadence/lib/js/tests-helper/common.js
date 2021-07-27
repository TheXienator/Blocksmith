import * as ft from "flow-js-testing";

export const getSuperAdminAddress = async () => ft.getAccountAddress("SuperAdmin");

export const getAdminAddress = async () => ft.getAccountAddress("Admin");

export const getUserAddress = async () => ft.getAccountAddress("User");

export const fundUser = async(user, amount="1000.0") => {
  try {
    await ft.mintFlow(user, amount);
  }
  catch (e) {
    console.log(e);
  }
};

export const defaultCreator = (creatorAddress) => {
  return {
    creatorID: 1,
    creatorAddress: creatorAddress,
    creatorMetadata: {},
    currentSeries: 0,
    nextBlueprintID: 1,
    nextSetID: 1,
    numCreations: 0,
    blueprints: {},
  };
};

export const defaultBlueprint = (metadata, creationLimit) => {
  return {
    creatorID: 1,
    blueprintID: 1,
    metadata: metadata,
    creationCount: 0,
    creationLimit: creationLimit,
  }
}

export const defaultSet = (setName) => {
  return {
    creatorID: 1,
    setID: 1,
    name: setName,
    series: 0,
    locked: false,
    blueprintIDs: [],
    retired: {},
    numberMintedPerBlueprint: {},
  }
}

export const defaultSetWithBlueprints = (setName, blueprintIDs) => {
  let retired = {};
  let numberMintedPerBlueprint = {};
  for (let blueprintID of blueprintIDs) {
    retired[blueprintID] = false;
    numberMintedPerBlueprint[blueprintID] = 0;
  }
  return {
    creatorID: 1,
    setID: 1,
    name: setName,
    series: 0,
    locked: false,
    blueprintIDs: blueprintIDs,
    retired: retired,
    numberMintedPerBlueprint: numberMintedPerBlueprint,
  }
}