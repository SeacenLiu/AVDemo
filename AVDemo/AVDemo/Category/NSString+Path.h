//
//  NSString+Path.h
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Path)

+ (NSString*)bundlePath:(NSString*)fileName;

+ (NSString*)documentsPath:(NSString*)fileName;

@end

NS_ASSUME_NONNULL_END
