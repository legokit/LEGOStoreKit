# LEGOStoreKit

[![CI Status](https://img.shields.io/travis/564008993@qq.com/LEGOStoreKit.svg?style=flat)](https://travis-ci.org/564008993@qq.com/LEGOStoreKit)
[![Version](https://img.shields.io/cocoapods/v/LEGOStoreKit.svg?style=flat)](https://cocoapods.org/pods/LEGOStoreKit)
[![License](https://img.shields.io/cocoapods/l/LEGOStoreKit.svg?style=flat)](https://cocoapods.org/pods/LEGOStoreKit)
[![Platform](https://img.shields.io/cocoapods/p/LEGOStoreKit.svg?style=flat)](https://cocoapods.org/pods/LEGOStoreKit)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

LEGOStoreKit is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'LEGOStoreKit'
```

## Usage

```
#import <StoreKit/StoreKit.h>

@protocol LEGOAppPurchaseStateDelegate <NSObject>

/**
 *  在线请求可购买商品成功
 *
 *  @param products 商品数组
 */
- (void)legoGotProducts:(NSMutableArray *)products;

/**
 *  在线请求可购买商品失败
 *
 *  @param error 失败原因
 */
- (void)legoGotProductsFailure:(NSError *)error;

/**
 *  购买成功
 *
 *  @param productID 购买成功的商品ID
 */
- (void)legoBuyProductSuccessed:(SKPaymentTransaction *)transaction;

/**
 *  购买失败
 *
 *  @param productID 商品ID
 */
- (void)legoBuyProductFailure:(NSString *)productID error:(NSError *)error;

/**
 *  恢复了已购买的商品
 *
 *  @param transactions 事务列表
 */
- (void)legoRestoreTransactionsSuccessed:(NSArray <SKPaymentTransaction *> *)transactions;

/**
 *  恢复了购买失败
 *  @param 失败的原因 error.debugDescription
 */
- (void)legoRestoreTransactionsFailure:(NSError *)error;

@end

@interface LEGOStoreManager : NSObject

/**
 *  购买完后是否在iOS端向苹果官方服务器验证一次，默认为NO
 */
@property (nonatomic, assign) BOOL isCheckByiTunesStore;

@property (nonatomic, weak) id <LEGOAppPurchaseStateDelegate> delegate;

+ (instancetype)defaultStore;

/**
 *  询问苹果的服务器能够销售哪些商品，并存于内存当中
 *
 *  @param products 商品ID的数组
 */
- (void)requestProductsWithProductArray:(NSArray <NSString *> *)products;

/**
 *  用户购买商品
 *
 *  @param productID 商品ID
 */
- (void)buyProduct:(NSString *)productID;

/**
 *  恢复用户商品
 */
- (void)restorePurchase;


@end


```

## Author

564008993@qq.com, 564008993@qq.com

## License

LEGOStoreKit is available under the MIT license. See the LICENSE file for more info.
