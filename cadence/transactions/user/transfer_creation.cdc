import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction transfers a creation to a recipient

// This transaction is how a blocksmith user would transfer a creation
// from their account to another account
// The recipient must have a Blocksmith Collection object stored
// and a public BlocksmithCollectionPublic capability stored at
// Blocksmith's collection path

// Parameters:
//
// recipient: The Flow address of the account to receive the creation.
// withdrawID: The id of the creation to be transferred

transaction(recipient: Address, withdrawID: UInt64) {

    // local variable for storing the transferred token
    let transferToken: @NonFungibleToken.NFT
    
    prepare(acct: AuthAccount) {

        // borrow a reference to the owner's collection
        let collectionRef = acct.borrow<&Blocksmith.Collection>(from: Blocksmith.CollectionStoragePath)
            ?? panic("Could not borrow a reference to the stored Creation collection")
        
        // withdraw the NFT
        self.transferToken <- collectionRef.withdraw(withdrawID: withdrawID)
    }

    execute {
        
        // get the recipient's public account object
        let recipient = getAccount(recipient)

        // get the Collection reference for the receiver
        let receiverRef = recipient.getCapability(Blocksmith.CollectionPublicPath).borrow<&{Blocksmith.CreationCollectionPublic}>()!

        // deposit the NFT in the receivers collection
        receiverRef.deposit(token: <-self.transferToken)
    }
}