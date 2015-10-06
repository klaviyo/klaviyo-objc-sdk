#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
#error You can use this SDK with iOS 7.0 or higher
#endif

#import "Klaviyo.h"
#import "KLDefinitions.h"
#import "NSData+KLBase64.h"
#import "KLReachability.h"

// Track event special info dict keys (constants)

NSString * const KLEventIDDictKey                           = @"$event_id";
NSString * const KLEventValueDictKey                        = @"$value";

// Track person special info dict keys (constants)

NSString * const KLPersonIDDictKey                           = @"$id";
NSString * const KLPersonDeviceIDDictKey                     = @"$anonymous"; //previously device_id
NSString * const KLPersonEmailDictKey                        = @"$email";
NSString * const KLPersonFirstNameDictKey                    = @"$first_name";
NSString * const KLPersonLastNameDictKey                     = @"$last_name";
NSString * const KLPersonPhoneNumberDictKey                  = @"$phone_number";
NSString * const KLPersonTitleDictKey                        = @"$title";
NSString * const KLPersonOrganizationDictKey                 = @"$organization";
NSString * const KLPersonCityDictKey                         = @"$city";
NSString * const KLPersonRegionDictKey                       = @"$region";
NSString * const KLPersonCountryDictKey                      = @"$country";
NSString * const KLPersonZipDictKey                          = @"$zip";

static Klaviyo *_sharedInstance = nil;

#define URL_SESSION_MAX_CONNETCIONS                         5

@interface Klaviyo()

@property (nonatomic, copy) NSString                        *apiKey;
@property (nonatomic, strong, readonly) NSString            *iOSIDString;
@property (nonatomic, copy) NSString                        *apnDeviceToken;

@property (nonatomic, strong) dispatch_queue_t               serialQueue;
@property (nonatomic, strong) NSMutableArray                *eventsQueue;
@property (nonatomic, strong) NSMutableArray                *peopleQueue;
@property (nonatomic, strong) NSURLSession                  *urlSession;
@property (nonatomic, strong) KLReachability                *reachability;
@property (nonatomic, strong) NSString                      *userEmail;
@end


@implementation Klaviyo

@synthesize iOSIDString = _iOSIDString;

+ (void)setupWithPublicAPIKey:(NSString*)apiKey {

    if(_sharedInstance == nil) {
        [Klaviyo sharedInstanceWithAPIKey:apiKey];
    }
    else {
        _sharedInstance.apiKey = apiKey;
    }
}


+ (instancetype)sharedInstance {
    if (_sharedInstance)
        return _sharedInstance;
    
    _sharedInstance = [self sharedInstanceWithAPIKey:nil];
    KLLog(@"Use + (void)setupWithPublicAPIKey:(NSString*)apiKey to setup API key");
    return _sharedInstance;
}


+ (instancetype)sharedInstanceWithAPIKey:(NSString*)apiKey {
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] initWithAPIKey:apiKey];
    });
    
    return _sharedInstance;
}

