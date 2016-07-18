//
// ObjectiveFlickr.m
//
// Copyright (c) 2006-2014 Lukhnos D. Liu (http://lukhnos.org)
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import "ObjectiveFlickr.h"
#import "OFUtilities.h"
#import "OFXMLMapper.h"

NSString *const OFFlickrSmallSquareSize = @"s";
NSString *const OFFlickrLargeSquareSize = @"q";
NSString *const OFFlickrThumbnailSize = @"t";
NSString *const OFFlickrSmallSize = @"m";
NSString *const OFFlickrSmallSize320 = @"n";
NSString *const OFFlickrMediumSize = nil;
NSString *const OFFlickrMediumSquareSize640 = @"z";
NSString *const OFFlickrMediumSquareSize800 = @"c";
NSString *const OFFlickrLargeSize = @"b";

NSString *const OFFlickrReadPermission = @"read";
NSString *const OFFlickrWritePermission = @"write";
NSString *const OFFlickrDeletePermission = @"delete";

NSString *const OFFlickrUploadTempFilenamePrefix = @"org.lukhnos.ObjectiveFlickr.upload";
NSString *const OFFlickrAPIReturnedErrorDomain = @"com.flickr";
NSString *const OFFlickrAPIRequestErrorDomain = @"org.lukhnos.ObjectiveFlickr";

NSString *const OFFlickrAPIRequestOAuthErrorUserInfoKey = @"OAuthError";
NSString *const OFFetchOAuthRequestTokenSession = @"FetchOAuthRequestToken";
NSString *const OFFetchOAuthAccessTokenSession = @"FetchOAuthAccessToken";

static NSString *const kEscapeChars = @"`~!@#$^&*()=+[]\\{}|;':\",/<>?";

static NSString *const kDefaultFlickrRESTAPIEndpoint = @"https://api.flickr.com/services/rest/";
static NSString *const kDefaultFlickrPhotoSource = @"https://staticflickr.com/";
static NSString *const kDefaultFlickrPhotoWebPageSource = @"https://www.flickr.com/photos/";
static NSString *const kDefaultFlickrAuthEndpoint = @"https://www.flickr.com/services/oauth/";
static NSString *const kDefaultFlickrUploadEndpoint = @"https://up.flickr.com/services/upload/";

static void AssertIsValidURLString(NSString *urlString)
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSCAssert(url, @"Must be a valid URL, but was given: %@", urlString);
    (void) url;
}


@interface OFFlickrAPIContext (PrivateMethods)
- (NSArray *)signedArgumentComponentsFromArguments:(NSDictionary *)inArguments useURIEscape:(BOOL)inUseEscape;
- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments;
@end


@implementation OFFlickrAPIContext
- (void)dealloc
{
    [key release];
    [sharedSecret release];
    [authToken release];
    
    [RESTAPIEndpoint release];
	[photoSource release];
	[photoWebPageSource release];
	[authEndpoint release];
    [uploadEndpoint release];
    
    [oauthToken release];
    [oauthTokenSecret release];
    
    [super dealloc];
}

- (instancetype)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret
{
    if ((self = [super init])) {
        key = [inKey copy];
        sharedSecret = [inSharedSecret copy];
        
        RESTAPIEndpoint = kDefaultFlickrRESTAPIEndpoint;
		photoSource = kDefaultFlickrPhotoSource;
		photoWebPageSource = kDefaultFlickrPhotoWebPageSource;
		authEndpoint = kDefaultFlickrAuthEndpoint;
        uploadEndpoint = kDefaultFlickrUploadEndpoint;
    }
    return self;
}

- (void)setAuthToken:(NSString *)inAuthToken
{
    NSString *tmp = authToken;
    authToken = [inAuthToken copy];
    [tmp release];
}

- (NSString *)authToken
{
    return authToken;
}

- (NSURL *)userAuthorizationURLWithRequestToken:(NSString *)inRequestToken requestedPermission:(NSString *)inPermission
{
    NSString *perms = @"";
    
    if (inPermission.length > 0) {
        perms = [NSString stringWithFormat:@"&perms=%@", inPermission];
    }
    
    NSString *URLString = [NSString stringWithFormat:@"https://www.flickr.com/services/oauth/authorize?oauth_token=%@%@", inRequestToken, perms];
    return [NSURL URLWithString:URLString];
}

- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier
{
    // From https://www.flickr.com/services/api/misc.urls.html, the URL is one of the following:
    // * http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}.jpg
    // * http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}_[mstzb].jpg
    // * http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{o-secret}_o.(jpg|gif|png)


	NSString *photoID = inDictionary[@"id"];
    NSAssert([photoID length], nil);

	NSString *secret = inDictionary[@"secret"];
    NSAssert([secret length], nil);

	NSString *server = inDictionary[@"server"];
	NSAssert([server length], nil);

    NSString *farmID = inDictionary[@"farm"];

    NSURL *basePhotoSourceURL = [NSURL URLWithString:photoSource];
    NSString *scheme = basePhotoSourceURL.scheme;
    NSString *host = basePhotoSourceURL.host;

	if (farmID.length) {
        host = [NSString stringWithFormat:@"farm%@.%@", farmID, host];
	}

    NSString *sizeSuffix = @"";
    if (inSizeModifier.length) {
        sizeSuffix = [NSString stringWithFormat:@"_%@", inSizeModifier];
    }

    // TODO: Add originalsecret and originalformat support
    NSString *formatExt = @"jpg";

    // Combine the path
    NSString *path = [NSString stringWithFormat:@"/%@/%@_%@%@.%@", server, photoID, secret, sizeSuffix, formatExt];

    NSURL *staticURL = [[[NSURL alloc] initWithScheme:scheme host:host path:path] autorelease];
	return staticURL;
}

- (NSURL *)photoWebPageURLFromDictionary:(NSDictionary *)inDictionary
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", photoWebPageSource, inDictionary[@"owner"], inDictionary[@"id"]]];
}

- (NSURL *)loginURLFromFrobDictionary:(NSDictionary *)inFrob requestedPermission:(NSString *)inPermission
{
	NSString *frob = inFrob[@"frob"][OFXMLTextContentKey];
    NSDictionary *argDict = frob.length ? @{@"frob": frob, @"perms": inPermission} : @{@"perms": inPermission};
	NSString *URLString = [NSString stringWithFormat:@"%@?%@", authEndpoint, [self signedQueryFromArguments:argDict]];
	return [NSURL URLWithString:URLString];
}

- (void)setRESTAPIEndpoint:(NSString *)inEndpoint
{
    NSString *tmp = RESTAPIEndpoint;
    RESTAPIEndpoint = [inEndpoint copy];
    [tmp release];
}

- (NSString *)RESTAPIEndpoint
{
    return RESTAPIEndpoint;
}

- (void)setPhotoSource:(NSString *)inSource
{
    AssertIsValidURLString(inSource);
	NSString *tmp = photoSource;
	photoSource = [inSource copy];
	[tmp release];
}

- (NSString *)photoSource
{
	return photoSource;
}

- (void)setPhotoWebPageSource:(NSString *)inSource
{
    AssertIsValidURLString(inSource);
	NSString *tmp = photoWebPageSource;
	photoWebPageSource = [inSource copy];
	[tmp release];
}

- (NSString *)photoWebPageSource
{
	return photoWebPageSource;
}

- (void)setAuthEndpoint:(NSString *)inEndpoint
{
	NSString *tmp = authEndpoint;
	authEndpoint = [inEndpoint copy];
	[tmp release];
}

- (NSString *)authEndpoint
{
	return authEndpoint;
}

- (void)setUploadEndpoint:(NSString *)inEndpoint
{
    NSString *tmp = uploadEndpoint;
    uploadEndpoint = [inEndpoint copy];
    [tmp release];
}

- (NSString *)uploadEndpoint
{
    return uploadEndpoint;
}

- (void)setOAuthToken:(NSString *)inToken
{
    NSString *tmp = oauthToken;
    oauthToken = [inToken copy];
    [tmp release];    
}

- (NSString *)OAuthToken
{
    return oauthToken;
}

- (void)setOAuthTokenSecret:(NSString *)inSecret;
{
    NSString *tmp = oauthTokenSecret;
    oauthTokenSecret = [inSecret copy];
    [tmp release];    
}

