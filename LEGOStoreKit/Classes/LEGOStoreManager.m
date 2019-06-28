//
//  LEGOStoreManager.m
//  LEGOStoreKit_Example
//
//  Created by 杨庆人 on 2019/6/28.
//  Copyright © 2019年 564008993@qq.com. All rights reserved.
//

#import "LEGOStoreManager.h"

NSInteger const LEGOStoreErrorCodeUnknownProductID = 100;
NSInteger const LEGOStoreErrorCodeVerificationFailed = 101;

#ifdef DEBUG
#define checkURL @"https://sandbox.itunes.apple.com/verifyReceipt"
#else
#define checkURL @"https://buy.itunes.apple.com/verifyReceipt"
#endif

@interface LEGOStoreManager ()<SKProductsRequestDelegate,SKPaymentTransactionObserver> {
    BOOL _isContinueBuy;
}
@property (nonatomic, strong) NSMutableDictionary *productDic;
@property (nonatomic, copy) NSString *productIdentifier;   // 当前购买的商品id
@property (nonatomic, strong) NSMutableArray <SKPaymentTransaction *> *restoreTransactions;
@end

@implementation LEGOStoreManager

static LEGOStoreManager *instance = nil;

#pragma mark -单例
+(instancetype)defaultStore {
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init] ;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:instance];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [LEGOStoreManager defaultStore];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [LEGOStoreManager defaultStore];
}

- (NSMutableArray <SKPaymentTransaction *> *)restoreTransactions {
    if (!_restoreTransactions) {
        _restoreTransactions = [[NSMutableArray <SKPaymentTransaction *> alloc] init];
    }
    return _restoreTransactions;
}

- (NSMutableDictionary *)productDic {
    if (!_productDic) {
        _productDic = [[NSMutableDictionary alloc] init];
    }
    return _productDic;
}

#pragma mark -请求可用商品
- (void)requestProductsWithProductArray:(NSArray *)products
{
    NSLog(@"开始请求可销售商品");
    // 能够销售的商品
    NSSet *set = [[NSSet alloc] initWithArray:products];
    // "异步"询问苹果能否销售
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    request.delegate = self;
    // 启动请求
    [request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSMutableArray *productArray = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        // 填充商品字典
        [self.productDic setObject:product forKey:product.productIdentifier];
        // 填充商品数组
        [productArray addObject:product];
    }
    
    NSArray *invalidProductIdentifiers = [NSArray arrayWithArray:response.invalidProductIdentifiers];
    [invalidProductIdentifiers enumerateObjectsUsingBlock:^(NSString *invalid, NSUInteger idx, BOOL *stop) {
        NSLog(@"请求失败，- id：%@ - 序号：%lu - 该商品 id 不合法!", invalid, (unsigned long)idx);
    }];
    // 通知代理
    if (self.delegate && [self.delegate respondsToSelector:@selector(legoGotProducts:)]) {
        [self.delegate legoGotProducts:productArray];
    }
    if (_isContinueBuy) {
        if ([self.productDic.allKeys containsObject:self.productIdentifier]) {
            [self buyProduct:self.productIdentifier];
        }
        else {
            NSLog(@"购买失败，商品列表中无此商品");
            NSString *errorDetail = [NSString stringWithFormat:@"ID: %@ 商品不存在",[invalidProductIdentifiers firstObject]];
            NSString *errorDesc = NSLocalizedStringFromTable(errorDetail,
                                                             @"LEGOIAPKit",
                                                             @"Error description");
            NSError *error = [NSError errorWithDomain:@"com.fimoCamera.store"
                                                 code:LEGOStoreErrorCodeUnknownProductID
                                             userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:error:)]) {
                [self.delegate legoBuyProductFailure:self.productIdentifier error:error];
            }
        }
        _isContinueBuy = NO;
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
    SKProduct *product = self.productDic[productID];
    if (!product) {
        NSLog(@"未在内存中找到该商品，在线查找商品");
        _isContinueBuy = YES;
        [self requestProductsWithProductArray:@[productID]];
    }
    else {
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        // 收银台，准备购买(异步网络)
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    // 处理结果
    for (SKPaymentTransaction *transaction in transactions) {
        NSLog(@"队列状态变化 %@", transaction);
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
                NSLog(@"购买请求回调成功，开始处理...");
                // 将事务从交易队列中删除
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                if(self.isCheckByiTunesStore) {
                    //需要向苹果服务器验证一下
                    [self verifyPruchase:transaction];
                }
                else {
                    if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductSuccessed:)]) {
                        [self.delegate legoBuyProductSuccessed:transaction];
                    }
                }
            }
                break;
            case SKPaymentTransactionStateFailed: {
                NSLog(@"购买请求回调失败，开始处理...");
                // 将事务从交易队列中删除
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:error:)]) {
                    [self.delegate legoBuyProductFailure:transaction.payment.productIdentifier error:transaction.error];
                }
                [self errorCodeTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateRestored: {
                NSLog(@"恢复购买请求回调成功，开始处理...");
                [self paymentQueueRestoreTransactions:transaction];
                // 将事务从交易队列中删除
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateDeferred: {
                NSLog(@"恢复购买请求回调失败，开始处理...");
                // 将事务从交易队列中删除
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
            default:
                break;
        }
    }
}

