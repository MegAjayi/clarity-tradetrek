// [Previous test content remains, adding new tests...]

Clarinet.test({
  name: "Test listing update functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Create listing
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("Original description"),
          types.uint(1000000),
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    // Update listing
    let updateBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'update-listing',
        [
          types.uint(1),
          types.some(types.ascii("Updated Item")),
          types.some(types.utf8("Updated description")),
          types.some(types.uint(2000000))
        ],
        wallet1.address
      )
    ]);
    
    updateBlock.receipts[0].result.expectOk();
    
    // Verify updated listing
    let listing = chain.callReadOnlyFn(
      'marketplace',
      'get-listing',
      [types.uint(1)],
      wallet1.address
    );
    
    let listingData = listing.result.expectSome().expectTuple();
    assertEquals(listingData['title'], "Updated Item");
    assertEquals(listingData['price'], 2000000);
  }
});

// [Additional tests for new functionality...]
