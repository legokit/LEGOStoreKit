//
//  LEGOTransactionManager.m
//  LEGOStoreKit
//
//  Created by errnull on 2019/3/19.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import "LEGOTransactionManager.h"
#import "LEGOPurchasStatePostParam.h"
#import "LEGOSystemInfo.h"

@implementation LEGOTransactionManager

static LEGOTransactionManager *_instance = nil;

+(instancetype) shareInstance {
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init] ;
    }) ;
    
    return _instance ;
}

+(id) allocWithZone:(struct _NSZone *)zone {
    return [LEGOTransactionManager shareInstance] ;
}

-(id) copyWithZone:(struct _NSZone *)zone {
    return [LEGOTransactionManager shareInstance] ;
}

- (void)verifyTransaction:(SKPaymentTransaction *)transaction success:(void (^)(void))successBlock failure:(void (^)(NSError *))failureBlock {
    // TODO：埋点信息
//    [LEGOEvent addEventCountWithEventID:@"LEGOFilmBuySuccess" attributes:@{@"productID":transaction.payment.productIdentifier}];
    LEGOLogInfo(@"此处检验购买凭证");
    if (successBlock) {
        successBlock();
    }
}

- (void)persistTransaction:(SKPaymentTransaction *)transaction {
}

@end
