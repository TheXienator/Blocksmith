import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the CreationData for an NFT in an account's collection.

pub fun main(address: Address, globalCreationID: UInt64): Blocksmith.CreationData {

    // get the public account object for the token owner
    let owner = getAccount(address)

    let collectionBorrow = owner.getCapability(Blocksmith.CollectionPublicPath)
        .borrow<&{Blocksmith.CreationCollectionPublic}>()
        ?? panic("Could not borrow CreationCollectionPublic")

    // borrow a reference to a specific NFT in the collection
    let creation = collectionBorrow.borrowCreation(id: globalCreationID)
        ?? panic("No such creationID in that collection")

    return creation.data
}
