import path from "path";
import * as ft from "flow-js-testing";
import * as bh from "../tests-helper/blocksmith"
import * as t from "@onflow/types";
import * as c from "../tests-helper/common"

const basePath = path.resolve(__dirname, "../../../");

let superAdmin = "";
let admin = "";
let user = "";

// TODO test events
describe("Contract deployment", () => {
  // Instantiate emulator and path to Cadence files
  // Using before all here because no transactions here change state
  beforeAll(async () => {
    const port = 8080;
    ft.init(basePath, port);
    return ft.emulator.start(port, false);
  });

  // Stop emulator, so it could be restarted
  afterAll(async () => {
    return ft.emulator.stop();
  });

	it("can deploy Blocksmith contract", async () => {
		await ft.shallPass(bh.deployBlocksmith());
	});

  describe("sets up the SuperAdmin", () => {
    beforeAll(async () => {
      superAdmin = await c.getSuperAdminAddress();
    })

    it("sets up an empty collection", async () => {
      const result = await bh.getCreationIds(superAdmin);
      expect(result).toEqual([]);
    });

    it("sets up an empty admin access", async () => {
      const result = await bh.getAdminAccess(superAdmin);
      expect(result).toEqual({});
    });

    it("sets up super admin access", async () => {
      await ft.shallResolve(bh.checkSuperAdminResource(superAdmin));
    });
  });

  describe("new users", () => {
    beforeAll(async () => {
      user = await c.getUserAddress();
      await bh.setupAccount(user);
    });

    it("can set up an empty collection", async () => {
      const result = await bh.getCreationIds(user);      
      expect(result).toEqual([]);
    });

    it("can set up an empty Admin access", async () => {
      const result = await bh.getAdminAccess(user);
      expect(result).toEqual({});
    });

    it("does not have super admin access", async () => {
      await ft.shallRevert(bh.checkSuperAdminResource(user));
    });
  });
});

