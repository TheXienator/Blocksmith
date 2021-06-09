import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction adds multiple blueprints to a set
		
// Parameters:
//
// creatorID: the ID the creator where the blueprints and the sets are part of
// setID: the ID of the set to which multiple blueprints are added
// blueprintIDs: an array of blueprint IDs being added to the set

transaction(creatorID: UInt32, setID: UInt32, blueprintIDs: [UInt32]) {

    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin

    prepare(acct: AuthAccount) {

        // borrow a reference to the admin resource
        self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {

        // borrow a reference to the set to be added to
        let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: setID)

        // Add the specified blueprint IDs
        setRef.addBlueprints(blueprintIDs: blueprintIDs)
    }
}