- (NSString *)OAuthTokenSecret
{
    return oauthTokenSecret;
}

@synthesize key;
@synthesize sharedSecret;
@end

@implementation OFFlickrAPIContext (PrivateMethods)
- (NSArray *)signedArgumentComponentsFromArguments:(NSDictionary *)inArguments useURIEscape:(BOOL)inUseEscape
{
    NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
	if (key.length) {
		newArgs[@"api_key"] = key;
	}
	
	if (authToken.length) {
		newArgs[@"auth_token"] = authToken;
	}
	
	// combine the args
	NSMutableArray *argArray = [NSMutableArray array];
	NSMutableString *sigString = [NSMutableString stringWithString:sharedSecret.length ? sharedSecret : @""];
	NSArray *sortedArgs = [newArgs.allKeys sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *argEnumerator = [sortedArgs objectEnumerator];
	NSString *nextKey;
	while ((nextKey = [argEnumerator nextObject])) {
		NSString *value = [newArgs[nextKey] description];
		[sigString appendFormat:@"%@%@", nextKey, value];
		[argArray addObject:@[nextKey, (inUseEscape ? OFEscapedURLStringFromNSString(value) : value)]];
	}
	
	NSString *signature = OFMD5HexStringFromNSString(sigString);    
    [argArray addObject:@[@"api_sig", signature]];
	return argArray;
}


- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments
{
    NSArray *argComponents = [self signedArgumentComponentsFromArguments:inArguments useURIEscape:YES];
    NSMutableArray *args = [NSMutableArray array];
    NSEnumerator *componentEnumerator = [argComponents objectEnumerator];
    NSArray *nextArg;
    while ((nextArg = [componentEnumerator nextObject])) {
        [args addObject:[nextArg componentsJoinedByString:@"="]];
    }
    
    return [args componentsJoinedByString:@"&"];
}

- (NSDictionary *)signedOAuthHTTPQueryArguments:(NSDictionary *)inArguments baseURL:(NSURL *)inURL method:(NSString *)inMethod
{
    NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
    newArgs[@"oauth_nonce"] = [OFGenerateUUIDString() substringToIndex:8];
    newArgs[@"oauth_timestamp"] = [NSString stringWithFormat:@"%lu", (long)[NSDate date].timeIntervalSince1970];
    newArgs[@"oauth_version"] = @"1.0";
    newArgs[@"oauth_signature_method"] = @"HMAC-SHA1";
    newArgs[@"oauth_consumer_key"] = key;
    
    if (!inArguments[@"oauth_token"] && oauthToken) {
        newArgs[@"oauth_token"] = oauthToken;
    }
    
    NSString *signatureKey = nil;
    if (oauthTokenSecret) {
        signatureKey = [NSString stringWithFormat:@"%@&%@", sharedSecret, oauthTokenSecret];
    }
    else {
        signatureKey = [NSString stringWithFormat:@"%@&", sharedSecret];
    }
    
    NSMutableString *baseString = [NSMutableString string];
    [baseString appendString:inMethod];
    [baseString appendString:@"&"];
    [baseString appendString:OFEscapedURLStringFromNSStringWithExtraEscapedChars(inURL.absoluteString, kEscapeChars)];
    
    NSArray *sortedArgKeys = [newArgs.allKeys sortedArrayUsingSelector:@selector(compare:)];
    [baseString appendString:@"&"];
    
    NSMutableArray *baseStrArgs = [NSMutableArray array];
    NSEnumerator *kenum = [sortedArgKeys objectEnumerator];
    NSString *k;
    while ((k = [kenum nextObject]) != nil) {
        [baseStrArgs addObject:[NSString stringWithFormat:@"%@=%@", k, OFEscapedURLStringFromNSStringWithExtraEscapedChars([newArgs[k] description], kEscapeChars)]];
    }
    
    [baseString appendString:OFEscapedURLStringFromNSStringWithExtraEscapedChars([baseStrArgs componentsJoinedByString:@"&"], kEscapeChars)];
    
    NSString *signature = OFHMACSha1Base64(signatureKey, baseString);
    
    newArgs[@"oauth_signature"] = signature;
    return newArgs;
}

- (NSURL *)oauthURLFromBaseURL:(NSURL *)inURL method:(NSString *)inMethod arguments:(NSDictionary *)inArguments
{
    NSDictionary *newArgs = [self signedOAuthHTTPQueryArguments:inArguments baseURL:inURL method:inMethod];
    NSMutableArray *queryArray = [NSMutableArray array];

    NSEnumerator *kenum = [newArgs keyEnumerator];
    NSString *k;
    while ((k = [kenum nextObject]) != nil) {
        [queryArray addObject:[NSString stringWithFormat:@"%@=%@", k, OFEscapedURLStringFromNSStringWithExtraEscapedChars([newArgs[k] description], kEscapeChars)]];
    }
    
    
    NSString *newURLStringWithQuery = [NSString stringWithFormat:@"%@?%@", inURL.absoluteString, [queryArray componentsJoinedByString:@"&"]];
    
    return [NSURL URLWithString:newURLStringWithQuery];
}
@end

@interface OFFlickrAPIRequest (PrivateMethods)
- (void)cleanUpTempFile;
@end            

@implementation OFFlickrAPIRequest
- (void)dealloc
{
    [context release];
    HTTPRequest.delegate = nil;
    [HTTPRequest cancelWithoutDelegateMessage];
    [HTTPRequest release];
    [sessionInfo release];
    
    [self cleanUpTempFile];
    
    [super dealloc];
}

- (instancetype)initWithAPIContext:(OFFlickrAPIContext *)inContext
{
    if ((self = [super init])) {
        context = [inContext retain];
        
        HTTPRequest = [[LFHTTPRequest alloc] init];
        HTTPRequest.delegate = self;
    }
    
    return self;
}

- (OFFlickrAPIContext *)context
{
	return context;
}

- (OFFlickrAPIRequestDelegateType)delegate
{
    return delegate;
}

- (void)setDelegate:(OFFlickrAPIRequestDelegateType)inDelegate
{
    delegate = inDelegate;
}

- (id)sessionInfo
{
    return [[sessionInfo retain] autorelease];
}

- (void)setSessionInfo:(id)inInfo
{
    id tmp = sessionInfo;
    sessionInfo = [inInfo retain];
    [tmp release];
}

- (NSTimeInterval)requestTimeoutInterval
{
    return HTTPRequest.timeoutInterval;
}

- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval
{
    HTTPRequest.timeoutInterval = inTimeInterval;
}

- (BOOL)isRunning
{
    return HTTPRequest.isRunning;
}

- (void)cancel
{
    [HTTPRequest cancelWithoutDelegateMessage];
    [self cleanUpTempFile];
}

- (BOOL)fetchOAuthRequestTokenWithCallbackURL:(NSURL *)inCallbackURL
{
    if (HTTPRequest.isRunning) {
        return NO;
    }

    NSDictionary *paramsDictionary = @{@"oauth_callback": inCallbackURL.absoluteString};
    NSURL *requestURL = [context oauthURLFromBaseURL:[NSURL URLWithString:@"https://www.flickr.com/services/oauth/request_token"] method:LFHTTPRequestGETMethod arguments:paramsDictionary];
    HTTPRequest.sessionInfo = OFFetchOAuthRequestTokenSession;
    [HTTPRequest setContentType:nil];
    return [HTTPRequest performMethod:LFHTTPRequestGETMethod onURL:requestURL withData:nil];
}

- (BOOL)fetchOAuthAccessTokenWithRequestToken:(NSString *)inRequestToken verifier:(NSString *)inVerifier
{
    if (HTTPRequest.isRunning) {
        return NO;
    }
    NSDictionary *paramsDictionary = @{@"oauth_token": inRequestToken, @"oauth_verifier": inVerifier};
    NSURL *requestURL = [context oauthURLFromBaseURL:[NSURL URLWithString:@"https://www.flickr.com/services/oauth/access_token"] method:LFHTTPRequestGETMethod arguments:paramsDictionary];
    HTTPRequest.sessionInfo = OFFetchOAuthAccessTokenSession;
    [HTTPRequest setContentType:nil];
    return [HTTPRequest performMethod:LFHTTPRequestGETMethod onURL:requestURL withData:nil];
}

- (BOOL)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments
{
    if (HTTPRequest.isRunning) {
        return NO;
    }
    
    // combine the parameters 
	NSMutableDictionary *newArgs = inArguments ? [NSMutableDictionary dictionaryWithDictionary:inArguments] : [NSMutableDictionary dictionary];
	newArgs[@"method"] = inMethodName;	

    NSURL *requestURL = nil;
    if (context.OAuthToken && context.OAuthTokenSecret) {
        requestURL = [context oauthURLFromBaseURL:[NSURL URLWithString:context.RESTAPIEndpoint] method:LFHTTPRequestGETMethod arguments:newArgs];
    }
    else {
        NSString *query = [context signedQueryFromArguments:newArgs];
        NSString *URLString = [NSString stringWithFormat:@"%@?%@", context.RESTAPIEndpoint, query];
        requestURL = [NSURL URLWithString:URLString];
    }
    
    if (requestURL) {
        [HTTPRequest setContentType:nil];
        return [HTTPRequest performMethod:LFHTTPRequestGETMethod onURL:requestURL withData:nil];        
    }
    return NO;
}

static NSData *NSDataFromOAuthPreferredWebForm(NSDictionary *formDictionary)
{
    NSMutableString *combinedDataString = [NSMutableString string];
    NSEnumerator *enumerator = [formDictionary keyEnumerator];
    
    NSString *key = [enumerator nextObject];
    if (key) {
        NSString *value = [formDictionary[key] description];
        [combinedDataString appendString:[NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]], [value stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]]]];
        
        while ((key = [enumerator nextObject])) {
            value = [formDictionary[key] description];
            [combinedDataString appendString:[NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]], [value stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]]]];
        }
    }
    
    return [combinedDataString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];    
}