- (instancetype)initWithAPIKey:(NSString*)apiKey {
    self = [super init];
    if(self) {
        if(apiKey == nil || apiKey.length == 0) {
            KLLog(@"Warning empty API key!");
        }
        self.apiKey = [apiKey copy];
        NSString *label = [NSString stringWithFormat:@"com.klaviyo.%@.%p", apiKey, self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.showNetworkActivityIndicator = YES;
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.allowsCellularAccess = YES;
        config.HTTPMaximumConnectionsPerHost = URL_SESSION_MAX_CONNETCIONS;
        self.urlSession = [NSURLSession sessionWithConfiguration:config];
        
        self.reachability = [KLReachability reachabilityWithHostName:@"www.klaviyo.com"];
        
        [self unarchive];
        [self flush];
        [self addNotificationsObserver];
    }
    
    return self;
}

- (void)dealloc {
    [self removeNotificationsObserver];
}

// End of instatiating method calls

#pragma mark - Properties

- (NSString*)iOSIDString {
    if(_iOSIDString) {
        return _iOSIDString;
    }
    
    _iOSIDString = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return _iOSIDString;
}


#pragma mark - Public Methods

// Method calls that should be implemented in Apps

- (void)trackEvent:(NSString*)eventName {
    [self trackEvent:eventName properties:nil];
}

- (void)trackEvent:(NSString*)eventName properties:(NSDictionary*)propertiesDict {
    [self trackEvent:eventName customerProperties:nil properties:propertiesDict];
}

- (void)trackEvent:(NSString*)eventName customerProperties:(NSDictionary*)custPropDict properties:(NSDictionary*)propDict {
    [self trackEvent:eventName customerProperties:custPropDict properties:propDict time:nil];
}

- (void)setUpUserEmail:(NSString*)userEmail {
    self.userEmail = userEmail;
}


- (void)trackEvent:(NSString*)eventName customerProperties:(NSDictionary*)custPropDict properties:(NSDictionary*)propDict time:(NSDate*)eventDate {
    if (eventName == nil || [eventName length] == 0) {
        KLLog(@"%@ klaviyo track called with empty event parameter. using 'KL_Event'", self);
        eventName = @"KL_Event";
    }
        
    propDict = [propDict copy];
    
    custPropDict = [self updatePropertiesDictionary:custPropDict];
    [Klaviyo assertPropertyTypes:propDict];
    
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *event = [NSMutableDictionary new];
        
        if(self.apiKey != nil && self.apiKey.length > 0)
            event[KLEventTrackTokenJSONKey] = self.apiKey;
        else
            event[KLEventTrackTokenJSONKey]     = @"";
        event[KLEventTrackEventJSONKey]         = eventName;
        event[KLEventTrackCustomerPropetiesJSONKey] = custPropDict;
        if([propDict.allKeys count] > 0)
            event[KLEventTrackPropertiesJSONKey]    = propDict;
        if(eventDate)
            event[KLEventTrackTimeJSONKey]          = eventDate;
        
        [self.eventsQueue addObject:event];
        if ([self.eventsQueue count] > 500) {
            [self.eventsQueue removeObjectAtIndex:0];
        }
        if ([Klaviyo inBackground]) {
            [self archiveEvents];
        }
        
        [self flushEvents];
    });
    
}

- (BOOL) emailAddressExists {
    if (self.userEmail != nil && self.userEmail.length > 0) {
        return YES;
    }
    return NO;
}

/*
Public method that tracks a user's activity within the application

:MARK - Need to add functionality to track users based off the iOSID
 
:param: NSDictionary containing the email key and the user's email address
:returns: Nothing
*/
- (void) trackPersonWithInfo {
    NSMutableDictionary *email = [NSMutableDictionary new];
    email[KLPersonEmailDictKey] = self.userEmail;
    [self trackPersonWithInfo: email];
}

- (void)trackPersonWithInfo:(NSDictionary*)personInfoDict {
    if(personInfoDict == nil || personInfoDict.allKeys.count == 0) {
        KLLog(@"Person information is empty");
        return;
    }
    
    personInfoDict = [personInfoDict copy];
    personInfoDict = [self updatePropertiesDictionary:personInfoDict];
    [Klaviyo assertPropertyTypes:personInfoDict];
    
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *event = [NSMutableDictionary new];
        
        if(self.apiKey != nil && self.apiKey.length > 0)
            event[KLPersonTrackTokenJSONKey] = self.apiKey;
        else
            event[KLPersonTrackTokenJSONKey]     = @"";
        event[KLPersonPropertiesJSONKey]         = personInfoDict;
        [self.peopleQueue addObject:event];
        if ([self.peopleQueue count] > 500) {
            [self.peopleQueue removeObjectAtIndex:0];
        }
        if ([Klaviyo inBackground]) {
            [self archivePeople];
        }
        
        [self flushPeople];
    });
    
}

- (void)addPushDeviceToken:(NSData *)deviceToken
{
    
    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    
    // set the device token
    self.apnDeviceToken = hex;
    // note that the user registered for events
    [self trackEvent:KLRegisterAPNDeviceTokenEvent];

}

#pragma mark - Private Methods

// Update the properties dictionary with appropriate info
- (NSDictionary*)updatePropertiesDictionary:(NSDictionary*)propDictionary {
    
    if(propDictionary == nil)
        propDictionary = @{};
    NSMutableDictionary *retDict = [propDictionary mutableCopy];
    
    // If email exists, use as primary key & track mobile device as secondary info
    if (self.emailAddressExists) {
        retDict[KLPersonEmailDictKey] = self.userEmail;
    } else {
        retDict[CustomerPropertiesIDDictKey] = self.iOSIDString;
    }
    
    // Set user's unique device id string
    retDict[KLPersonDeviceIDDictKey] = self.iOSIDString;
    
    // If push notifications are used, append to the list of tokens
    if (self.apnDeviceToken != nil) {
        retDict[CustomerPropertiesAppendDictKey] = @{CustomerPropertiesAPNTokensDictKey : @[self.apnDeviceToken]};
    }
    return retDict;
}

