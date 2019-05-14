//
//  LEGOReceiptRefreshService.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface LEGOReceiptRefreshService : NSObject

- (void)refreshReceiptOnSuccess:(void(^)(void))successBlock
                        failure:(void(^)(NSError *error))failureBlock;

@end
