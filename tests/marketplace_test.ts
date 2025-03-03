// [Previous test content...]

Clarinet.test({
  name: "Test listing creation with expiration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("Test description"),
          types.uint(1000000),
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify listing details
    let listing = chain.callReadOnlyFn(
      'marketplace',
      'get-listing',
      [types.uint(1)],
      wallet1.address
    );
    
    let listingData = listing.result.expectSome().expectTuple();
    assertEquals(listingData['active'], true);
    assert(Number(listingData['expires-at']) > Number(listingData['created-at']));
  }
});

// [Additional tests for new functionality...]