describe("Contract functions", () => {
  const adminCreatorID = 1;
  const otherCreatorID = 2;
  let creatorData;
  let nextBlueprintID;
  let nextSetID;

  const creationMetadatas = [
    { "pokemon": "pikachu", "type": "lightning" },
    { "pokemon": "squirtle", "type": "water" },
    { "pokemon": "charmander", "type": "fire" },
  ];
  const creationLimit = 10;
  const setNames = [
    "Pokemon Yellow",
    "Pokemon Blue",
    "Pokemon Red",
    "Pokemon All",
  ];

  // Using before each here because transactions may change state
  beforeEach(async () => {
    const port = 8080;
    ft.init(basePath, port);
    return ft.emulator.start(port, false);
  });

  beforeEach(async () => {
    await ft.shallPass(bh.deployBlocksmith());
    superAdmin = await c.getSuperAdminAddress();
    admin = await c.getAdminAddress();
    user = await c.getUserAddress();
    await bh.fundAndSetupAccounts([admin, user]);
  });

  // Stop emulator, so it could be restarted
  afterEach(async () => {
    return ft.emulator.stop();
  });

  describe("SuperAdmins funcions", () => {
    const creatorID = 1;

    it("can create creators and grant admin access", async () => {
      // Can't give access to creators that don't exist yet
      await ft.shallRevert(bh.grantAdminAccess(superAdmin, superAdmin, creatorID));

      // Superadmin can create creators + asign default access
      await ft.shallResolve(bh.createCreator(superAdmin, admin));
      const adminResult = await bh.getAdminAccess(admin);
      expect(adminResult[creatorID]).toBe(true);
      let superAdminResult = await bh.getAdminAccess(superAdmin);
      expect(!superAdminResult[creatorID]).toBe(true);
      
      // Can give access for an already created creator
      await ft.shallResolve(bh.grantAdminAccess(superAdmin, superAdmin, creatorID));
      superAdminResult = await bh.getAdminAccess(superAdmin);
      expect(superAdminResult[creatorID]).toBe(true);

      // Testing script that anyone can use to view creator Data
      const expectedData = c.defaultCreator(admin);
      const creatorData = await bh.getCreatorData(creatorID);
      expect(creatorData).toEqual(expectedData);

      // testing that we can create many creators
      await ft.shallResolve(bh.createCreator(superAdmin, admin));
      await ft.shallResolve(bh.createCreator(superAdmin, admin));
      await ft.shallResolve(bh.createCreator(superAdmin, admin));
    });

    it("cannot be called by non superAdmins", async () => {
      // non superAdmins cannot createCreators
      await ft.shallRevert(bh.createCreator(admin, admin));
      await ft.shallRevert(bh.createCreator(user, user));

      await ft.shallResolve(bh.createCreator(superAdmin, admin));

      // non superAdmins cannot self grantAdminAccess to existing Creators
      await ft.shallRevert(bh.grantAdminAccess(admin, admin, creatorID));
      await ft.shallRevert(bh.grantAdminAccess(user, user, creatorID));
    });
  });

  describe("Admin functions", () => {
    beforeEach(async () => {
      await bh.createCreator(superAdmin, admin);
      await bh.createCreator(superAdmin, superAdmin);
      creatorData = await bh.getCreatorData(adminCreatorID);
      nextBlueprintID = creatorData.nextBlueprintID;
      nextSetID = creatorData.nextSetID;
    });

    it("allows admins to change creator metadata for creators they have access to", async () => {
      const creatorMetadata = { "name": "Albert" };
      await ft.shallResolve(bh.updateCreatorMetadata(admin, adminCreatorID, creatorMetadata));

      // creator's data is as expected with the new metadata populated
      creatorData = await bh.getCreatorData(adminCreatorID);
      const expectedAdminData = c.defaultCreator(admin);
      expectedAdminData["creatorMetadata"] = creatorMetadata;
      expect(creatorData).toEqual(expectedAdminData);
      
      // can't change another creator's metadata
      await ft.shallRevert(bh.updateCreatorMetadata(admin, otherCreatorID, creatorMetadata));

      // after giving superAdmin giving new access admin now can
      await bh.grantAdminAccess(superAdmin, admin, otherCreatorID);
      await ft.shallResolve(bh.updateCreatorMetadata(admin, otherCreatorID, creatorMetadata));
      const otherData = await bh.getCreatorData(otherCreatorID);

      // other creator's data is as expected with the new metadata populated
      const expectedOtherData = c.defaultCreator(superAdmin);
      expectedOtherData["creatorID"] = otherCreatorID;
      expectedOtherData["creatorMetadata"] = creatorMetadata;
      expect(otherData).toEqual(expectedOtherData);
    });

    it("allows admins to create blueprints for creators they have access to", async () => {
      const metadata = creationMetadatas[0];
      // cannot read a blueprint that isn't created yet
      await ft.shallRevert(bh.getBlueprint(adminCreatorID, nextBlueprintID));

      // admin can create blueprints
      await ft.shallResolve(bh.createBlueprint(admin, adminCreatorID, metadata, creationLimit));

      // anyone can now read that blueprint is created as expected
      const blueprint =  await ft.shallResolve(bh.getBlueprint(adminCreatorID, nextBlueprintID));
      const expected = c.defaultBlueprint(metadata, creationLimit);
      expect(blueprint).toEqual(expected);

      // test admin can create multiple blueprints
      await ft.shallResolve(bh.createBlueprint(admin, adminCreatorID, creationMetadatas[1], creationLimit));
      await ft.shallResolve(bh.createBlueprint(admin, adminCreatorID, creationMetadatas[2], creationLimit));
      const blueprints =  await ft.shallResolve(bh.getBlueprints(adminCreatorID));
      expect(blueprints).toHaveLength(3);

      // Adding blueprints also updates CreatorData and nextBlueprintID
      const updatedData = await bh.getCreatorData(adminCreatorID);
      expect(updatedData.blueprints[nextBlueprintID]).toEqual(blueprints[0]);
      expect(updatedData.blueprints[nextBlueprintID + 1]).toEqual(blueprints[1]);
      expect(updatedData.blueprints[nextBlueprintID + 2]).toEqual(blueprints[2]);
      expect(updatedData.nextBlueprintID).toEqual(nextBlueprintID + 3);

      // cannot create blueprints for creators you don't have access to
      await ft.shallRevert(bh.createBlueprint(admin, otherCreatorID, metadata, creationLimit));

      // after giving superAdmin giving new access admin now can
      await bh.grantAdminAccess(superAdmin, admin, otherCreatorID);
      await ft.shallResolve(bh.createBlueprint(admin, otherCreatorID, metadata, creationLimit));

      // checks that nextBlueprintID is reset for each creator
      const otherData = await bh.getCreatorData(otherCreatorID);
      expected.creatorID = otherCreatorID;
      expect(otherData.blueprints[nextBlueprintID]).toEqual(expected);
      expect(otherData.nextBlueprintID).toEqual(nextBlueprintID + 1);
    });

    it("allows admins to create sets for creators they have access to", async () => {
      const setName = setNames[0];
      // cannot get data for sets that aren't created yet
      await ft.shallRevert(bh.getSetData(adminCreatorID, nextSetID));

      // admin can create a new set
      await ft.shallResolve(bh.createSet(admin, adminCreatorID, setName));

      // anyone can now get the setData with a script
      const set = await ft.shallResolve(bh.getSetData(adminCreatorID, nextSetID));
      const expected = c.defaultSet(setName);
      expect(set).toEqual(expected);

      // can create multiple sets and increment series
      await ft.shallResolve(bh.createSet(admin, adminCreatorID, setNames[1]));
      await ft.shallResolve(bh.incrementSeries(admin, adminCreatorID));
      await ft.shallResolve(bh.createSet(admin, adminCreatorID, setNames[2]));
      const set2 = await bh.getSetData(adminCreatorID, nextSetID + 1);
      const set3 = await bh.getSetData(adminCreatorID, nextSetID + 2);
      expect(set.series).toEqual(set2.series);
      expect(set3.series).not.toEqual(set2.series);
      
      // sets update the creator variables properly
      const updatedData = await bh.getCreatorData(adminCreatorID);
      expect(updatedData.nextSetID).toEqual(nextSetID + 3);

      // admin cannot create sets for creators they don't have access to
      await ft.shallRevert(bh.createSet(admin, otherCreatorID, setName));

      // after giving superAdmin giving new access admin now can
      await bh.grantAdminAccess(superAdmin, admin, otherCreatorID);
      await ft.shallResolve(bh.createSet(admin, otherCreatorID,setName));

      // checks that nextSetID is reset for each creator
      const otherData = await bh.getCreatorData(otherCreatorID);
      expect(otherData.nextSetID).toEqual(nextSetID + 1);
    });

    it("allows admins to add/retire blueprints to sets and lock sets", async () => {
      await ft.shallResolve(
        bh.createBulkBlueprintsAndSets(admin, adminCreatorID, creationMetadatas, creationLimit, setNames)
      );

      // can add single blueprint to a set
      await ft.shallResolve(
        bh.addBlueprintsToSet(admin, adminCreatorID, nextSetID, [nextBlueprintID])
      );

      // cannot add single blueprint to a set for creators we don't have access to
      await ft.shallRevert(
        bh.addBlueprintsToSet(admin, otherCreatorID, nextSetID, [nextBlueprintID])
      );

      // verify it gets added properly
      let setData = await bh.getSetData(adminCreatorID, nextSetID);
      let expected = c.defaultSetWithBlueprints(setNames[0], [nextBlueprintID]);
      expect(setData).toEqual(expected);

      // verify we cannot add the same blueprint twice
      await ft.shallRevert(
        bh.addBlueprintsToSet(admin, adminCreatorID, nextSetID, [nextBlueprintID])
      );

      // verify we can add a different blueprint
      await ft.shallResolve(
        bh.addBlueprintsToSet(admin, adminCreatorID, nextSetID, [nextBlueprintID + 1])
      );

      // verify we can lock sets
      await ft.shallResolve(bh.lockSet(admin, adminCreatorID, nextSetID));
      // verify we can't lock sets for creators we don't have access to
      await ft.shallRevert(bh.lockSet(admin, otherCreatorID, nextSetID));

      // verify the locked status is updated
      setData = await bh.getSetData(adminCreatorID, nextSetID);
      expect(setData.locked).toBeTruthy();

      // verify we cannot add new blueprints after it is locked
      await ft.shallRevert(
        bh.addBlueprintsToSet(admin, adminCreatorID, nextSetID, [nextBlueprintID + 2])
      );

      // verify we can add the same blueprint to multiple sets and multiple blueprints to a set
      const allBlueprintIDs = [nextBlueprintID, nextBlueprintID + 1, nextBlueprintID + 2];
      await ft.shallResolve(
        bh.addBlueprintsToSet(admin, adminCreatorID, nextSetID + 1, allBlueprintIDs)
      );

      setData = await bh.getSetData(adminCreatorID, nextSetID + 1);
      expected = c.defaultSetWithBlueprints(setNames[1], allBlueprintIDs);
      expected.setID = nextSetID + 1;
      expect(setData).toEqual(expected);
    });

    it("allows composite BlueprintSet and minting methods to work", async () => {
      const pikachuData = creationMetadatas[0];
      const setName = setNames[0];

      // testing the blueprint sets creation transaction
      await ft.shallResolve(
        bh.createBlueprintSet(admin, adminCreatorID, pikachuData, creationLimit, setName)
      );

      // verify set is created successfully and locked
      let set = await ft.shallResolve(bh.getSetData(adminCreatorID, nextSetID));
      let expectedSet = c.defaultSetWithBlueprints(setName, [nextBlueprintID]);
      expectedSet.locked = true;
      expect(set).toEqual(expectedSet);

      // verify blueprint is created successfully
      let blueprint = await ft.shallResolve(bh.getBlueprint(adminCreatorID, nextBlueprintID));
      let expectedBP = c.defaultBlueprint(pikachuData, creationLimit);
      expect(blueprint).toEqual(expectedBP);

      // cannot create blueprint sets for other creators
      await ft.shallRevert(
        bh.createBlueprintSet(admin, otherCreatorID, pikachuData, creationLimit, setName)
      );

      // verify we have no creations by deafult and can read anyones creationIDs
      let adminTokens = await bh.getCreationIds(admin);
      expect(adminTokens).toEqual([]);

      // can mint creations from sets with valid blueprintIDs (globalID 1)
      await ft.shallResolve(
        bh.mintCreation(admin, adminCreatorID, nextSetID, nextBlueprintID, admin)
      );
      adminTokens = await bh.getCreationIds(admin);
      expect(adminTokens).toEqual([1]);
      
      // can mint to any user who has a collection set-up (globalID 2)
      await ft.shallResolve(
        bh.mintCreation(admin, adminCreatorID, nextSetID, nextBlueprintID, user)
      );
      let userTokens = await bh.getCreationIds(user);
      expect(userTokens).toEqual([2]);

      // cannot mint to a user who does not have an collection set-up
      const random = ft.getAccountAddress("Random");
      await ft.shallRevert(
        bh.mintCreation(admin, adminCreatorID, nextSetID, nextBlueprintID, random)
      );

      // verify minting-related creation, creator, blueprint, set variables
      creatorData = await bh.getCreatorData(adminCreatorID);
      blueprint = await bh.getBlueprint(adminCreatorID, nextBlueprintID);
      set = await bh.getSetData(adminCreatorID, nextSetID);
      expect(creatorData.nextBlueprintID).toEqual(nextBlueprintID + 1);
      expect(creatorData.nextSetID).toEqual(nextSetID + 1);
      expect(creatorData.numCreations).toEqual(2);
      expect(creatorData.blueprints[nextBlueprintID]).toEqual(blueprint);
      expectedBP.creationCount = 2;
      expect(blueprint).toEqual(expectedBP);
      expectedSet.numberMintedPerBlueprint[nextBlueprintID] = 2;
      expect(set).toEqual(expectedSet);

      let creationData1 = await ft.shallResolve(bh.getCreationData(admin, 1));
      let expectedCreation1 = {
        creatorID: 1,
        creationID: 1,
        setID: 1,
        blueprintID: 1,
        serialNumber: 1,
      };
      expect(creationData1).toEqual(expectedCreation1);
      let creationData2 = await ft.shallResolve(bh.getCreationData(user, 2));
      let expectedCreation2 = {
        creatorID: 1,
        creationID: 2,
        setID: 1,
        blueprintID: 1,
        serialNumber: 2,
      };
      expect(creationData2).toEqual(expectedCreation2);

      // create another set with different data
      bh.createBlueprintSet(admin, adminCreatorID, creationMetadatas[1], 1, setNames[1])

      // cannot mint creations from sets without the blueprintID
      await ft.shallRevert(
        bh.mintCreation(admin, adminCreatorID, nextSetID, nextBlueprintID + 1, admin)
      );
      await ft.shallRevert(
        bh.mintCreation(admin, adminCreatorID, nextSetID + 1, nextBlueprintID, admin)
      );

      // can mint creations from the second set as well (globalID 3)
      await ft.shallResolve(
        bh.mintCreation(admin, adminCreatorID, nextSetID + 1, nextBlueprintID + 1, admin)
      );
      let creationData3 = await ft.shallResolve(bh.getCreationData(admin, 3));
      let expectedCreation3 = {
        creatorID: 1,
        creationID: 3, // continues onto 3 because this is the same creator
        setID: 2,
        blueprintID: 2,
        serialNumber: 1, // set back to 1 because this is a new set
      };
      expect(creationData3).toEqual(expectedCreation3);

      // cannot mint creations past creationLimit
      await ft.shallRevert(
        bh.mintCreation(admin, adminCreatorID, nextSetID + 1, nextBlueprintID + 1, admin)
      );

      // can all of setup and minting in one (globalID 4)
      await ft.shallResolve(bh.createBlueprintSetAndMint(superAdmin, otherCreatorID, user));
      userTokens = await bh.getCreationIds(user);
      expect(userTokens).toEqual([2, 4]);
      let creationData4 = await ft.shallResolve(bh.getCreationData(user, 4));
      let expectedCreation4 = {
        creatorID: 2,
        creationID: 1, // set back to 1 because this is a new creator
        setID: 1,
        blueprintID: 1,
        serialNumber: 1, // set back to 1 because this is a new set
      };
      expect(creationData4).toEqual(expectedCreation4);
    });
  });

  describe("User functions", () => {
    beforeEach(async () => {
      await bh.createCreator(superAdmin, admin);
      await bh.createCreator(superAdmin, superAdmin);
      await bh.createBlueprintSetAndMint(admin, adminCreatorID, user);
    });

    it("allows users to view and transfer NFTs they have", async () => {
      let userTokens = await ft.shallResolve(bh.getCreationIds(user));
      expect(userTokens).toEqual([1]);

      // user cannot transfer a token they do not have
      await ft.shallRevert(bh.transferCreation(user, admin, 2));

      // user cannot transfer to a user that has no collection
      let random = ft.getAccountAddress("Random");
      await ft.shallRevert(bh.transferCreation(user, random, 1));

      // user can transfer an owned creation to a user with a collection
      await ft.shallResolve(bh.transferCreation(user, admin, 1));
      userTokens = await bh.getCreationIds(user);
      expect(userTokens).toEqual([]);

      // the admin now has this token
      let adminTokens = await bh.getCreationIds(admin);
      expect(adminTokens).toContain(1);
    });
  });
});