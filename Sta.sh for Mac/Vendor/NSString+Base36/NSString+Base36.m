//
//  NSString+Base36.m
//  Sta.sh
//
//  Created by Aaron Pearce on 2/11/12.
//  Copyright (c) 2012 Aaron Pearce. All rights reserved.
//

#import "NSString+Base36.h"

@implementation NSString (Base36)

- (NSString *)base36Encode
{
    double value = [self doubleValue];
	NSString *base36 = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	
	NSString *returnValue = @"";
	NSString *g = @"0";
	
	int i = 0;
	do {
		int x ;
		if (i == 0)
		{
			x = fmod(value, [base36 length] );
		}
		else {
			x = fmod([g doubleValue], [base36 length]);
		}
		
		NSString *y = [[NSString alloc] initWithFormat:@"%c", [base36 characterAtIndex:x]];
		returnValue = [y stringByAppendingString:returnValue];
		value = value / 36;
		i++;
		g = [[NSString alloc] initWithFormat:@"%0.0f", value - 0.5];
	} while ([g intValue] != 0);
    
	return returnValue;
}

@end
