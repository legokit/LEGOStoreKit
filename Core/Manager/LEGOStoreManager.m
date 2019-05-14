//
//  LEGOStoreManager.m
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import "LEGOStoreManager.h"
#import "LEGOStoreProductService.h"
#import "LEGOReceiptRefreshService.h"
#import "LEGOPurchasStatePostParam.h"
#import "LEGOSystemInfo.h"

#define ITMS_SANDBOX_VERIFY_RECEIPT_URL @"https://sandbox.itunes.apple.com/verifyReceipt"
#define ITMS_PRODUCT_VERIFY_RECEIPT_URL @"https://buy.itunes.apple.com/verifyReceipt"

NSString *const LEGOStoreErrorDomain = @"com.quvideo.store";
NSInteger const LEGOStoreErrorCodeDownloadCanceled = 300;
NSInteger const LEGOStoreErrorCodeUnknownProductIdentifier = 100;
NSInteger const LEGOStoreErrorCodeUnableToCompleteVerification = 200;

NSString* const LEGOSKDownloadCanceled = @"LEGOSKDownloadCanceled";
NSString* const LEGOSKDownloadFailed = @"LEGOSKDownloadFailed";
NSString* const LEGOSKDownloadFinished = @"LEGOSKDownloadFinished";
NSString* const LEGOSKDownloadPaused = @"LEGOSKDownloadPaused";
NSString* const LEGOSKDownloadUpdated = @"LEGOSKDownloadUpdated";
NSString* const LEGOSKPaymentTransactionDeferred = @"LEGOSKPaymentTransactionDeferred";
NSString* const LEGOSKPaymentTransactionFailed = @"LEGOSKPaymentTransactionFailed";
NSString* const LEGOSKPaymentTransactionFinished = @"LEGOSKPaymentTransactionFinished";
NSString* const LEGOSKProductsRequestFailed = @"LEGOSKProductsRequestFailed";
NSString* const LEGOSKProductsRequestFinished = @"LEGOSKProductsRequestFinished";
NSString* const LEGOSKRefreshReceiptFailed = @"LEGOSKRefreshReceiptFailed";
NSString* const LEGOSKRefreshReceiptFinished = @"LEGOSKRefreshReceiptFinished";
NSString* const LEGOSKRestoreTransactionsFailed = @"LEGOSKRestoreTransactionsFailed";
NSString* const LEGOSKRestoreTransactionsFinished = @"LEGOSKRestoreTransactionsFinished";

typedef void (^LEGOSKPaymentTransactionFailureBlock)(SKPaymentTransaction *transaction, NSError *error);
typedef void (^LEGOSKPaymentTransactionSuccessBlock)(SKPaymentTransaction *transaction);
typedef void (^LEGOStoreFailureBlock)(NSError *error);
typedef void (^LEGOStoreSuccessBlock)(void);

@interface LEGOAddPaymentParameters : NSObject

@property (nonatomic, strong) LEGOSKPaymentTransactionSuccessBlock successBlock;

@property (nonatomic, strong) LEGOSKPaymentTransactionFailureBlock failureBlock;

@end

@implementation LEGOAddPaymentParameters

@end

@interface LEGOStoreManager()<SKRequestDelegate>
{
    NSInteger _pendingRestoredTransactionsCount;
    BOOL _restoredCompletedTransactionsFinished;
    
    void (^_restoreTransactionsFailureBlock)(NSError* error);
    void (^_restoreTransactionsSuccessBlock)(NSArray* transactions);
}

// HACK: We use a dictionary of product identifiers because the returned SKPayment is different from the one we add to the queue. Bad Apple.
@property (nonatomic, strong) NSMutableDictionary *addPaymentParameters;

@property (nonatomic, strong) NSMutableDictionary *products;

@property (nonatomic, strong) NSMutableArray *restoredTransactions;

@property (nonatomic, strong) NSMutableSet *productsRequestSet;

