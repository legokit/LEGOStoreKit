//
//  LEGOStoreProductService.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

typedef void (^LEGOSKProductsRequestFailureBlock)(NSError *error);

typedef void (^LEGOSKProductsRequestSuccessBlock)(NSArray *products, NSArray *invalidIdentifiers);

@interface LEGOStoreProductService : NSObject<SKProductsRequestDelegate>

@property (nonatomic, copy) void(^addProductBlock)(SKProduct *product);

@property (nonatomic, copy) void(^removeProductRequestBlock)(LEGOStoreProductService *service);

- (void)requestProducts:(NSSet*)identifiers
                success:(LEGOSKProductsRequestSuccessBlock)successBlock
                failure:(LEGOSKProductsRequestFailureBlock)failureBlock;

@end
