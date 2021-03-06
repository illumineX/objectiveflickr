//
// ObjectiveFlickr.h
//
// Copyright (c) 2006-2014 Lukhnos D. Liu (https://lukhnos.org)
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

#import "LFWebAPIKit.h"
#import "OFUtilities.h"
#import "OFXMLMapper.h"

extern NSString *const OFFlickrSmallSquareSize;		// "s" - 75x75
extern NSString *const OFFlickrLargeSquareSize;     // "q" - 150x150
extern NSString *const OFFlickrThumbnailSize;		// "t" - 100 on longest side
extern NSString *const OFFlickrSmallSize;			// "m" - 240 on longest side
extern NSString *const OFFlickrSmallSize320;		// "n" - 320 on longest side
extern NSString *const OFFlickrMediumSize;			// (no size modifier) - 500 on longest side
extern NSString *const OFFlickrMediumSquareSize640; // "z" - 640x640
extern NSString *const OFFlickrMediumSquareSize800;	// "c" - 800x800
extern NSString *const OFFlickrLargeSize;			// "b" - 1024 on longest side

extern NSString *const OFFlickrReadPermission;
extern NSString *const OFFlickrWritePermission;
extern NSString *const OFFlickrDeletePermission;

@interface OFFlickrAPIContext : NSObject
{
    NSString *key;
    NSString *sharedSecret;
    NSString *authToken;
    
    NSString *RESTAPIEndpoint;
	NSString *photoSource;
	NSString *photoWebPageSource;
	NSString *authEndpoint;
    NSString *uploadEndpoint;
    
    NSString *oauthToken;
    NSString *oauthTokenSecret;
}
- (instancetype)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret NS_DESIGNATED_INITIALIZER;

// OAuth URL
- (NSURL *)userAuthorizationURLWithRequestToken:(NSString *)inRequestToken requestedPermission:(NSString *)inPermission;


// URL provisioning
- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier;
- (NSURL *)photoWebPageURLFromDictionary:(NSDictionary *)inDictionary;
- (NSURL *)loginURLFromFrobDictionary:(NSDictionary *)inFrob requestedPermission:(NSString *)inPermission;

// API endpoints

@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *sharedSecret;
@property (nonatomic, retain) NSString *authToken;

@property (nonatomic, retain) NSString *RESTAPIEndpoint;
@property (nonatomic, retain) NSString *photoSource;
@property (nonatomic, retain) NSString *photoWebPageSource;
@property (nonatomic, retain) NSString *authEndpoint;
@property (nonatomic, retain) NSString *uploadEndpoint;

@property (nonatomic, retain) NSString *OAuthToken;
@property (nonatomic, retain) NSString *OAuthTokenSecret;
@end

extern NSString *const OFFlickrAPIReturnedErrorDomain;
extern NSString *const OFFlickrAPIRequestErrorDomain;

enum {
	// refer to Flickr API document for Flickr's own error codes
    OFFlickrAPIRequestConnectionError = 0x7fff0001,
    OFFlickrAPIRequestTimeoutError = 0x7fff0002,    
	OFFlickrAPIRequestFaultyXMLResponseError = 0x7fff0003,
    
    OFFlickrAPIRequestOAuthError = 0x7fff0004,

    OFFlickrAPIRequestUnknownError = 0x7fff0042    
};

extern NSString *const OFFlickrAPIRequestOAuthErrorUserInfoKey;

extern NSString *const OFFetchOAuthRequestTokenSession;
extern NSString *const OFFetchOAuthAccessTokenSession;


@class OFFlickrAPIRequest;

@protocol OFFlickrAPIRequestDelegate <NSObject>
@optional
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary;
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError;
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes;
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret;
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID;

@end

typedef id<OFFlickrAPIRequestDelegate> OFFlickrAPIRequestDelegateType;

@interface OFFlickrAPIRequest : NSObject
{
    OFFlickrAPIContext *context;
    LFHTTPRequest *HTTPRequest;
    
    OFFlickrAPIRequestDelegateType delegate;
    id sessionInfo;
    
    NSString *uploadTempFilename;
    
    id oauthState;
}
- (instancetype)initWithAPIContext:(OFFlickrAPIContext *)inContext NS_DESIGNATED_INITIALIZER;
- (OFFlickrAPIContext *)context;


- (NSTimeInterval)requestTimeoutInterval;
- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval;
@property (NS_NONATOMIC_IOSONLY, getter=isRunning, readonly) BOOL running;
- (void)cancel;

// oauth methods
- (BOOL)fetchOAuthRequestTokenWithCallbackURL:(NSURL *)inCallbackURL;
- (BOOL)fetchOAuthAccessTokenWithRequestToken:(NSString *)inRequestToken verifier:(NSString *)inVerifier;

// elementary methods
- (BOOL)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments;
- (BOOL)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments;

// image upload—we use NSInputStream here because we want to have flexibity; with this you can upload either a file or NSData from NSImage
- (BOOL)uploadImageStream:(NSInputStream *)inImageStream suggestedFilename:(NSString *)inFilename MIMEType:(NSString *)inType arguments:(NSDictionary *)inArguments;

@property (nonatomic, readonly) OFFlickrAPIContext *context;
@property (nonatomic, assign) OFFlickrAPIRequestDelegateType delegate;
@property (nonatomic, retain) id sessionInfo;
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;

@end
