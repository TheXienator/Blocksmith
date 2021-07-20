import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction allows an admin to update the metadata for a creator
transaction(creatorID: UInt32, metadata: {String: String}) {

    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {
        // Update the metadata using the admin reference
        self.adminRef.updateCreatorMetadata(creatorID: creatorID, metadata: metadata)
    }
}
