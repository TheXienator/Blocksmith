import Blocksmith from "../../contracts/Blocksmith.cdc"

// Checks if you have super admin just for testing
transaction() {

 // Local variable for the Blocksmith Admin object
  let superAdminRef: &Blocksmith.SuperAdmin

  prepare(acct: AuthAccount) {
    // borrow a reference to the admin resource
    self.superAdminRef = acct.borrow<&Blocksmith.SuperAdmin>(from: Blocksmith.SuperAdminStoragePath)
      ?? panic("No super admin resource in storage")
  }

  execute {
    destroy self.superAdminRef.createNewSuperAdmin()
  }
}