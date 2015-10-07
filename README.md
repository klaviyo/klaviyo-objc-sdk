# KlaviyoObjC

[![CI Status](http://img.shields.io/travis/Katy Keuper/KlaviyoObjC.svg?style=flat)](https://travis-ci.org/Katy Keuper/KlaviyoObjC)
[![Version](https://img.shields.io/cocoapods/v/KlaviyoObjC.svg?style=flat)](http://cocoapods.org/pods/KlaviyoObjC)
[![License](https://img.shields.io/cocoapods/l/KlaviyoObjC.svg?style=flat)](http://cocoapods.org/pods/KlaviyoObjC)
[![Platform](https://img.shields.io/cocoapods/p/KlaviyoObjC.svg?style=flat)](http://cocoapods.org/pods/KlaviyoObjC)

## Overview

KlaviyoObjC is an SDK, written im Objective-C, for users to incorporate Klaviyo's event tracking functionality into iOS applications. We also provide an SDK written in [Swift](https://github.com/klaviyo/klaviyo-swift-sdk). The two SDKs are identical in their functionality.

## Requirements
*iOS >= 8.0

## Installation Options

1. Cocoapods (recommended)
2. Download the blank, pre-configured project, and get started from scratch.

KlaviyoObjC is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "KlaviyoObjC"
```

## Example Usage: Event Tracking

To run the example project, clone the repo, and run `pod install` from the Example directory first. Make sure any .m file using the Klaviyo SDK contains the import call.

```objective-c
#import "KlaviyoObjC/Klaviyo.h"
```

To add Klaviyo's tracking functionality, it requires just a few lines of code. First, in your application delegate file (under application:didFinishLaunchingWithOptions), add the following line to set up Klaviyo: 

```objective-c
[Klaviyo setupWithPublicAPIKey:@"YOUR_PUBLIC_API_KEY"]
```

The below code example shows how to implement event or person tracking within your application. 

```objective-c
    
    NSMutableDictionary *customerProperties = [NSMutableDictionary new];
    customerProperties[@"$firstName"] = @"John";
    customerProperties[@"$lastName"] = @"Smith";
    [[Klaviyo sharedInstance] trackPersonWithInfo: customerProperties];
    [[Klaviyo sharedInstance] trackEvent:@"Logged In"];

```

## Argument Description

The `track` function can be called with anywhere between 1-4 arguments:

`eventName` This is the name of the event you want to track. It can be any string. At a bare minimum this must be provided to track and event.

`customer_properties` (optional, but recommended) This is a NSMutableDictionary of properties that belong to the person who did the action you're recording. If you do not include an $email or $id key, the user will be tracked by an $anonymous key. Note that right now anonymous user tracking is not supported, but will be shortly. In the meantime you MUST provide $email or $id for tracking purposes.

`properties` (optional) This is a NSMutableDictionary of properties that are specific to the event. In the above example we included the items purchased and the total price.

`eventDate` (optional) This is the timestamp (an NSDate) when the event occurred. You only need to include this if you're tracking past events. If you're tracking real time activity, you can ignore this argument.

Note that the only argument `trackPersonWithInfo` takes is a dictionary representing a customer's attributes. This is different from `trackEvent`, which can take multiple arguments.

## Special Properties

As was shown in the examples above, special person and event properties can be used. This works in a similar manner to the [Klaviyo Analytics API](https://www.klaviyo.com/docs). These are special properties that can be utilized when identifying a user or an event. They are:
    
    KLPersonEmailDictKey 
    KLPersonFirstNameDictKey
    KLPersonLastNameDictKey
    KLPersonPhoneNumberDictKey
    KLPersonTitleDictKey
    KLPersonOrganizationDictKey
    KLPersonCityDictKey
    KLPersonRegionDictKey
    KLPersonCountryDictKey
    KLPersonZipDictKey
    KLEventIDDictKey
    KLEventValueDictKey

Lastly, cases where you wish to call `trackEvent` with only the eventName parameter and not have it result in anonymous user tracking you can use `setUpUserEmail` to configure your user's email address. By calling this once,  usually upon application login, Klaviyo can track all subsequent events as tied to the given user. However, you are also free to override this functionality by passing in a customer properties dictionary at any time: 

```objective-c
[[Klaviyo sharedInstance] setUpUserEmail:@"john.smith@example.com"]; 
```

## Author

Katy Keuper, katy.keuper@klaviyo.com

## License

KlaviyoObjC is available under the MIT license. See the LICENSE file for more info.
