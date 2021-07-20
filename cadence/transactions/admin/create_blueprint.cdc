import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction creates a new blueprint struct for a creator 
// in the Blocksmith smart contract

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

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
        self.currBlueprintID = Blocksmith.getCreator(creatorID: creatorID)!.nextBlueprintID;
    }

    execute {
        // Create a blueprint with the specified metadata
        self.adminRef.createBlueprint(creatorID: creatorID, metadata: metadata, creationLimit: creationLimit)
    }
}