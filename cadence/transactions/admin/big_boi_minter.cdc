import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is for the admin to fully create a blueprint
// set and NFT and send it to the recipient. It uses predetermined
// metadata and info to set everything up.

// Parameters:
//
// creatorID: the id of the creator this set belongs to
// recipientAddress: the name of a new Set to be created

transaction(creatorID: UInt32, recipientAddress: Address) {
    
    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the Admin resource in storage
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("Could not borrow a reference to the Admin resource")
    }

    execute {
        let metadata = {"name": "Squirtle", "type": "water"}
        let setName = "Pokemon Yellow"
        let creationLimit: UInt32? = 10

        let nextBlueprintID = Blocksmith.getCreator(creatorID: creatorID)!.nextBlueprintID
        let nextSetID = Blocksmith.getCreator(creatorID: creatorID)!.nextSetID
        // Create a set with the specified name
        self.adminRef.createSet(creatorID: creatorID, name: setName)
        self.adminRef.createBlueprint(creatorID: creatorID, metadata: metadata, creationLimit: creationLimit)

        // borrow a reference to the set and add the new blueprint
        let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: nextSetID)
        setRef.addBlueprint(blueprintID: nextBlueprintID)
        setRef.lock()

        // Mint a new NFT
        let creation <- setRef.mintCreation(blueprintID: nextBlueprintID)

        // get the public account object for the recipient and the related collection
        let recipient = getAccount(recipientAddress)
        let receiverRef = recipient.getCapability(Blocksmith.CollectionPublicPath).borrow<&{Blocksmith.CreationCollectionPublic}>()
            ?? panic("Cannot borrow a reference to the recipient's creation collection")

        // deposit the NFT in the receivers collection
        receiverRef.deposit(token: <-creation)
    }
}