- (BOOL)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments
{
    if (HTTPRequest.isRunning) {
        return NO;
    }
    
    // combine the parameters 
	NSMutableDictionary *newArgs = inArguments ? [NSMutableDictionary dictionaryWithDictionary:inArguments] : [NSMutableDictionary dictionary];
	newArgs[@"method"] = inMethodName;	
    
    
    NSData *postData = nil;
    
    if (context.OAuthToken && context.OAuthTokenSecret) {
        NSDictionary *signedArgs = [context signedOAuthHTTPQueryArguments:newArgs baseURL:[NSURL URLWithString:context.RESTAPIEndpoint] method:LFHTTPRequestPOSTMethod];
        
        postData = NSDataFromOAuthPreferredWebForm(signedArgs);
    }
    else {    
        NSString *arguments = [context signedQueryFromArguments:newArgs];
        postData = [arguments dataUsingEncoding:NSUTF8StringEncoding];
    }
    
	HTTPRequest.contentType = LFHTTPRequestWWWFormURLEncodedContentType;
	return [HTTPRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:context.RESTAPIEndpoint] withData:postData];
}

- (BOOL)uploadImageStream:(NSInputStream *)inImageStream suggestedFilename:(NSString *)inFilename MIMEType:(NSString *)inType arguments:(NSDictionary *)inArguments
{
    if (HTTPRequest.isRunning) {
        return NO;
    }
    
    // get the api_sig
    NSArray *argComponents = nil;
    
    if (context.OAuthToken && context.OAuthTokenSecret) {
        NSMutableArray *newArgsComps = [NSMutableArray array];
        NSDictionary *signedArgs = [context signedOAuthHTTPQueryArguments:(inArguments ? inArguments : @{}) baseURL:[NSURL URLWithString:context.uploadEndpoint] method:LFHTTPRequestPOSTMethod];
        
        NSEnumerator *keyEnum = [signedArgs keyEnumerator];
        NSString *key;
        while ((key = [keyEnum nextObject]) != nil) {
            NSString *value = [signedArgs valueForKey:key];
            [newArgsComps addObject:@[key, value]];
        }
        
        argComponents = newArgsComps;
    }
    else if (context.authToken.length > 0) {
        argComponents = [self.context signedArgumentComponentsFromArguments:(inArguments ? inArguments : @{}) useURIEscape:NO];
    }
    else {
        return NO;
    }
    
    NSString *separator = OFGenerateUUIDString();
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", separator];
    
    // build the multipart form
    NSMutableString *multipartBegin = [NSMutableString string];
    NSMutableString *multipartEnd = [NSMutableString string];
    
    NSEnumerator *componentEnumerator = [argComponents objectEnumerator];
    NSArray *nextArgComponent;
    while ((nextArgComponent = [componentEnumerator nextObject])) {        
        [multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", separator, nextArgComponent[0], nextArgComponent[1]];
    }

    // add filename, if nil, generate a UUID
    [multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"%@\"\r\n", separator, inFilename.length ? inFilename : OFGenerateUUIDString()];
    [multipartBegin appendFormat:@"Content-Type: %@\r\n\r\n", inType];
        
    [multipartEnd appendFormat:@"\r\n--%@--", separator];
    
    
    // now we have everything, create a temp file for this purpose; although UUID is inferior to 
    [self cleanUpTempFile];
	
    uploadTempFilename = [[NSTemporaryDirectory() stringByAppendingFormat:@"%@.%@", OFFlickrUploadTempFilenamePrefix, OFGenerateUUIDString()] retain];
    
    // create the write stream
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:uploadTempFilename append:NO];
    [outputStream open];
    
    const char *UTF8String;
    size_t writeLength;
    UTF8String = multipartBegin.UTF8String;
    writeLength = strlen(UTF8String);
	
	size_t __unused actualWrittenLength;
	actualWrittenLength = [outputStream write:(uint8_t *)UTF8String maxLength:writeLength];
    NSAssert(actualWrittenLength == writeLength, @"Must write multipartBegin");
	
    // open the input stream
    const size_t bufferSize = 65536;
    size_t readSize = 0;
    uint8_t *buffer = (uint8_t *)calloc(1, bufferSize);
    NSAssert(buffer, @"Must have enough memory for copy buffer");

    [inImageStream open];
    while (inImageStream.hasBytesAvailable) {
        if (!(readSize = [inImageStream read:buffer maxLength:bufferSize])) {
            break;
        }
        
		
		size_t __unused actualWrittenLength;
		actualWrittenLength = [outputStream write:buffer maxLength:readSize];
        NSAssert (actualWrittenLength == readSize, @"Must completes the writing");
    }
    
    [inImageStream close];
    free(buffer);
    
    
    UTF8String = multipartEnd.UTF8String;
    writeLength = strlen(UTF8String);
	actualWrittenLength = [outputStream write:(uint8_t *)UTF8String maxLength:writeLength];
    NSAssert(actualWrittenLength == writeLength, @"Must write multipartBegin");
    [outputStream close];
    
    NSError *error = nil;
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:uploadTempFilename error:&error];
    NSAssert(fileInfo && !error, @"Must have upload temp file");
    NSNumber *fileSizeNumber = fileInfo[NSFileSize];
    NSUInteger fileSize = fileSizeNumber.integerValue;
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:uploadTempFilename];
	
    HTTPRequest.contentType = contentType;
    return [HTTPRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:context.uploadEndpoint] withInputStream:inputStream knownContentSize:fileSize];
}

