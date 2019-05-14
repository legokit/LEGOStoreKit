//
//  LEGOPurchasStatePostParam.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/3/22.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SKPaymentTransaction;
@interface LEGOPurchasStatePostParam : NSObject

@property (nonatomic, copy) NSString *_id;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *productID;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *result;
@property (nonatomic, copy) NSString *price;
@property (nonatomic, assign) BOOL sandbox;

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction;

@end