- (void)errorCodeTransaction:(SKPaymentTransaction *)transaction {
    NSString *detail = nil;
    switch (transaction.error.code) {
        case SKErrorUnknown:
            NSLog(@"SKErrorUnknown");
            detail = @"未知的错误，请稍后重试。";
            break;
        case SKErrorClientInvalid:
            NSLog(@"SKErrorClientInvalid");
            detail = @"当前苹果账户无法购买商品(如有疑问，可以询问苹果客服)";
            break;
        case SKErrorPaymentCancelled:
            NSLog(@"SKErrorPaymentCancelled");
            detail = @"订单已取消";
            break;
        case SKErrorPaymentInvalid:
            NSLog(@"SKErrorPaymentInvalid");
            detail = @"订单无效(如有疑问，可以询问苹果客服)";
            break;
        case SKErrorPaymentNotAllowed:
            NSLog(@"SKErrorPaymentNotAllowed");
            detail = @"当前苹果设备无法购买商品(如有疑问，可以询问苹果客服)";
            break;
        case SKErrorStoreProductNotAvailable:
            NSLog(@"SKErrorStoreProductNotAvailable");
            detail = @"当前商品不可用";
            break;
        default:
            NSLog(@"No Match Found for error");
            detail = @"未知错误";
            break;
    }
    NSLog(@"detail == %@",detail);
    NSLog(@"description == %@",transaction.error.localizedDescription);
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
    NSLog(@"restore transactions finished");
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

#pragma mark 验证购买凭据
- (void)verifyPruchase:(SKPaymentTransaction *)transaction
{
    // appStoreReceiptURL 购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    // 发送网络POST请求，对购买凭据进行验证
    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt

    NSLog(@"checkURL:%@",checkURL);
    NSURL *url = [NSURL URLWithString:checkURL];
    
    // 国内访问苹果服务器比较慢，timeoutInterval需要长一点
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0f];
    request.HTTPMethod = @"POST";
    
    // 传输的是BASE64编码的字符串
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    
    request.HTTPBody = payloadData;
    
    // 提交验证请求，并获得官方的验证JSON结果
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"ID = %@ 苹果验证通过，购买完成", transaction.payment.productIdentifier);
            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductSuccessed:)]) {
                [self.delegate legoBuyProductSuccessed:transaction];
            }
        }
        else {
            NSString *errorDetail = [NSString stringWithFormat:@"ID: %@ 商品苹果验证不通过",self.productIdentifier];
            NSString *errorDesc = NSLocalizedStringFromTable(errorDetail,
                                                             @"LEGOIAPKit",
                                                             @"Error description");
            NSError *error = [NSError errorWithDomain:@"com.fimoCamera.store"
                                                 code:LEGOStoreErrorCodeVerificationFailed
                                             userInfo:@{NSLocalizedDescriptionKey:errorDesc}];
            if (self.delegate && [self.delegate respondsToSelector:@selector(legoBuyProductFailure:error:)]) {
                [self.delegate legoBuyProductFailure:transaction.payment.productIdentifier error:error];
            }
        }
    }];
}

@end