@property (nonatomic, strong) LEGOReceiptRefreshService *receiptService;

@property (nonatomic, weak) id<LEGOStoreContentDownloader> contentDownloader;

@property (nonatomic, weak) id<LEGOStoreReceiptVerifier> receiptVerifier;

@property (nonatomic, weak) id<LEGOStoreTransactionPersistor> transactionPersistor;

@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

@end

@implementation LEGOStoreManager

- (NSNumberFormatter *)numberFormatter {
    if (!_numberFormatter) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        _numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        
        SKProduct *product = [[self products].allValues lastObject];
        if ([product.priceLocale.localeIdentifier containsString: @"CN"]) {
//            [_numberFormatter ]
        }
        _numberFormatter.locale = product.priceLocale;
    }
    return _numberFormatter;
}

- (instancetype) init
{
    if (self = [super init])
    {
        _restoredTransactions = [NSMutableArray array];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

+ (LEGOStoreManager *)defaultStore
{
    static LEGOStoreManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

- (void)registerContentDownloader:(id<LEGOStoreContentDownloader>)contentDownloader
{
    _contentDownloader = contentDownloader;
}

- (void)registerReceiptVerifier:(id<LEGOStoreReceiptVerifier>)receiptVerifier
{
    _receiptVerifier = receiptVerifier;
}

- (void)registerTransactionPersistor:(id<LEGOStoreTransactionPersistor>)transactionPersistor
{
    _transactionPersistor = transactionPersistor;
}

#pragma mark StoreKit wrapper

+ (BOOL)canMakePayments
{
    return [SKPaymentQueue canMakePayments];
}

- (void)addPayment:(NSString*)productIdentifier
{
    [self addPayment:productIdentifier success:nil failure:nil];
}

- (void)addPayment:(NSString*)productIdentifier
           success:(void (^)(SKPaymentTransaction *transaction))successBlock
           failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock
{
    [self addPayment:productIdentifier user:nil success:successBlock failure:failureBlock];
}

- (void)addPayment:(NSString*)productIdentifier
              user:(NSString*)userIdentifier
           success:(void (^)(SKPaymentTransaction *transaction))successBlock
           failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failureBlock
{
    
    __weak typeof(self) weakSelf = self;
    void(^errorBlock)(NSError *error)  = ^(NSError *error) {
        if (failureBlock) {
            failureBlock(nil, error);
        }
    };
    
    id completeBlock = ^(SKProduct *product) {
        if (!product) {
            NSString *errorDesc = NSLocalizedStringFromTable(@"Unknown product identifier", @"LEGOIAPKit", @"Error description");
            NSError *error = [NSError errorWithDomain:LEGOStoreErrorDomain
                                                 code:LEGOStoreErrorCodeUnknownProductIdentifier
                                             userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
            errorBlock(error);
        }else {            
            SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
            if ([payment respondsToSelector:@selector(setApplicationUsername:)])
            {
                payment.applicationUsername = userIdentifier;
            }
            
            LEGOAddPaymentParameters *parameters = [[LEGOAddPaymentParameters alloc] init];
            parameters.successBlock = successBlock;
            parameters.failureBlock = failureBlock;
            weakSelf.addPaymentParameters[productIdentifier] = parameters;
            
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    };
    
    [self fetchProduct:productIdentifier success:completeBlock failure:errorBlock];
}

#pragma mark - requestProducts
- (void)requestProducts:(NSSet*)identifiers
{
    [self requestProducts:identifiers success:nil failure:nil];
}

- (void)requestProducts:(NSSet*)identifiers
                success:(void (^)(NSArray *products, NSArray *invalidProductIdentifiers))successBlock
                failure:(void (^)(NSError *error))failureBlock
{
    LEGOLogInfo(@"本地商品信息不存在，开始从苹果服务器拉取");
    __weak typeof(self) weakSelf = self;
    LEGOStoreProductService *service = [[LEGOStoreProductService alloc] init];
    service.addProductBlock = ^(SKProduct *product) {
        [weakSelf addProduct:product];
    };
    
    service.removeProductRequestBlock = ^(LEGOStoreProductService *service) {
        [weakSelf removeProductsRequest:service];
    };
    
    [self.productsRequestSet addObject:service];
    
    [service requestProducts:identifiers
                     success:^(NSArray *products, NSArray *invalidIdentifiers)
     {
         
         if (successBlock) {
             successBlock(products, invalidIdentifiers);
         }
         
         NSDictionary *userInfo = @{LEGOStoreNotificationProducts: products, LEGOStoreNotificationInvalidProductIdentifiers: invalidIdentifiers};
         [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKProductsRequestFinished object:self userInfo:userInfo];
         
     } failure:^(NSError *error) {
         
         if (failureBlock) {
             failureBlock(error);
         }
         
         NSDictionary *userInfo = nil;
         if (error){
             // error might be nil (e.g., on airplane mode)
             userInfo = @{LEGOStoreNotificationStoreError: error};
         }
         [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKProductsRequestFailed object:self userInfo:userInfo];
     }];
}


- (void)fetchProduct:(NSString *)identifier
             success:(void (^)(SKProduct *product))success
             failure:(void (^)(NSError *error))failure
{
    if (!identifier) {
        NSString *errorDesc = NSLocalizedStringFromTable(@"Unknown product identifier", @"LEGOIAPKit", @"Error description");
        NSError *error = [NSError errorWithDomain:LEGOStoreErrorDomain
                                             code:LEGOStoreErrorCodeUnknownProductIdentifier
                                         userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        if (failure) {
            failure(error);
        }
        return;
    }
    
    SKProduct *product = [self productForIdentifier:identifier];
    if (product) {
        success(product);
        return;
    }
    
    // 若内存中没有，网络获取
    NSSet *set = [[NSSet alloc] initWithArray:@[identifier]];
    [self requestProducts:set
                  success:^(NSArray *products, NSArray *invalidProductIdentifiers)
     {
         if (products.count > 0) {
             if (success) {
                 success(products.firstObject);
             }
         }else{
             if (failure) {
                 NSString *errorDetail = [NSString stringWithFormat:@"Product do not exist ID: %@", [invalidProductIdentifiers firstObject]];
                 NSString *errorDesc = NSLocalizedStringFromTable(errorDetail, @"LEGOIAPKit", @"Error description");
                 NSError *error = [NSError errorWithDomain:LEGOStoreErrorDomain
                                                      code:LEGOStoreErrorCodeUnknownProductIdentifier
                                                  userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
                 failure(error);
             }
         }
     } failure:failure];
}

- (void)restoreTransactions
{
    [self restoreTransactionsOnSuccess:nil failure:nil];
}

- (void)restoreTransactionsOnSuccess:(void (^)(NSArray *transactions))successBlock
                             failure:(void (^)(NSError *error))failureBlock
{
    _restoredCompletedTransactionsFinished = NO;
    _pendingRestoredTransactionsCount = 0;
    _restoredTransactions = [NSMutableArray array];
    _restoreTransactionsSuccessBlock = successBlock;
    _restoreTransactionsFailureBlock = failureBlock;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)restoreTransactionsWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                                       Success:(void (^)(NSArray *transactions))successBlock
                                       failure:(void (^)(NSError *error))failureBlock
{
    [self restoreTransactionsOnSuccess:successBlock failure:failureBlock];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *errorDesc = @"RestoreRTransactions On Failure: Time Out";
        NSError *error = [NSError errorWithDomain:LEGOStoreErrorDomain
                                             code:LEGOStoreErrorCodeUnknownProductIdentifier
                                         userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        [self paymentQueue:[SKPaymentQueue defaultQueue] restoreCompletedTransactionsFailedWithError:error];
    });
}

- (void)restoreTransactionsOfUser:(NSString*)userIdentifier
                        onSuccess:(void (^)(NSArray *transactions))successBlock
                          failure:(void (^)(NSError *error))failureBlock
{
    NSAssert([[SKPaymentQueue defaultQueue] respondsToSelector:@selector(restoreCompletedTransactionsWithApplicationUsername:)], @"restoreCompletedTransactionsWithApplicationUsername: not supported in this iOS version. Use restoreTransactionsOnSuccess:failure: instead.");
    _restoredCompletedTransactionsFinished = NO;
    _pendingRestoredTransactionsCount = 0;
    _restoreTransactionsSuccessBlock = successBlock;
    _restoreTransactionsFailureBlock = failureBlock;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:userIdentifier];
}

#pragma mark Receipt

+ (NSURL*)receiptURL
{
    NSAssert(floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1, @"appStoreReceiptURL not supported in this iOS version.");
    NSURL *url = [NSBundle mainBundle].appStoreReceiptURL;
    return url;
}

- (void)refreshReceipt
{
    [self refreshReceiptOnSuccess:nil failure:nil];
}

- (void)refreshReceiptOnSuccess:(LEGOStoreSuccessBlock)successBlock
                        failure:(LEGOStoreFailureBlock)failureBlock
{
    [self.receiptService refreshReceiptOnSuccess:^{
        if (successBlock) {
            successBlock();
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKRefreshReceiptFinished object:self];
        
    } failure:^(NSError *error) {
        if (failureBlock) {
            failureBlock(error);
        }
        
        NSDictionary *userInfo = nil;
        if (error) {
            userInfo = @{LEGOStoreNotificationStoreError: error};
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKRefreshReceiptFailed object:self userInfo:userInfo];
    }];
}

- (void)base64Receipt:(void(^)(NSString *base64Data))success
              failure:(void(^)(NSError *error))failure
{
    void(^handler)(NSURL *url) = ^(NSURL *url) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSString *base64Data = [data base64EncodedStringWithOptions:0];
        if (success) {
            success(base64Data);
        }
    };
    
    NSURL *URL = [NSBundle mainBundle].appStoreReceiptURL;
    if (URL) {
        handler(URL);
    }else {
        [self refreshReceiptOnSuccess:^{
            NSURL *URL = [NSBundle mainBundle].appStoreReceiptURL;
            if (URL) {
                handler(URL);
            }else {
                if (failure) {
                    failure([NSError errorWithDomain:@"com.iapkit" code:100001 userInfo:@{NSLocalizedDescriptionKey : @"None appStoreReceiptUR"}]);
                }
            }
        } failure:failure];
    }
}

#pragma mark Product management

- (SKProduct*)productForIdentifier:(NSString*)productIdentifier
{
    return self.products[productIdentifier];
}

+ (NSString*)localizedPriceOfProduct:(SKProduct*)product
{
    NSNumberFormatter *numberFormatter = [[self defaultStore] numberFormatter];
    NSString *formattedString = [numberFormatter stringFromNumber:product.price];
    if ([formattedString containsString:@"CN"]) {
        return [formattedString stringByReplacingOccurrencesOfString:@"CN" withString:@""];
    }
    return formattedString;
}



#pragma mark Observers

- (void)addStoreObserver:(id<LEGOStoreObserver>)observer
{
    [self addStoreObserver:observer selector:@selector(storeDownloadCanceled:) notificationName:LEGOSKDownloadCanceled];
    [self addStoreObserver:observer selector:@selector(storeDownloadFailed:) notificationName:LEGOSKDownloadFailed];
    [self addStoreObserver:observer selector:@selector(storeDownloadFinished:) notificationName:LEGOSKDownloadFinished];
    [self addStoreObserver:observer selector:@selector(storeDownloadPaused:) notificationName:LEGOSKDownloadPaused];
    [self addStoreObserver:observer selector:@selector(storeDownloadUpdated:) notificationName:LEGOSKDownloadUpdated];
    [self addStoreObserver:observer selector:@selector(storeProductsRequestFailed:) notificationName:LEGOSKProductsRequestFailed];
    [self addStoreObserver:observer selector:@selector(storeProductsRequestFinished:) notificationName:LEGOSKProductsRequestFinished];
    [self addStoreObserver:observer selector:@selector(storePaymentTransactionDeferred:) notificationName:LEGOSKPaymentTransactionDeferred];
    [self addStoreObserver:observer selector:@selector(storePaymentTransactionFailed:) notificationName:LEGOSKPaymentTransactionFailed];
    [self addStoreObserver:observer selector:@selector(storePaymentTransactionFinished:) notificationName:LEGOSKPaymentTransactionFinished];
    [self addStoreObserver:observer selector:@selector(storeRefreshReceiptFailed:) notificationName:LEGOSKRefreshReceiptFailed];
    [self addStoreObserver:observer selector:@selector(storeRefreshReceiptFinished:) notificationName:LEGOSKRefreshReceiptFinished];
    [self addStoreObserver:observer selector:@selector(storeRestoreTransactionsFailed:) notificationName:LEGOSKRestoreTransactionsFailed];
    [self addStoreObserver:observer selector:@selector(storeRestoreTransactionsFinished:) notificationName:LEGOSKRestoreTransactionsFinished];
}

- (void)removeStoreObserver:(id<LEGOStoreObserver>)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKDownloadCanceled object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKDownloadFailed object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKDownloadFinished object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKDownloadPaused object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKDownloadUpdated object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKProductsRequestFailed object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKProductsRequestFinished object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKPaymentTransactionDeferred object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKPaymentTransactionFailed object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKPaymentTransactionFinished object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKRefreshReceiptFailed object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKRefreshReceiptFinished object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKRestoreTransactionsFailed object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:LEGOSKRestoreTransactionsFinished object:self];
}

// Private
- (void)addStoreObserver:(id<LEGOStoreObserver>)observer selector:(SEL)aSelector notificationName:(NSString*)notificationName
{
    if ([observer respondsToSelector:aSelector])
    {
        [[NSNotificationCenter defaultCenter] addObserver:observer selector:aSelector name:notificationName object:self];
    }
}

#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self didPurchaseTransaction:transaction queue:queue];
                break;
            case SKPaymentTransactionStateFailed:
                [self didFailTransaction:transaction queue:queue error:transaction.error];
                break;
            case SKPaymentTransactionStateRestored:
                [self didRestoreTransaction:transaction queue:queue];
                break;
            case SKPaymentTransactionStateDeferred:
                [self didDeferTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"restore transactions finished");
    _restoredCompletedTransactionsFinished = YES;
    
    [self notifyRestoreTransactionFinishedIfApplicableAfterTransaction:nil];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    if (_restoreTransactionsFailureBlock != nil)
    {
        NSLog(@"restored transactions failed with error %@", error.debugDescription);
        _restoreTransactionsFailureBlock(error);
        _restoreTransactionsFailureBlock = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKRestoreTransactionsFailed object:self userInfo:@{LEGOStoreNotificationStoreError: error}];
    }
    if (_restoreTransactionsSuccessBlock != nil)
    {
        _restoreTransactionsSuccessBlock = nil;
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
    for (SKDownload *download in downloads)
    {
        switch (download.downloadState)
        {
            case SKDownloadStateActive:
                [self didUpdateDownload:download queue:queue];
                break;
            case SKDownloadStateCancelled:
                [self didCancelDownload:download queue:queue];
                break;
            case SKDownloadStateFailed:
                [self didFailDownload:download queue:queue];
                break;
            case SKDownloadStateFinished:
                [self didFinishDownload:download queue:queue];
                break;
            case SKDownloadStatePaused:
                [self didPauseDownload:download queue:queue];
                break;
            case SKDownloadStateWaiting:
                // Do nothing
                break;
        }
    }
}

#pragma mark Download State

- (void)didCancelDownload:(SKDownload*)download queue:(SKPaymentQueue*)queue
{
    SKPaymentTransaction *transaction = download.transaction;
    NSLog(@"download %@ for product %@ canceled", download.contentIdentifier, download.transaction.payment.productIdentifier);
    
    [self postNotificationWithName:LEGOSKDownloadCanceled download:download userInfoExtras:nil];
    
    NSError *error = [NSError errorWithDomain:LEGOStoreErrorDomain code:LEGOStoreErrorCodeDownloadCanceled userInfo:@{NSLocalizedDescriptionKey: NSLocalizedStringFromTable(@"Download canceled", @"LEGOStore", @"Error description")}];
    
    const BOOL hasPendingDownloads = [self.class hasPendingDownloadsInTransaction:transaction];
    if (!hasPendingDownloads)
    {
        [self didFailTransaction:transaction queue:queue error:error];
    }
}

- (void)didFailDownload:(SKDownload*)download queue:(SKPaymentQueue*)queue
{
    NSError *error = download.error;
    SKPaymentTransaction *transaction = download.transaction;
    NSLog(@"download %@ for product %@ failed with error %@", download.contentIdentifier, transaction.payment.productIdentifier, error.debugDescription);
    
    NSDictionary *extras = error ? @{LEGOStoreNotificationStoreError : error} : nil;
    [self postNotificationWithName:LEGOSKDownloadFailed download:download userInfoExtras:extras];
    
    const BOOL hasPendingDownloads = [self.class hasPendingDownloadsInTransaction:transaction];
    if (!hasPendingDownloads)
    {
        [self didFailTransaction:transaction queue:queue error:error];
    }
}

- (void)didFinishDownload:(SKDownload*)download queue:(SKPaymentQueue*)queue
{
    SKPaymentTransaction *transaction = download.transaction;
    NSLog(@"download %@ for product %@ finished", download.contentIdentifier, transaction.payment.productIdentifier);
    
    [self postNotificationWithName:LEGOSKDownloadFinished download:download userInfoExtras:nil];
    
    const BOOL hasPendingDownloads = [self.class hasPendingDownloadsInTransaction:transaction];
    if (!hasPendingDownloads)
    {
        [self finishTransaction:download.transaction queue:queue];
    }
}

- (void)didPauseDownload:(SKDownload*)download queue:(SKPaymentQueue*)queue
{
    NSLog(@"download %@ for product %@ paused", download.contentIdentifier, download.transaction.payment.productIdentifier);
    [self postNotificationWithName:LEGOSKDownloadPaused download:download userInfoExtras:nil];
}

- (void)didUpdateDownload:(SKDownload*)download queue:(SKPaymentQueue*)queue
{
    NSLog(@"download %@ for product %@ updated", download.contentIdentifier, download.transaction.payment.productIdentifier);
    NSDictionary *extras = @{LEGOStoreNotificationDownloadProgress : @(download.progress)};
    [self postNotificationWithName:LEGOSKDownloadUpdated download:download userInfoExtras:extras];
}

+ (BOOL)hasPendingDownloadsInTransaction:(SKPaymentTransaction*)transaction
{
    for (SKDownload *download in transaction.downloads)
    {
        switch (download.downloadState)
        {
            case SKDownloadStateActive:
            case SKDownloadStatePaused:
            case SKDownloadStateWaiting:
                return YES;
            case SKDownloadStateCancelled:
            case SKDownloadStateFailed:
            case SKDownloadStateFinished:
                continue;
        }
    }
    return NO;
}

#pragma mark Transaction State

- (void)didPurchaseTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue
{
    NSLog(@"transaction purchased with product %@", transaction.payment.productIdentifier);
    if (self.receiptVerifier != nil)
    {
        [self.receiptVerifier verifyTransaction:transaction success:^{
            [self didVerifyTransaction:transaction queue:queue];
        } failure:^(NSError *error) {
            [self didFailTransaction:transaction queue:queue error:error];
        }];
    }
    else
    {
        NSLog(@"WARNING: no receipt verification");
        [self didVerifyTransaction:transaction queue:queue];
    }
}

- (void)didFailTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue error:(NSError*)error
{
    SKPayment *payment = transaction.payment;
    NSString* productIdentifier = payment.productIdentifier;
    NSLog(@"transaction failed with product %@ and error %@", productIdentifier, error.debugDescription);
    
    if (error.code != LEGOStoreErrorCodeUnableToCompleteVerification)
    { // If we were unable to complete the verification we want StoreKit to keep reminding us of the transaction
        [queue finishTransaction:transaction];
    }
    
    LEGOAddPaymentParameters *parameters = [self popAddPaymentParametersForIdentifier:productIdentifier];
    if (parameters.failureBlock != nil)
    {
        parameters.failureBlock(transaction, error);
    }
    
    NSDictionary *extras = error ? @{LEGOStoreNotificationStoreError : error} : nil;
    [self postNotificationWithName:LEGOSKPaymentTransactionFailed transaction:transaction userInfoExtras:extras];
    
    if (transaction.transactionState == SKPaymentTransactionStateRestored)
    {
        [self notifyRestoreTransactionFinishedIfApplicableAfterTransaction:transaction];
    }
}

- (void)didRestoreTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue
{
    NSLog(@"transaction restored with product %@", transaction.originalTransaction.payment.productIdentifier);
    
    _pendingRestoredTransactionsCount++;
    if (self.receiptVerifier != nil)
    {
        [self.receiptVerifier verifyTransaction:transaction success:^{
            [self didVerifyTransaction:transaction queue:queue];
        } failure:^(NSError *error) {
            [self didFailTransaction:transaction queue:queue error:error];
        }];
    }
    else
    {
        NSLog(@"WARNING: no receipt verification");
        [self didVerifyTransaction:transaction queue:queue];
    }
}

- (void)didDeferTransaction:(SKPaymentTransaction *)transaction
{
    [self postNotificationWithName:LEGOSKPaymentTransactionDeferred transaction:transaction userInfoExtras:nil];
}

- (void)didVerifyTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue
{
    if (self.contentDownloader != nil)
    {
        [self.contentDownloader downloadContentForTransaction:transaction success:^{
            [self postNotificationWithName:LEGOSKDownloadFinished transaction:transaction userInfoExtras:nil];
            [self didDownloadSelfHostedContentForTransaction:transaction queue:queue];
        } progress:^(float progress) {
            NSDictionary *extras = @{LEGOStoreNotificationDownloadProgress : @(progress)};
            [self postNotificationWithName:LEGOSKDownloadUpdated transaction:transaction userInfoExtras:extras];
        } failure:^(NSError *error) {
            NSDictionary *extras = error ? @{LEGOStoreNotificationStoreError : error} : nil;
            [self postNotificationWithName:LEGOSKDownloadFailed transaction:transaction userInfoExtras:extras];
            [self didFailTransaction:transaction queue:queue error:error];
        }];
    } else {
        [self didDownloadSelfHostedContentForTransaction:transaction queue:queue];
    }
}

- (void)didDownloadSelfHostedContentForTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue
{
    NSArray *downloads = [transaction respondsToSelector:@selector(downloads)] ? transaction.downloads : @[];
    if (downloads.count > 0)
    {
        NSLog(@"starting downloads for product %@ started", transaction.payment.productIdentifier);
        [queue startDownloads:downloads];
    }
    else
    {
        [self finishTransaction:transaction queue:queue];
    }
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue
{
    SKPayment *payment = transaction.payment;
    NSString* productIdentifier = payment.productIdentifier;
    [queue finishTransaction:transaction];
    [self.transactionPersistor persistTransaction:transaction];
    
    LEGOAddPaymentParameters *wrapper = [self popAddPaymentParametersForIdentifier:productIdentifier];
    if (wrapper.successBlock != nil)
    {
        wrapper.successBlock(transaction);
    }
    
    [self postNotificationWithName:LEGOSKPaymentTransactionFinished transaction:transaction userInfoExtras:nil];
    
    if (transaction.transactionState == SKPaymentTransactionStateRestored)
    {
        [self notifyRestoreTransactionFinishedIfApplicableAfterTransaction:transaction];
    }
}

- (void)notifyRestoreTransactionFinishedIfApplicableAfterTransaction:(SKPaymentTransaction*)transaction
{
    if (transaction != nil)
    {
        [_restoredTransactions addObject:transaction];
        _pendingRestoredTransactionsCount--;
    }
    if (_restoredCompletedTransactionsFinished && _pendingRestoredTransactionsCount == 0)
    { // Wait until all restored transations have been verified
        NSArray *restoredTransactions = [_restoredTransactions copy];
        if (_restoreTransactionsSuccessBlock != nil)
        {
            _restoreTransactionsSuccessBlock(restoredTransactions);
            _restoreTransactionsSuccessBlock = nil;
        }
        if (_restoreTransactionsFailureBlock != nil) {
            _restoreTransactionsFailureBlock = nil;
        }
        NSDictionary *userInfo = @{ LEGOStoreNotificationTransactions : restoredTransactions };
        [[NSNotificationCenter defaultCenter] postNotificationName:LEGOSKRestoreTransactionsFinished object:self userInfo:userInfo];
    }
}

- (LEGOAddPaymentParameters*)popAddPaymentParametersForIdentifier:(NSString*)identifier
{
    LEGOAddPaymentParameters *parameters = self.addPaymentParameters[identifier];
    [self.addPaymentParameters removeObjectForKey:identifier];
    return parameters;
}

#pragma mark Private

- (void)addProduct:(SKProduct*)product
{
    self.products[product.productIdentifier] = product;
}

- (void)postNotificationWithName:(NSString*)notificationName download:(SKDownload*)download userInfoExtras:(NSDictionary*)extras
{
    NSMutableDictionary *mutableExtras = extras ? [NSMutableDictionary dictionaryWithDictionary:extras] : [NSMutableDictionary dictionary];
    mutableExtras[LEGOStoreNotificationStoreDownload] = download;
    [self postNotificationWithName:notificationName transaction:download.transaction userInfoExtras:mutableExtras];
}

- (void)postNotificationWithName:(NSString*)notificationName transaction:(SKPaymentTransaction*)transaction userInfoExtras:(NSDictionary*)extras
{
    NSString *productIdentifier = transaction.payment.productIdentifier;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[LEGOStoreNotificationTransaction] = transaction;
    userInfo[LEGOStoreNotificationProductIdentifier] = productIdentifier;
    if (extras) {
        [userInfo addEntriesFromDictionary:extras];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
}

- (void)removeProductsRequest:(LEGOStoreProductService *)request
{
    [self.productsRequestSet removeObject:request];
}

#pragma mark - lazy load

- (NSMutableSet *)productsRequestSet
{
    if (!_productsRequestSet) {
        _productsRequestSet = [NSMutableSet set];
    }
    
    return _productsRequestSet;
}

- (LEGOReceiptRefreshService *)receiptService
{
    if (_receiptService) {
        _receiptService = [[LEGOReceiptRefreshService alloc] init];
    }
    
    return _receiptService;
}

- (NSMutableDictionary *)addPaymentParameters
{
    if (!_addPaymentParameters) {
        _addPaymentParameters = [NSMutableDictionary dictionary];
    }
    
    return _addPaymentParameters;
}

- (NSMutableDictionary *)products
{
    if (!_products) {
        _products = [NSMutableDictionary dictionary];
    }
    
    return _products;
}

@end

