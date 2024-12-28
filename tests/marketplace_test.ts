import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that users can create listings",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("A test item description"),
          types.uint(1000000), // 1 STX
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify listing details
    let listing = chain.callReadOnlyFn(
      'marketplace',
      'get-listing',
      [types.uint(1)],
      wallet1.address
    );
    
    listing.result.expectSome().expectTuple();
  },
});

Clarinet.test({
  name: "Ensure that users can purchase items",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // First create a listing
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("A test item description"),
          types.uint(1000000), // 1 STX
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    // Then try to purchase it
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'purchase-item',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    purchaseBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify purchase details
    let purchase = chain.callReadOnlyFn(
      'marketplace',
      'get-purchase',
      [types.uint(1)],
      wallet2.address
    );
    
    purchase.result.expectSome().expectTuple();
  },
});

Clarinet.test({
  name: "Test seller rating system",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'rate-seller',
        [
          types.principal(wallet1.address),
          types.uint(5)
        ],
        wallet2.address
      )
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify seller profile
    let profile = chain.callReadOnlyFn(
      'marketplace',
      'get-seller-profile',
      [types.principal(wallet1.address)],
      wallet2.address
    );
    
    profile.result.expectSome().expectTuple();
  },
});