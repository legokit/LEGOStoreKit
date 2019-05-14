//
//  LEGOStoreProtocol.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//

#ifndef LEGOStoreProtocol_h
#define LEGOStoreProtocol_h

#import <StoreKit/StoreKit.h>

@protocol LEGOStoreContentDownloader <NSObject>

- (void)downloadContentForTransaction:(SKPaymentTransaction*)transaction
                              success:(void (^)(void))successBlock
                             progress:(void (^)(float progress))progressBlock
                              failure:(void (^)(NSError *error))failureBlock;

@end


@protocol LEGOStoreTransactionPersistor<NSObject>

- (void)persistTransaction:(SKPaymentTransaction*)transaction;

@end

@protocol LEGOStoreReceiptVerifier <NSObject>

/** Verifies the given transaction and calls the given success or failure block accordingly.
 @param transaction The transaction to be verified.
 @param successBlock Called if the transaction passed verification. Must be called in the main queu.
 @param failureBlock Called if the transaction failed verification. If verification could not be completed (e.g., due to connection issues), then error must be of code LEGOStoreErrorCodeUnableToCompleteVerification to prevent LEGOStoreManager to finish the transaction. Must be called in the main queu.
 */
- (void)verifyTransaction:(SKPaymentTransaction*)transaction
                  success:(void (^)(void))successBlock
                  failure:(void (^)(NSError *error))failureBlock;

@end

@protocol LEGOStoreObserver<NSObject>
@optional

/**
 Tells the observer that a download has been canceled.
 @discussion Only for Apple-hosted downloads.
 */
- (void)storeDownloadCanceled:(NSNotification*)notification;

/**
 Tells the observer that a download has failed. Use @c storeError to get the cause.
 */
- (void)storeDownloadFailed:(NSNotification*)notification;

/**
 Tells the observer that a download has finished.
 */
- (void)storeDownloadFinished:(NSNotification*)notification __attribute__((availability(ios,introduced=6.0)));

/**
 Tells the observer that a download has been paused.
 @discussion Only for Apple-hosted downloads.
 */
- (void)storeDownloadPaused:(NSNotification*)notification;

/**
 Tells the observer that a download has been updated. Use downloadProgress to get the progress.
 */
- (void)storeDownloadUpdated:(NSNotification*)notification;

- (void)storePaymentTransactionDeferred:(NSNotification*)notification;

- (void)storePaymentTransactionFailed:(NSNotification*)notification;

- (void)storePaymentTransactionFinished:(NSNotification*)notification;


/**
 Tells the observer that request has changed
 */
- (void)storeProductsRequestFailed:(NSNotification*)notification;

- (void)storeProductsRequestFinished:(NSNotification*)notification;

/**
 Tells the observer that receipt has changed
 */
- (void)storeRefreshReceiptFailed:(NSNotification*)notification;

- (void)storeRefreshReceiptFinished:(NSNotification*)notification;

/**
 Tells the observer that transactions has changed
 */
- (void)storeRestoreTransactionsFailed:(NSNotification*)notification;

- (void)storeRestoreTransactionsFinished:(NSNotification*)notification;

@end



#endif /* LEGOStoreProtocol_h */
