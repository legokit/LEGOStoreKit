//
//  LEGOStoreManager.m
//  LEGOStoreKit_Example
//
//  Created by 杨庆人 on 2019/6/28.
//  Copyright © 2019年 564008993@qq.com. All rights reserved.
//

#import "LEGOStoreManager.h"

@interface LEGOStoreManager ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>
@property (nonatomic, copy) NSString *productIdentifier;   // 当前内购的商品id
@property (nonatomic, strong) NSMutableArray <SKProduct *> *productArray;  // 商品数据
@property (nonatomic, strong) NSMutableArray <SKPaymentTransaction *> *restoreTransactions;    // 恢复购买的数据
@property (nonatomic, assign) BOOL isPlaying;  // 是否要继续购买，用于请求商品数据后继续购买

@end

@implementation LEGOStoreManager

static LEGOStoreManager *instance = nil;

#pragma mark -单例
+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init] ;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:instance];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [LEGOStoreManager shareManager];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [LEGOStoreManager shareManager];
}

- (NSMutableArray <SKPaymentTransaction *> *)restoreTransactions {
    if (!_restoreTransactions) {
        _restoreTransactions = [[NSMutableArray <SKPaymentTransaction *> alloc] init];
    }
    return _restoreTransactions;
}

- (NSMutableArray <SKProduct *> *)productArray
{
    if (!_productArray) {
        _productArray = [[NSMutableArray <SKProduct *> alloc] init];
    }
    return _productArray;
}

- (SKProduct *)getSKProductWithIdentity:(NSString *)productIdentifier
{
    __block SKProduct *product = nil;
    [self.productArray enumerateObjectsUsingBlock:^(SKProduct * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.productIdentifier isEqualToString:productIdentifier]) {
            product = obj;
            *stop = YES;
        }
    }];
    return product;
}

#pragma mark -请求可用商品
- (void)requestProductsWithProductArray:(NSArray *)products
{
    NSSet *set = [[NSSet alloc] initWithArray:products];
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    self.productArray = [NSMutableArray arrayWithArray:response.products];
    NSArray *invalidProductIdentifiers = [NSArray arrayWithArray:response.invalidProductIdentifiers];
    [invalidProductIdentifiers enumerateObjectsUsingBlock:^(NSString *invalid, NSUInteger idx, BOOL *stop) {
        NSLog(@"请求失败，- id：%@ - 序号：%lu - 该商品 id 不合法!", invalid, (unsigned long)idx);
    }];
    if (self.delegate && [self.delegate respondsToSelector:@selector(legoGotProducts:)]) {
        [self.delegate legoGotProducts:response.products];
    }
    // 继续完成内购
    if (self.isPlaying) {
        self.isPlaying = NO;
        if ([self getSKProductWithIdentity:self.productIdentifier]) {
            [self buyProduct:self.productIdentifier];
        }
        else {
            NSLog(@"购买失败，商品列表中无此商品");
            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:)]) {
                [self.delegate legoBuyProductFailure:nil];
            }
        }
    }
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"Apple Store 商品请求回调处理完成...");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"Apple Store 商品请求回调失败，错误信息：%@", error.debugDescription);
}

#pragma mark -用户购买商品
- (void)buyProduct:(NSString *)productID {
    self.productIdentifier = productID;
    SKProduct *product = [self getSKProductWithIdentity:productID];
    if (product) {
        [[[SKPaymentQueue defaultQueue] transactions] enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSLog(@"obj.transactionState=%ld",obj.transactionState);
            @try {
                [[SKPaymentQueue defaultQueue] finishTransaction:obj]; // 尝试完成进行中的事务将引发异常
            } @catch (NSException *exception) {
                NSLog(@"exception=%@",exception);
            } @finally {
                
            }
        }];
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else {
        NSLog(@"未在内存中找到该商品，在线查找商品");
        self.isPlaying = YES;
        [self requestProductsWithProductArray:@[productID]];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
                NSLog(@"购买请求回调成功，开始处理...");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductSuccessed:)]) {
                    [self.delegate legoBuyProductSuccessed:transaction];
                }
            }
                break;
            case SKPaymentTransactionStateFailed: {
                NSLog(@"购买请求回调失败，开始处理...");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:)]) {
                    [self.delegate legoBuyProductFailure:transaction];
                }
            }
                break;
            case SKPaymentTransactionStateRestored: {
                NSLog(@"恢复购买请求回调成功，开始处理...");
                [self paymentQueueRestoreTransactions:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateDeferred: {
                NSLog(@"恢复购买请求回调失败，开始处理...");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
            default:
                break;
        }
    }
}

#pragma mark -恢复购买
- (void)restorePurchase {
    [self.restoreTransactions removeAllObjects];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)paymentQueueRestoreTransactions:(SKPaymentTransaction *)transaction {
    [self.restoreTransactions addObject:transaction];
}

#pragma mark -恢复购买完成
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    if (self.delegate && [self.delegate respondsToSelector:@selector(legoRestoreTransactionsSuccessed:)]) {
        [self.delegate legoRestoreTransactionsSuccessed:self.restoreTransactions];
    }
}

#pragma mark -恢复购买失败
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(legoRestoreTransactionsFailure:)]) {
        [self.delegate legoRestoreTransactionsFailure:error];
    }
}

- (void)removeTransactionObserver
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

//#pragma mark 验证购买凭据
//- (void)verifyPruchase:(SKPaymentTransaction *)transaction
//{
//    // appStoreReceiptURL 购买交易完成后，会将凭据存放在该地址
//    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
//    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
//
//    // 发送网络POST请求，对购买凭据进行验证
//    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
//    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
//
//    NSLog(@"checkURL:%@",checkURL);
//    NSURL *url = [NSURL URLWithString:checkURL];
//
//    // 国内访问苹果服务器比较慢，timeoutInterval需要长一点
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0f];
//    request.HTTPMethod = @"POST";
//
//    // 传输的是BASE64编码的字符串
//    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
//    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
//    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
//
//    request.HTTPBody = payloadData;
//
//    // 提交验证请求，并获得官方的验证JSON结果
//    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        if (!error) {
//            NSLog(@"ID = %@ 苹果验证通过，购买完成", transaction.payment.productIdentifier);
//            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductSuccessed:)]) {
//                [self.delegate legoBuyProductSuccessed:transaction];
//            }
//        }
//        else {
//            NSString *errorDetail = [NSString stringWithFormat:@"ID: %@ 商品苹果验证不通过",self.productIdentifier];
//            NSString *errorDesc = NSLocalizedStringFromTable(errorDetail,
//                                                             @"LEGOIAPKit",
//                                                             @"Error description");
//            NSError *error = [NSError errorWithDomain:@"com.fimoCamera.store"
//                                                 code:LEGOStoreErrorCodeVerificationFailed
//                                             userInfo:@{NSLocalizedDescriptionKey:errorDesc}];
//            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:error:)]) {
//                [self.delegate legoBuyProductFailure:transaction.payment.productIdentifier error:error];
//            }
//        }
//    }];
//}

@end
