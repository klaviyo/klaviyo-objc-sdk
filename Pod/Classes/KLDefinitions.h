
#import <Foundation/Foundation.h>

#ifdef KL_DEBUG
#	define KLLog(fmt, ...) NSLog((@"%s [Line %d] Klaviyo: " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#	define KLLog(...)
#endif

// Events tracking JSON keys

extern NSString * const KLEventTrackTokenJSONKey;
extern NSString * const KLEventTrackEventJSONKey;
extern NSString * const KLEventTrackCustomerPropetiesJSONKey;
extern NSString * const KLEventTrackPropertiesJSONKey;
extern NSString * const KLEventTrackTimeJSONKey;

// Person tracking JSON keys

extern NSString * const KLPersonTrackTokenJSONKey;
extern NSString * const KLPersonPropertiesJSONKey;

// Internal constants

extern NSString * const KlaviyoServerURLString;
extern NSString * const KlaviyoServerTrackEventEndpoint;
extern NSString * const KlaviyoServerTrackPersonEndpoint;
extern NSString * const CustomerPropertiesIDDictKey;
extern NSString * const CustomerPropertiesAppendDictKey;
extern NSString * const CustomerPropertiesAPNTokensDictKey;

extern NSString * const KLRegisterAPNDeviceTokenEvent;
