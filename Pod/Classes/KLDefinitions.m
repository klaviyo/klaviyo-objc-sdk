
#import "KLDefinitions.h"

// Events tracking JSON keys

NSString * const KLEventTrackTokenJSONKey                    = @"token";
NSString * const KLEventTrackEventJSONKey                    = @"event";
NSString * const KLEventTrackCustomerPropetiesJSONKey        = @"customer_properties";
NSString * const KLEventTrackPropertiesJSONKey               = @"properties";
NSString * const KLEventTrackTimeJSONKey                     = @"time";

// Person tracking JSON keys

NSString * const KLPersonTrackTokenJSONKey                   = @"token";
NSString * const KLPersonPropertiesJSONKey                   = @"properties";

NSString * const KlaviyoServerURLString                     = @"https://a.klaviyo.com/api";
NSString * const KlaviyoServerTrackEventEndpoint            = @"/track";
NSString * const KlaviyoServerTrackPersonEndpoint           = @"/identify";

/*
Temporary API workaround. Swap out commented line of code once the $anonymous trackign is set up 
*/
NSString * const CustomerPropertiesIDDictKey                = @"$device_id";
//NSString * const CustomerPropertiesIDDictKey                = @"$id";

NSString * const CustomerPropertiesAppendDictKey            = @"$append";
NSString * const CustomerPropertiesAPNTokensDictKey         = @"$ios_tokens";

NSString * const KLRegisterAPNDeviceTokenEvent              = @"KL_ReceiveNotificationsDeviceToken";
