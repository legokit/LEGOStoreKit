//
//  LEGOPurchasStatePostParam.m
//  LEGOStoreKit
//
//  Created by errnull on 2019/3/22.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import "LEGOPurchasStatePostParam.h"
#import <StoreKit/StoreKit.h>
#import "LEGOStoreManager.h"

@implementation LEGOPurchasStatePostParam

- (instancetype)init {
    if (self = [super init]) {
        self.state = @"unknow";
        self.price = @"unknow";
        self.result = @"unknow";
        self.sandbox = @"unknow";
        self.account = @"unknow";
        self.productID = @"unknow";
        self.bundleID = [YYUtility appBundleId];
    }
    return self;
}

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction {
    if (self = [super init]) {
        NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
        NSString *receipt = [receiptData base64EncodedStringWithOptions:0];
        
        self.price = [LEGOStoreManager localizedPriceOfProduct:[[LEGOStoreManager defaultStore] productForIdentifier:transaction.payment.productIdentifier]];
        self.result = receipt;
        self.bundleID = [YYUtility appBundleId];
        self.account = transaction.transactionIdentifier;
        self.productID = transaction.payment.productIdentifier;
    }
    return self;
}

+ (NSDictionary *)mj_replacedKeyFromPropertyName{
    return @{
             @"_id" : @"id"
             };
}

@end
