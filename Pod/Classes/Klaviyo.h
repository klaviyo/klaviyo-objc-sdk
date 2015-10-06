
#import <UIKit/UIKit.h>

//
// Use KL_DEBUG=1 in Apple LLVM Preprocessing to show Klaviyo logs
//

// Special Event Properties

extern NSString * const KLEventIDDictKey;       // an unique identifier for an event
extern NSString * const KLEventValueDictKey;    //a numeric value to associate with this event (e.g. the dollar value of a purcahse)

// Special Person Properties

extern NSString * const KLPersonIDDictKey;              // your unique identifier for a person
extern NSString * const KLPersonEmailDictKey;           // email address
extern NSString * const KLPersonFirstNameDictKey;       // first name
extern NSString * const KLPersonLastNameDictKey;        // last name
extern NSString * const KLPersonPhoneNumberDictKey;     // phone number
extern NSString * const KLPersonTitleDictKey;           // title at their business or organization
extern NSString * const KLPersonOrganizationDictKey;    // business or organization they belong to
extern NSString * const KLPersonCityDictKey;            // city they live in
extern NSString * const KLPersonRegionDictKey;          // region or start they live in
extern NSString * const KLPersonCountryDictKey;         // country they live in
extern NSString * const KLPersonZipDictKey;             // postal code where they live



@protocol KlaviyoDelegate;

@interface Klaviyo : NSObject

@property (nonatomic, weak) id<KlaviyoDelegate>     delegate;

@property (atomic) BOOL                             showNetworkActivityIndicator;

// Setup Public API key before use Klaviyo
+ (void)setupWithPublicAPIKey:(NSString*)apiKey;

+ (instancetype)sharedInstance;

- (instancetype)init __attribute__((unavailable("cannot use init for this class, use + (void)setupWithPublicAPIKey:(NSString*)apiKey; and + (instancetype)sharedInstance instead")));
+ (instancetype)new __attribute__((unavailable("cannot use new for this class, use + (void)setupWithPublicAPIKey:(NSString*)apiKey; and + (instancetype)sharedInstance instead")));

// Track specific event
- (void)trackEvent:(NSString*)eventName;

// Track specific event with your custom properties
- (void)trackEvent:(NSString*)eventName properties:(NSDictionary*)propertiesDict;

// Track specific event with your custom properties and customer properties
// Can use KLPersonIDDictKey or/and KLPersonEmailDictKey for customerPropertiesDict to identify customer and other custom properties
- (void)trackEvent:(NSString*)eventName customerProperties:(NSDictionary*)customerPropertiesDict properties:(NSDictionary*)propertiesDict;

// Track specific event with your custom properties and customer properties
// Can use KLPersonIDDictKey or/and KLPersonEmailDictKey for customerPropertiesDict to identify customer and other custom properties
// If you'd like to track an event that happened in past, use eventDate parameter
- (void)trackEvent:(NSString*)eventName customerProperties:(NSDictionary*)customerPropertiesDict properties:(NSDictionary*)propertiesDict time:(NSDate*)eventDate;

// Track properties about an individual without tracking an associated event
// Can use Special Person Properties or/and other custom properties
- (void)trackPersonWithInfo:(NSDictionary*)personInfoDict;

// Register Klaviyo with Apple Push Notifications
- (void)addPushDeviceToken:(NSData *)deviceToken;

// NEW ADDITIONS
// Register app user's email if know
- (void)setUpUserEmail:(NSString*)userEmail;


- (void)trackPersonWithInfo;

- (BOOL) emailAddressExists;

@end


@protocol KlaviyoDelegate <NSObject>
@optional

// Asks the delegate if data should be uploaded to the server.
// Return YES to upload now, NO to defer until later.
- (BOOL)klaviyoWillFlush:(Klaviyo *)mixpanel;

@end

