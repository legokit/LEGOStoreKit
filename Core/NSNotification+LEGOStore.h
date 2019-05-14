//
//  NSNotification+LEGOStore.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

extern NSString *const LEGOStoreNotificationInvalidProductIdentifiers;
extern NSString *const LEGOStoreNotificationDownloadProgress;
extern NSString *const LEGOStoreNotificationProductIdentifier;
extern NSString *const LEGOStoreNotificationProducts;
extern NSString *const LEGOStoreNotificationStoreDownload;
extern NSString *const LEGOStoreNotificationStoreError;
extern NSString *const LEGOStoreNotificationStoreReceipt;
extern NSString *const LEGOStoreNotificationTransaction;
extern NSString *const LEGOStoreNotificationTransactions;

/**
 Category on NSNotification to recover store data from userInfo without requiring to know the keys.
 */
@interface NSNotification (LEGOStore)

@property (nonatomic, readonly) float lego_downloadProgress;

/** Array of product identifiers that were not recognized by the App Store. Used in @c storeProductsRequestFinished:.
 */
@property (nonatomic, readonly) NSArray *lego_invalidProductIdentifiers;

/** Used in @c storeDownload*:, @c storePaymentTransactionFinished: and @c storePaymentTransactionFailed:.
 */
@property (nonatomic, readonly) NSString *lego_productIdentifier;

/** Array of SKProducts, one product for each valid product identifier provided in the corresponding request. Used in @c storeProductsRequestFinished:.
 */
@property (nonatomic, readonly) NSArray *lego_products;

/** Used in @c storeDownload*:.
 */
@property (nonatomic, readonly) SKDownload *lego_storeDownload;

/** Used in @c storeDownloadFailed:, @c storePaymentTransactionFailed:, @c storeProductsRequestFailed:, @c storeRefreshReceiptFailed: and @c storeRestoreTransactionsFailed:.
 */
@property (nonatomic, readonly) NSError *lego_storeError;

/** Used in @c storeDownload*:, @c storePaymentTransactionFinished: and in @c storePaymentTransactionFailed:.
 */
@property (nonatomic, readonly) SKPaymentTransaction *lego_transaction;

/** Used in @c storeRestoreTransactionsFinished:.
 */
@property (nonatomic, readonly) NSArray *lego_transactions;

@end

