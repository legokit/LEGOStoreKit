//
//  LEGOStoreManager.h
//  LEGOStoreKit_Example
//
//  Created by 杨庆人 on 2019/6/28.
//  Copyright © 2019年 564008993@qq.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol LEGOAppPurchaseStateDelegate <NSObject>

/**
 *  在线请求可购买商品成功
 *
 *  @param products 商品数组
 */
- (void)legoGotProducts:(NSMutableArray *)products;

/**
 *  在线请求可购买商品失败
 *
 *  @param error 失败原因
 */
- (void)legoGotProductsFailure:(NSError *)error;

/**
 *  购买成功
 *
 *  @param transaction 购买成功的商品
 */
- (void)legoBuyProductSuccessed:(SKPaymentTransaction *)transaction;

/**
 *  购买失败
 *
 *  @param productID 商品ID
 */
- (void)legoBuyProductFailure:(NSString *)productID error:(NSError *)error;

/**
 *  恢复了已购买的商品
 *
 *  @param transactions 事务列表
 */
- (void)legoRestoreTransactionsSuccessed:(NSArray <SKPaymentTransaction *> *)transactions;

/**
 *  恢复了购买失败
 *  @param error error.debugDescription
 */
- (void)legoRestoreTransactionsFailure:(NSError *)error;

@end

@interface LEGOStoreManager : NSObject

/**
 *  购买完后是否在iOS端向服务器验证一次，默认为NO
 */
@property (nonatomic, assign) BOOL isCheckByiTunesStore;

@property (nonatomic, weak) id <LEGOAppPurchaseStateDelegate> delegate;

+ (instancetype)defaultStore;

/**
 *  询问苹果的服务器能够销售哪些商品，并存于内存当中
 *
 *  @param products 商品ID的数组
 */
- (void)requestProductsWithProductArray:(NSArray <NSString *> *)products;

/**
 *  用户购买商品
 *
 *  @param productID 商品ID
 */
- (void)buyProduct:(NSString *)productID;

/**
 *  恢复用户商品
 */
- (void)restorePurchase;


@end

