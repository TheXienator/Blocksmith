import Blocksmith from 0xBlocksmith

// This transaction creates a new blueprint and set struct for a creator 
// in the Blocksmith smart contract. It will automatically add the new blueprint
// to the new set and immediately lock the set. This is for creators who
// mostly want to create unique drops and do not care about grouping
// their drops into sets.

// Parameters:
//
// creatorID: The creator ID that this blueprint belongs to
// metadata: A dictionary of all the blueprint metadata associated
// creationLimit: Optional unsigned integer that specifies a global creation limit 
//      for this blueprint that holds across ALL sets. Defaults to UInt32.max if not set

transaction(creatorID: UInt32, metadata: {String: String}, creationLimit: UInt32?, setName: String) {
  // Local variable for the Blocksmith Admin object
  let adminRef: &Blocksmith.Admin

  prepare(acct: AuthAccount) {
    // borrow a reference to the admin resource
    self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
      ?? panic("No admin resource in storage")
  }

  execute {
    let nextBlueprintID = Blocksmith.getCreator(creatorID: creatorID)!.nextBlueprintID
    let nextSetID = Blocksmith.getCreator(creatorID: creatorID)!.nextSetID
    // Create a set with the specified name
    self.adminRef.createSet(creatorID: creatorID, name: setName)
    self.adminRef.createBlueprint(creatorID: creatorID, metadata: metadata, creationLimit: creationLimit)

    // borrow a reference to the set and add the new blueprint
    let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: nextSetID)
    setRef.addBlueprint(blueprintID: nextBlueprintID)
    setRef.lock()
  }
}