#pragma mark LFHTTPRequest delegate methods
- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
    if (request.sessionInfo == OFFetchOAuthRequestTokenSession) {
        [request setSessionInfo:nil];
        
        NSString *response = [[[NSString alloc] initWithData:request.receivedData encoding:NSUTF8StringEncoding] autorelease];

        NSDictionary *params = OFExtractURLQueryParameter(response);
        NSString *oat = params[@"oauth_token"];
        NSString *oats = params[@"oauth_token_secret"];
        if (!oat || !oats) {
            NSDictionary *userInfo = @{OFFlickrAPIRequestOAuthErrorUserInfoKey: response};
            NSError *error = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestOAuthError userInfo:userInfo];            
            [delegate flickrAPIRequest:self didFailWithError:error];                
        }
        else {
            NSAssert([delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthRequestToken:secret:)], @"Delegate must implement the method -flickrAPIRequest:didObtainOAuthRequestToken:secret: to handle OAuth request token callback");
            
            [delegate flickrAPIRequest:self didObtainOAuthRequestToken:oat secret:oats];
        }
    }
    else if (request.sessionInfo == OFFetchOAuthAccessTokenSession) {
        [request setSessionInfo:nil];

        NSString *response = [[[NSString alloc] initWithData:request.receivedData encoding:NSUTF8StringEncoding] autorelease];
        NSDictionary *params = OFExtractURLQueryParameter(response);
        
        NSString *fn = params[@"fullname"];
        NSString *oat = params[@"oauth_token"];
        NSString *oats = params[@"oauth_token_secret"];
        NSString *nsid = params[@"user_nsid"];
        NSString *un = params[@"username"];
        if (!fn || !oat || !oats || !nsid || !un) {
            NSDictionary *userInfo = @{OFFlickrAPIRequestOAuthErrorUserInfoKey: response};
            NSError *error = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestOAuthError userInfo:userInfo];            
            [delegate flickrAPIRequest:self didFailWithError:error];            
        }
        
        else {
            NSAssert([delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthAccessToken:secret:userFullName:userName:userNSID:)], @"Delegate must implement -flickrAPIRequest:didObtainOAuthAccessToken:secret:userFullName:userName:userNSID: to handle the obtained access token");
            
            [delegate flickrAPIRequest:self didObtainOAuthAccessToken:oat secret:oats userFullName:fn userName:un userNSID:nsid];
        }
    }
    else {
        NSDictionary *responseDictionary = [OFXMLMapper dictionaryMappedFromXMLData:request.receivedData];	
        NSDictionary *rsp = responseDictionary[@"rsp"];
        NSString *stat = rsp[@"stat"];
        
        // this also fails when (responseDictionary, rsp, stat) == nil, so it's a guranteed way of checking the result
        if (![stat isEqualToString:@"ok"]) {
            NSDictionary *err = rsp[@"err"];
            NSString *code = err[@"code"];
            NSString *msg = err[@"msg"];
        
            NSError *toDelegateError;
            if (code.length) {
                // intValue for 10.4-compatibility
                toDelegateError = [NSError errorWithDomain:OFFlickrAPIReturnedErrorDomain code:code.intValue userInfo:msg.length ? @{NSLocalizedFailureReasonErrorKey: msg} : nil];				
            }
            else {
                toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestFaultyXMLResponseError userInfo:nil];
            }
                
            if ([delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
                [delegate flickrAPIRequest:self didFailWithError:toDelegateError];        
            }
            return;
        }

        [self cleanUpTempFile];
        if ([delegate respondsToSelector:@selector(flickrAPIRequest:didCompleteWithResponse:)]) {
            [delegate flickrAPIRequest:self didCompleteWithResponse:rsp];
        }    
    }
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error
{
    NSError *toDelegateError = nil;
    if ([error isEqualToString:LFHTTPRequestConnectionError]) {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestConnectionError userInfo:@{NSLocalizedFailureReasonErrorKey: @"Network connection error"}];
    }
    else if ([error isEqualToString:LFHTTPRequestTimeoutError]) {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestTimeoutError userInfo:@{NSLocalizedFailureReasonErrorKey: @"Request timeout"}];
    }
    else {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestUnknownError userInfo:@{NSLocalizedFailureReasonErrorKey: @"Unknown error"}];
    }
    
    [self cleanUpTempFile];
    if ([delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
        [delegate flickrAPIRequest:self didFailWithError:toDelegateError];        
    }
}

- (void)httpRequest:(LFHTTPRequest *)request sentBytes:(NSUInteger)bytesSent total:(NSUInteger)total
{
    if (uploadTempFilename && [delegate respondsToSelector:@selector(flickrAPIRequest:imageUploadSentBytes:totalBytes:)]) {
        [delegate flickrAPIRequest:self imageUploadSentBytes:bytesSent totalBytes:total];
    }
}
@end

@implementation OFFlickrAPIRequest (PrivateMethods)
- (void)cleanUpTempFile

{
    if (uploadTempFilename) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:uploadTempFilename]) {
			BOOL __unused removeResult = NO;
			NSError *error = nil;
			removeResult = [fileManager removeItemAtPath:uploadTempFilename error:&error];
			NSAssert(removeResult, @"Should be able to remove temp file");
        }
        
        [uploadTempFilename release];
        uploadTempFilename = nil;
    }
}
@end
