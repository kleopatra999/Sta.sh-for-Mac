// Copyright © 1999-2011 deviantART Inc.

#import "NSString+TruncateToWidth.h"


@implementation NSString (TruncateToWidth)

- (NSString*)stringByTruncatingStringToWidth:(CGFloat)width withAttributes:(NSDictionary *)attributes {
    NSMutableString *resultString = [self mutableCopy];
    NSRange range = {resultString.length-1, 1};
	
	BOOL truncated = NO;
	
    while ([resultString sizeWithAttributes:attributes].width > width) {
        [resultString deleteCharactersInRange:range];
        range.location--;
		truncated = YES;
    }
	
	if (truncated) {
		[resultString replaceCharactersInRange:range withString:@"…"];
	}
	
    return resultString;
}

@end
