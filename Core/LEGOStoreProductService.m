//
//  LEGOStoreProductService.m
//  LEGOStoreKit
//
//  Created by errnull on 2019/2/28.
//  Copyright © 2019 The last stand. All rights reserved.
//

#import "LEGOStoreProductService.h"
#import "LEGOStoreManager.h"

@interface LEGOStoreProductService()

@property (nonatomic, copy) LEGOSKProductsRequestSuccessBlock successBlock;

@property (nonatomic, copy) LEGOSKProductsRequestFailureBlock failureBlock;

@end

@implementation LEGOStoreProductService

- (void)requestProducts:(NSSet*)identifiers
                success:(LEGOSKProductsRequestSuccessBlock)successBlock
                failure:(LEGOSKProductsRequestFailureBlock)failureBlock
{
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:identifiers];
    productsRequest.delegate = self;
    LEGOLogInfo(@"开始苹果服务器商品请求，等待回调...");
    [productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    LEGOLogInfo(@"苹果服务器商品请求回调成功...开始处理回调信息");
    NSArray *products = [NSArray arrayWithArray:response.products];
    NSArray *invalidProductIdentifiers = [NSArray arrayWithArray:response.invalidProductIdentifiers];
    
    for (SKProduct *product in products)
    {
        LEGOLogInfo(@"苹果服务器商品请求回调成功...商品 id：%@", product.productIdentifier);
        if (_addProductBlock) {
            _addProductBlock(product);
        }
    }
    
    [invalidProductIdentifiers enumerateObjectsUsingBlock:^(NSString *invalid, NSUInteger idx, BOOL *stop) {
        LEGOLogInfo(@"苹果服务器商品请求回调成功...商品 id 不合法！！！ id：%@ --- 序号：%lu ---", invalid, (unsigned long)idx);
    }];
    
    if (self.successBlock)
    {
        self.successBlock(products, invalidProductIdentifiers);
    }
}

- (void)requestDidFinish:(SKRequest *)request
{
    if (_removeProductRequestBlock) {
        LEGOLogInfo(@"苹果服务器商品请求回调处理结束...");
        _removeProductRequestBlock(self);
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    LEGOLogInfo(@"苹果服务器商品请求处理异常... %@", error.debugDescription);
    if (self.failureBlock)
    {
        self.failureBlock(error);
    }

    if (_removeProductRequestBlock) {
        _removeProductRequestBlock(self);
    }
}


@end


