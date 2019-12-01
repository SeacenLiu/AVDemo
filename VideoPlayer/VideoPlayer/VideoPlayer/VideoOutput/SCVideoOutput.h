//
//  SCVideoOutput.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseEffectFilter.h"

@class VideoFrame;
@interface SCVideoOutput : UIView

- (instancetype)initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth textureHeight:(NSInteger)textureHeight usingHWCodec:(BOOL)usingHWCodec;
- (instancetype)initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth textureHeight:(NSInteger)textureHeight usingHWCodec:(BOOL)usingHWCodec shareGroup:(EAGLSharegroup *)shareGroup;

- (void)presentVideoFrame:(VideoFrame*) frame;

- (BaseEffectFilter*)createImageProcessFilterInstance;
- (BaseEffectFilter*)getImageProcessFilterInstance;

- (void) destroy;

@end