+ (void)assertPropertyTypes:(NSDictionary *)properties
{
    for (id __unused k in properties) {
        NSAssert([k isKindOfClass: [NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [k class], k);
        // would be convenient to do: id v = [properties objectForKey:k]; but
        // when the NSAssert's are stripped out in release, it becomes an
        // unused variable error. also, note that @YES and @NO pass as
        // instances of NSNumber class.
        NSAssert([properties[k] isKindOfClass:[NSString class]] ||
                 [properties[k] isKindOfClass:[NSNumber class]] ||
                 [properties[k] isKindOfClass:[NSNull class]] ||
                 [properties[k] isKindOfClass:[NSArray class]] ||
                 [properties[k] isKindOfClass:[NSDictionary class]] ||
                 [properties[k] isKindOfClass:[NSDate class]] ||
                 [properties[k] isKindOfClass:[NSURL class]],
                 @"%@ property values must be NSString, NSNumber, NSNull, NSArray, NSDictionary, NSDate or NSURL. got: %@ %@", self, [properties[k] class], properties[k]);
    }
}

- (void)addNotificationsObserver {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(hostReachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}

- (void)removeNotificationsObserver {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self forKeyPath:UIApplicationDidBecomeActiveNotification];
    [notificationCenter removeObserver:self forKeyPath:UIApplicationDidEnterBackgroundNotification];
    [notificationCenter removeObserver:self forKeyPath:UIApplicationWillTerminateNotification];
    [notificationCenter removeObserver:self forKeyPath:kReachabilityChangedNotification];
}

#pragma mark - UIApplication Events

- (void)applicationDidBecomeActiveNotification:(NSNotification*)notification {
    [self.reachability startNotifier];
}

- (void)applicationDidEnterBackgroundNotification:(NSNotification*)notification {
    [self.reachability stopNotifier];
}

- (void)applicationWillTerminateNotification:(NSNotification *)notification
{
    [self archive];
}

#pragma mark - Persistence

- (NSString *)filePathForData:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"klaviyo-%@-%@.plist", self.apiKey, data];
    
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

- (NSString *)eventsFilePath
{
    return [self filePathForData:@"events"];
}

- (NSString *)peopleFilePath
{
    return [self filePathForData:@"people"];
}

- (void)archiveEvents
{
    NSString *filePath = [self eventsFilePath];
    NSMutableArray *eventsQueueCopy = [NSMutableArray arrayWithArray:[self.eventsQueue copy]];
    KLLog(@"%@ archiving events data to %@: %@", self, filePath, eventsQueueCopy);
    if (![NSKeyedArchiver archiveRootObject:eventsQueueCopy toFile:filePath]) {
        KLLog(@"%@ unable to archive events data", self);
    }
}

- (void)archivePeople
{
    NSString *filePath = [self peopleFilePath];
    NSMutableArray *peopleQueueCopy = [NSMutableArray arrayWithArray:[self.peopleQueue copy]];
    KLLog(@"%@ archiving people data to %@: %@", self, filePath, peopleQueueCopy);
    if (![NSKeyedArchiver archiveRootObject:peopleQueueCopy toFile:filePath]) {
        KLLog(@"%@ unable to archive people data", self);
    }
}

- (void)archive
{
    [self archiveEvents];
    [self archivePeople];
}

- (void)unarchive
{
    [self unarchiveEvents];
    [self unarchivePeople];
}

- (void)unarchiveEvents
{
    self.eventsQueue = (NSMutableArray *)[self unarchiveFromFile:[self eventsFilePath]];
    
    if (!self.eventsQueue) {
        self.eventsQueue = [NSMutableArray array];
    }
}

- (void)unarchivePeople
{
    
    self.peopleQueue = (NSMutableArray *)[self unarchiveFromFile:[self peopleFilePath]];
    if (!self.peopleQueue) {
        self.peopleQueue = [NSMutableArray array];
    }
}

- (id)unarchiveFromFile:(NSString *)filePath
{
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        KLLog(@"%@ unarchived data from %@: %@", self, filePath, unarchivedData);
    }
    @catch (NSException *exception) {
        KLLog(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        unarchivedData = nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (!removed) {
            KLLog(@"%@ unable to remove archived file at %@ - %@", self, filePath, error);
        }
    }
    return unarchivedData;
}

#pragma mark - Application Helpers

+ (BOOL)inBackground
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
}

