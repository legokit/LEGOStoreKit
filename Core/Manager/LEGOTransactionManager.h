//
//  LEGOTransactionManager.h
//  LEGOStoreKit
//
//  Created by errnull on 2019/3/19.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import "LEGOStoreManager.h"

@interface LEGOTransactionManager : NSObject<LEGOStoreReceiptVerifier, LEGOStoreTransactionPersistor>

+ (instancetype)shareInstance;

@end
