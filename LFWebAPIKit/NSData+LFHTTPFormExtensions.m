//
// NSData+LFHTTPFormExtensions.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. (https://lithoglyph.com)
// Copyright (c) 2007-2009 Lukhnos D. Liu (https://lukhnos.org)
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

#import "NSData+LFHTTPFormExtensions.h"

@implementation NSData (LFHTTPFormExtensions)
+ (instancetype)dataAsWWWURLEncodedFormFromDictionary:(NSDictionary *)formDictionary
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
@end
