//
//  NSString+Path.m
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "NSString+Path.h"

@implementation NSString (Path)

+ (NSString*)bundlePath:(NSString*)fileName {
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:fileName];
}

+ (NSString*)documentsPath:(NSString*)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

@end