- (void)updateNetworkActivityIndicator:(BOOL)on
{
    if (_showNetworkActivityIndicator) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = on;
    }
}

#pragma mark - Network control

- (void)flush
{
    KLLog(@"%@ flush starting", self);
    
    __strong id<KlaviyoDelegate> strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(klaviyoWillFlush:)]) {
        if(![strongDelegate klaviyoWillFlush:self]) {
            KLLog(@"%@ flush deferred by delegate", self);
            return;
        }
    }
    
    [self flushEvents];
    [self flushPeople];
    
    KLLog(@"%@ flush complete", self);
}

- (void)flushEvents
{
    dispatch_async(self.serialQueue, ^{
        [self flushQueue:_eventsQueue
                endpoint:KlaviyoServerTrackEventEndpoint];
    });
}

- (void)flushPeople
{
    dispatch_async(self.serialQueue, ^{
        [self flushQueue:_peopleQueue
                endpoint:KlaviyoServerTrackPersonEndpoint];
    });
}

- (void)flushQueue:(NSMutableArray *)queue endpoint:(NSString *)endpoint
{
    if(![self isHostReachable]){
        NSLog(@"returning");
        return;
    }
    
    NSArray *currentQueue = [queue copy];
    
    for(NSDictionary *requestParamDict in currentQueue) {
        @autoreleasepool {
            //Encode the parameters
            NSString *requestParamData = [self encodeAPIParamData:requestParamDict];
            NSString *param = [NSString stringWithFormat:@"data=%@", requestParamData];
            
            //Create the URL request
            NSURLRequest *request = [self apiRequestWithEndpoint:endpoint param:param];
            
            NSLog(@"sending request %@", request);
            
            [self updateNetworkActivityIndicator:YES];
            
            NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(self.serialQueue, ^{
                    if (error) {
                        KLLog(@"%@ network failure: %@", self, error);
                    } else {
                        NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        if ([response intValue] == 0) {
                            KLLog(@"%@ %@ api rejected item %@", self, endpoint, requestParamDict);
                        }
                        
                        [queue removeObject:requestParamDict];
                    }
                    
                    if(queue.count == 0)
                        [self updateNetworkActivityIndicator:NO];
                });
            }];
            [task resume];
        }
    }
}

- (NSURLRequest *)apiRequestWithEndpoint:(NSString *)endpoint param:(NSString *)param
{
    // Concatenate the strings to construct an appropriate url
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", [KlaviyoServerURLString stringByAppendingString:endpoint], param];
    NSURL *URL = [NSURL URLWithString:urlString];
    
    //Set up the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"GET"];
    
    KLLog(@"Http request: %@", request);
    return request;
}

- (void)hostReachabilityChanged:(NSNotification *)note
{
    if([self isHostReachable]) {
        [self flush];
    }
}

- (BOOL)isHostReachable {
    return self.reachability.currentReachabilityStatus != NotReachable;
}


#pragma mark - Encoding/decoding utilities

- (NSString *)encodeAPIParamData:(NSDictionary *)dict
{
    NSString *b64String = @"";
    //serialize the dictionary
    NSData *data = [self JSONSerializeObject:dict];
    if (data) {
        // if successful, encode it base 64
        b64String = [data kl_base64EncodedString];
        //adding percent encoding with allowed characters
        b64String = (id)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                  (CFStringRef)b64String,
                                                                                  NULL,
                                                                                  CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                  kCFStringEncodingUTF8));
    }
    return b64String;
}

- (NSData *)JSONSerializeObject:(id)obj
{
    id coercedObj = [self JSONSerializableObjectForObject:obj];
    NSError *error = nil;
    NSData *data = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:coercedObj options:0 error:&error];
    }
    @catch (NSException *exception) {
        KLLog(@"%@ exception encoding api data: %@", self, exception);
    }
    if (error) {
        KLLog(@"%@ error encoding api data: %@", self, error);
    }
    return data;
}

- (id)JSONSerializableObjectForObject:(id)obj
{
    // valid json types
    if ([obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }
    // recurse on containers
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self JSONSerializableObjectForObject:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                KLLog(@"%@ warning: property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            } else {
                stringKey = [NSString stringWithString:key];
            }
            id v = [self JSONSerializableObjectForObject:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    // some common cases
    if ([obj isKindOfClass:[NSDate class]]) {
        return @([obj timeIntervalSince1970]);
    }
    
    // default to sending the object's description
    NSString *s = [obj description];
    KLLog(@"%@ warning: property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

@end
