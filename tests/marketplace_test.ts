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
  name: "Test complete purchase flow with escrow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Create listing
    let block = chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("A test item description"),
          types.uint(1000000),
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    // Purchase and put payment in escrow
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'purchase-item',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    purchaseBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Confirm delivery and release funds
    let confirmBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'confirm-delivery',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    confirmBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify purchase status
    let purchase = chain.callReadOnlyFn(
      'marketplace',
      'get-purchase',
      [types.uint(1)],
      wallet2.address
    );
    
    let purchaseData = purchase.result.expectSome().expectTuple();
    assertEquals(purchaseData['status'], 'completed');
  },
});

Clarinet.test({
  name: "Test dispute resolution flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!; // seller
    const wallet2 = accounts.get('wallet_2')!; // buyer
    const deployer = accounts.get('deployer')!; // contract owner
    
    // Create and purchase item
    chain.mineBlock([
      Tx.contractCall('marketplace', 'create-listing',
        [
          types.ascii("Test Item"),
          types.utf8("A test item description"),
          types.uint(1000000),
          types.ascii("Electronics")
        ],
        wallet1.address
      )
    ]);
    
    chain.mineBlock([
      Tx.contractCall('marketplace', 'purchase-item',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    // Open dispute
    let disputeBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'open-dispute',
        [
          types.uint(1),
          types.utf8("Item not as described")
        ],
        wallet2.address
      )
    ]);
    
    disputeBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Resolve dispute (refund buyer)
    let resolveBlock = chain.mineBlock([
      Tx.contractCall('marketplace', 'resolve-dispute',
        [
          types.uint(1),
          types.bool(true)
        ],
        deployer.address
      )
    ]);
    
    resolveBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify dispute status
    let purchase = chain.callReadOnlyFn(
      'marketplace',
      'get-purchase',
      [types.uint(1)],
      wallet2.address
    );
    
    let purchaseData = purchase.result.expectSome().expectTuple();
    assertEquals(purchaseData['status'], 'refunded');
  },
});
