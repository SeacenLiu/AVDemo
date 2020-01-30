//
//  CommonUtil.h
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/15.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonUtil : NSObject

+ (NSString *)bundlePath:(NSString *)fileName;

+ (NSString *)documentsPath:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
