import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is for the admin to create a new set resource
// and store it in the blocksmith smart contract

// Parameters:
//
// creatorID: the id of the creator this set belongs to
// setName: the name of a new Set to be created

transaction(creatorID: UInt32, setName: String) {
    
    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin
    let currSetID: UInt32

    prepare(acct: AuthAccount) {

        // borrow a reference to the Admin resource in storage
        self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("Could not borrow a reference to the Admin resource")
        self.currSetID = Blocksmith.getCreator(creatorID: creatorID)!.nextSetID;
    }

    execute {
        
        // Create a set with the specified name
        self.adminRef.createSet(creatorID: creatorID, name: setName)
    }

    post {
        
        Blocksmith.getSetName(creatorID: creatorID, setID: self.currSetID) == setName:
          "Could not find the specified set"
    }
}