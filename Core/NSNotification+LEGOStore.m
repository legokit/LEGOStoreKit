//
//  NSNotification+LEGOStore.m
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//


#import "NSNotification+LEGOStore.h"

NSString* const LEGOStoreNotificationInvalidProductIdentifiers = @"invalidProductIdentifiers";
NSString* const LEGOStoreNotificationDownloadProgress = @"downloadProgress";
NSString* const LEGOStoreNotificationProductIdentifier = @"productIdentifier";
NSString* const LEGOStoreNotificationProducts = @"products";
NSString* const LEGOStoreNotificationStoreDownload = @"storeDownload";
NSString* const LEGOStoreNotificationStoreError = @"storeError";
NSString* const LEGOStoreNotificationStoreReceipt = @"storeReceipt";
NSString* const LEGOStoreNotificationTransaction = @"transaction";
NSString* const LEGOStoreNotificationTransactions = @"transactions";

@implementation NSNotification (LEGOStore)

- (float)lego_downloadProgress
{
    return [self.userInfo[LEGOStoreNotificationDownloadProgress] floatValue];
}

- (NSArray*)lego_invalidProductIdentifiers
{
    return (self.userInfo)[LEGOStoreNotificationInvalidProductIdentifiers];
}

- (NSString*)lego_productIdentifier
{
    return (self.userInfo)[LEGOStoreNotificationProductIdentifier];
}

- (NSArray*)lego_products
{
    return (self.userInfo)[LEGOStoreNotificationProducts];
}

- (SKDownload*)lego_storeDownload
{
    return (self.userInfo)[LEGOStoreNotificationStoreDownload];
}

- (NSError*)lego_storeError
{
    return (self.userInfo)[LEGOStoreNotificationStoreError];
}

- (SKPaymentTransaction*)lego_transaction
{
    return (self.userInfo)[LEGOStoreNotificationTransaction];
}

- (NSArray*)lego_transactions {
    return (self.userInfo)[LEGOStoreNotificationTransactions];
}

@end
