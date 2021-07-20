import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is what an admin would use to mint a single new creation
// and deposit it in a user's collection

// Parameters:
//
// creatorID: the ID of a creator that we want to mint from
// setID: the ID of a set for that creator containing the blueprint
// blueprintID: the ID of a blueprint from which a new creation is minted
// recipientAddr: the Flow address of the account receiving the newly minted creation

transaction(creatorID: UInt32, setID: UInt32, blueprintID: UInt32, recipientAddr: Address) {
    // local variable for the admin reference
    let adminRef: &Blocksmith.Admin

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {
        // Borrow a reference to the specified set
        let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: setID)

        // Mint a new NFT
        let creation <- setRef.mintCreation(blueprintID: blueprintID)

        // get the public account object for the recipient
        let recipient = getAccount(recipientAddr)

        // get the Collection reference for the receiver
        let receiverRef = recipient.getCapability(Blocksmith.CollectionPublicPath).borrow<&{Blocksmith.CreationCollectionPublic}>()
            ?? panic("Cannot borrow a reference to the recipient's creation collection")

        // deposit the NFT in the receivers collection
        receiverRef.deposit(token: <-creation)
    }
}