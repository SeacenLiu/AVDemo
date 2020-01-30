//
//  AUGraphPlayer.h
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/12.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUGraphPlayer : NSObject

- (instancetype)initWithFilePath:(NSString*) path;

- (BOOL)play;

- (void)stop;

- (void)setInputSource:(BOOL)isAcc;

@end

NS_ASSUME_NONNULL_END
