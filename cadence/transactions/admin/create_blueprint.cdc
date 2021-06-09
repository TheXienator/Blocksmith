import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction creates a new blueprint struct 
// and stores it in the creator's Blocksmith smart contract
// We currently stringify the metadata and insert it into the 
// transaction string, but want to use transaction arguments soon

// Parameters:
//
// creatorID: The creator ID that this blueprint belongs to
// metadata: A dictionary of all the blueprint metadata associated
// creationLimit: Optional unsigned integer that specifies a global creation limit 
//      for this blueprint that holds across ALL sets. Defaults to UInt32.max if not set

transaction(creatorID: UInt32, metadata: {String: String}, creationLimit: UInt32?) {

    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin
    let currBlueprintID: UInt32

    prepare(acct: AuthAccount) {

        // borrow a reference to the admin resource
        self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
        self.currBlueprintID = Blocksmith.getCreator(creatorID: creatorID)!.nextBlueprintID;
    }

    execute {

        // Create a blueprint with the specified metadata
        self.adminRef.createBlueprint(creatorID: creatorID, metadata: metadata, creationLimit: creationLimit)
    }

    post {
        
        Blocksmith.getBlueprintMetaData(creatorID: creatorID, blueprintID: self.currBlueprintID) != nil:
            "blueprintID doesnt exist"
    }
}