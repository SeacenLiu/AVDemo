//
//  CommonUtil.m
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/15.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "CommonUtil.h"

@implementation CommonUtil

+ (NSString *)bundlePath:(NSString *)fileName {
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)documentsPath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

@end
