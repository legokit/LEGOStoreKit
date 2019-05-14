//
//  LEGOStoreManager.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "LEGOStoreProtocol.h"
#import "NSNotification+LEGOStore.h"

extern NSString *const LEGOStoreErrorDomain;
extern NSInteger const LEGOStoreErrorCodeDownloadCanceled;
extern NSInteger const LEGOStoreErrorCodeUnknownProductIdentifier;
extern NSInteger const LEGOStoreErrorCodeUnableToCompleteVerification;


@interface LEGOStoreManager : NSObject<SKPaymentTransactionObserver>

+ (LEGOStoreManager *)defaultStore;

/**
 外部内容下载
 注：单利内部为weak持有，建议注册一个单利的contentDownloader
 @discussion Hosted content from Apple’s server (SKDownload) 自动下载，无需设置contentDownloader。
 */

- (void)registerContentDownloader:(id<LEGOStoreContentDownloader>)contentDownloader;

/**
 票据校验
 注：内部为weak持有，建议注册一个单利的receiptVerifier
 */
- (void)registerReceiptVerifier:(id<LEGOStoreReceiptVerifier>)receiptVerifier;

/**
 缓存订单
 注：内部为weak持有，建议注册一个单利的transactionPersistor
 The transaction persistor. It is recommended to provide your own obfuscator if piracy is a concern. The store will use weak obfuscation via `NSKeyedArchiver` by default.
 @see LEGOStoreKeychainPersistence
 @see LEGOStoreUserDefaultsPersistence
 */
- (void)registerTransactionPersistor:(id<LEGOStoreTransactionPersistor>)transactionPersistor;

+ (BOOL)canMakePayments;

- (void)addPayment:(NSString*)productIdentifier;

- (void)addPayment:(NSString*)productIdentifier
           success:(void (^)(SKPaymentTransaction *transaction))successBlock
           failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock;


/**
 @param userIdentifier
 
 An opaque identifier for the user’s account on your system.
 Use this property to help the store detect irregular activity. For example, in a game, it would be unusual for dozens of different iTunes Store accounts to make purchases on behalf of the same in-game character.
 The recommended implementation is to use a one-way hash of the user’s account name to calculate the value for this property.
 */
- (void)addPayment:(NSString*)productIdentifier
              user:(NSString*)userIdentifier
           success:(void (^)(SKPaymentTransaction *transaction))successBlock
           failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock;


/**
 请求在线商品，并存储于内存中

 @param identifiers 产品id
 */
- (void)requestProducts:(NSSet*)identifiers;

/**
 请求在线商品，并存储于内存中

 @param identifiers 产品id
 */
- (void)requestProducts:(NSSet*)identifiers
                success:(void (^)(NSArray *products, NSArray *invalidProductIdentifiers))successBlock
                failure:(void (^)(NSError *error))failureBlock;

/**
 获取单个产品，若内存中已存在，直接返回；若没有则网络获取
 
 @param identifier 产品id
 */
- (void)fetchProduct:(NSString *)identifier
             success:(void (^)(SKProduct *product))success
             failure:(void (^)(NSError *error))failure;


/**
 恢复购买
 */
- (void)restoreTransactions;

- (void)restoreTransactionsOnSuccess:(void (^)(NSArray *transactions))successBlock
                             failure:(void (^)(NSError *error))failureBlock;

- (void)restoreTransactionsOfUser:(NSString*)userIdentifier
                        onSuccess:(void (^)(NSArray *transactions))successBlock
                          failure:(void (^)(NSError *error))failureBlock;

- (void)restoreTransactionsWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                                       Success:(void (^)(NSArray *transactions))successBlock
                                       failure:(void (^)(NSError *error))failureBlock;

#pragma mark Receipt

+ (NSURL*)receiptURL;

- (void)refreshReceipt;

- (void)refreshReceiptOnSuccess:(void (^)(void))successBlock
                        failure:(void (^)(NSError *error))failureBlock;


/**
 获取base64的票据，主要用于服务器的票据校验
 */
- (void)base64Receipt:(void(^)(NSString *base64Data))success
              failure:(void(^)(NSError *error))failure;

#pragma mark Product management

- (SKProduct*)productForIdentifier:(NSString*)productIdentifier;

+ (NSString*)localizedPriceOfProduct:(SKProduct*)product;

#pragma mark Notifications

/** Adds an observer to the store.
 Unlike `SKPaymentQueue`, it is not necessary to set an observer.
 @param observer The observer to add.
 */
- (void)addStoreObserver:(id<LEGOStoreObserver>)observer;

/** Removes an observer from the store.
 @param observer The observer to remove.
 */
- (void)removeStoreObserver:(id<LEGOStoreObserver>)observer;

@end



